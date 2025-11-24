"""
AI RAG Agent for Blog Post Scoring
Analyzes blog posts and provides quality scores using LLM
"""

from fastapi import FastAPI, HTTPException, BackgroundTasks
from pydantic import BaseModel
from typing import List, Optional, Dict
import os
import json
from datetime import datetime
import psycopg2
from psycopg2.extras import RealDictCursor
import logging

# LangChain imports
from langchain_openai import ChatOpenAI, OpenAIEmbeddings
from langchain_community.llms import Ollama
from langchain_community.vectorstores import Chroma
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.prompts import ChatPromptTemplate

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="AI RAG Agent",
    description="Blog post quality scoring with RAG",
    version="1.0.0"
)

# Configuration
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@postgresql:5432/blogdb")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://ollama:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "llama3")
LLM_PROVIDER = os.getenv("LLM_PROVIDER", "ollama")  # "ollama" or "openai"
VECTOR_DB_PATH = os.getenv("VECTOR_DB_PATH", "./chroma_db")

# Initialize LLM and embeddings based on provider
if LLM_PROVIDER == "ollama":
    logger.info(f"Initializing Ollama LLM: {OLLAMA_BASE_URL} with model {OLLAMA_MODEL}")
    llm = Ollama(base_url=OLLAMA_BASE_URL, model=OLLAMA_MODEL)
    embeddings = None  # Ollama doesn't provide embeddings API yet
elif OPENAI_API_KEY:
    logger.info("Initializing OpenAI LLM")
    llm = ChatOpenAI(model="gpt-4-turbo-preview", temperature=0.3)
    embeddings = OpenAIEmbeddings()
else:
    logger.warning("No LLM provider configured. Agent will run in demo mode.")
    llm = None
    embeddings = None

# Vector database
vector_db = None
if embeddings:
    vector_db = Chroma(
        persist_directory=VECTOR_DB_PATH,
        embedding_function=embeddings
    )

# Database connection
def get_db_connection():
    return psycopg2.connect(DATABASE_URL, cursor_factory=RealDictCursor)

# Models
class PostScore(BaseModel):
    post_id: int
    technical_accuracy: int
    clarity: int
    completeness: int
    code_quality: int
    seo: int
    engagement: int
    total_score: int
    suggestions: List[str]
    analyzed_at: datetime

class ScoreRequest(BaseModel):
    post_id: int

class BatchScoreRequest(BaseModel):
    post_ids: List[int]

# Scoring prompt template
SCORING_PROMPT = ChatPromptTemplate.from_template("""
You are an expert technical content reviewer for a Kubernetes blog platform.

Analyze this blog post and provide detailed scores:

**Blog Post:**
Title: {title}
Category: {category}
Author: {author}
Content: {content}

**Scoring Criteria (return scores only, no explanations):**

1. Technical Accuracy (0-25): Correctness of information, best practices
2. Clarity & Readability (0-20): Writing quality, organization
3. Completeness (0-20): Topic coverage, depth
4. Code Quality (0-15): Code examples, formatting (0 if no code)
5. SEO Optimization (0-10): Keywords, structure
6. Engagement Potential (0-10): Interesting, valuable content

**Similar High-Quality Posts for Reference:**
{similar_posts}

Return ONLY a JSON object in this exact format:
{{
  "technical_accuracy": <number 0-25>,
  "clarity": <number 0-20>,
  "completeness": <number 0-20>,
  "code_quality": <number 0-15>,
  "seo": <number 0-10>,
  "engagement": <number 0-10>,
  "suggestions": ["suggestion 1", "suggestion 2", "suggestion 3"]
}}
""")

async def get_post(post_id: int) -> Dict:
    """Retrieve post from database"""
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, title, category, content, author, created_at FROM blog_posts WHERE id = %s",
                (post_id,)
            )
            post = cur.fetchone()
            if not post:
                raise HTTPException(status_code=404, detail=f"Post {post_id} not found")
            return dict(post)
    finally:
        conn.close()

async def find_similar_posts(content: str, k: int = 3) -> List[str]:
    """Find similar high-quality posts using RAG"""
    if not vector_db:
        return []

    try:
        results = vector_db.similarity_search(content, k=k)
        return [doc.page_content[:200] + "..." for doc in results]
    except Exception as e:
        logger.error(f"Error finding similar posts: {e}")
        return []

async def analyze_with_llm(post: Dict) -> Dict:
    """Analyze post with LLM"""
    if not llm:
        # Demo mode - return random scores
        import random
        return {
            "technical_accuracy": random.randint(15, 25),
            "clarity": random.randint(12, 20),
            "completeness": random.randint(12, 20),
            "code_quality": random.randint(8, 15),
            "seo": random.randint(5, 10),
            "engagement": random.randint(5, 10),
            "suggestions": [
                "Add more code examples",
                "Improve the introduction",
                "Add a conclusion section"
            ]
        }

    # Find similar posts
    similar_posts = await find_similar_posts(post['content'])
    similar_text = "\n\n".join(similar_posts) if similar_posts else "No similar posts found."

    # Create prompt
    prompt = SCORING_PROMPT.format(
        title=post['title'],
        category=post['category'],
        author=post['author'],
        content=post['content'][:2000],  # Limit content length
        similar_posts=similar_text
    )

    # Get LLM response
    try:
        if LLM_PROVIDER == "ollama":
            # Ollama returns string directly
            response_text = llm.invoke(prompt)
            logger.info(f"Raw Ollama response (first 500 chars): {response_text[:500]}")
            
            # Try to extract JSON from response - find outermost braces
            import re
            # Find the first { and last }
            first_brace = response_text.find('{')
            last_brace = response_text.rfind('}')
            
            if first_brace != -1 and last_brace != -1 and last_brace > first_brace:
                json_str = response_text[first_brace:last_brace + 1]
                # Clean up common escape issues
                json_str = json_str.replace('\n', ' ').replace('\r', ' ')
                # Remove escaped underscores (technical\_accuracy -> technical_accuracy)
                json_str = json_str.replace('\\_', '_')
                # Remove invalid escape sequences
                json_str = re.sub(r'\\(?!["\\/bfnrtu])', r'\\\\', json_str)
                
                try:
                    result = json.loads(json_str)
                except json.JSONDecodeError as e:
                    logger.error(f"JSON decode error: {e}. Cleaned JSON: {json_str[:200]}")
                    raise ValueError(f"Invalid JSON response from Ollama: {str(e)}")
            else:
                logger.error(f"Could not find JSON braces in Ollama response: {response_text[:200]}")
                raise ValueError("No JSON found in Ollama response")
        else:
            # OpenAI returns object with .content
            response = llm.invoke(prompt)
            result = json.loads(response.content)
        
        return result
    except Exception as e:
        logger.error(f"LLM analysis error: {e}")
        raise HTTPException(status_code=500, detail=f"Analysis failed: {str(e)}")

async def store_scores(post_id: int, scores: Dict):
    """Store scores in database"""
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            # Calculate total score
            total = (
                scores['technical_accuracy'] +
                scores['clarity'] +
                scores['completeness'] +
                scores['code_quality'] +
                scores['seo'] +
                scores['engagement']
            )

            # Update blog_posts table
            cur.execute(
                """
                UPDATE blog_posts
                SET ai_score = %s, last_scored_at = CURRENT_TIMESTAMP
                WHERE id = %s
                """,
                (total, post_id)
            )

            # Insert into post_analysis table
            cur.execute(
                """
                INSERT INTO post_analysis (
                    post_id, technical_accuracy_score, clarity_score,
                    completeness_score, code_quality_score, seo_score,
                    engagement_score, total_score, suggestions, model_version
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    post_id,
                    scores['technical_accuracy'],
                    scores['clarity'],
                    scores['completeness'],
                    scores['code_quality'],
                    scores['seo'],
                    scores['engagement'],
                    total,
                    json.dumps(scores.get('suggestions', [])),
                    "gpt-4-turbo-preview"
                )
            )

            conn.commit()
            logger.info(f"Stored scores for post {post_id}: {total}/100")

    finally:
        conn.close()

# API Endpoints

@app.get("/")
async def root():
    return {
        "service": "AI RAG Agent",
        "version": "1.0.0",
        "status": "running",
        "llm_enabled": llm is not None,
        "llm_provider": LLM_PROVIDER if llm else "none",
        "ollama_url": OLLAMA_BASE_URL if LLM_PROVIDER == "ollama" else None,
        "ollama_model": OLLAMA_MODEL if LLM_PROVIDER == "ollama" else None
    }

@app.get("/health")
async def health():
    """Health check endpoint"""
    return {"status": "healthy"}

@app.post("/score")
async def score_post(request: ScoreRequest, background_tasks: BackgroundTasks):
    """
    Score a single blog post

    The scoring happens in the background, so this returns immediately.
    Check GET /scores/{post_id} for results.
    """
    logger.info(f"Received score request for post {request.post_id}")

    # Add to background tasks
    background_tasks.add_task(score_post_task, request.post_id)

    return {
        "message": f"Scoring post {request.post_id} in background",
        "post_id": request.post_id,
        "status": "queued"
    }

async def score_post_task(post_id: int):
    """Background task to score a post"""
    try:
        logger.info(f"Starting analysis for post {post_id}")

        # Get post
        post = await get_post(post_id)

        # Analyze with LLM
        scores = await analyze_with_llm(post)

        # Store results
        await store_scores(post_id, scores)

        logger.info(f"Completed analysis for post {post_id}")

    except Exception as e:
        logger.error(f"Error scoring post {post_id}: {e}")

@app.post("/score/batch")
async def score_batch(request: BatchScoreRequest, background_tasks: BackgroundTasks):
    """Score multiple posts"""
    logger.info(f"Received batch score request for {len(request.post_ids)} posts")

    for post_id in request.post_ids:
        background_tasks.add_task(score_post_task, post_id)

    return {
        "message": f"Scoring {len(request.post_ids)} posts in background",
        "post_ids": request.post_ids,
        "status": "queued"
    }

@app.get("/scores/{post_id}")
async def get_scores(post_id: int):
    """Get all scores for a post"""
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    pa.*,
                    bp.title,
                    bp.category,
                    bp.ai_score
                FROM post_analysis pa
                JOIN blog_posts bp ON pa.post_id = bp.id
                WHERE pa.post_id = %s
                ORDER BY pa.analyzed_at DESC
                """,
                (post_id,)
            )
            results = cur.fetchall()

            if not results:
                raise HTTPException(status_code=404, detail=f"No scores found for post {post_id}")

            return {
                "post_id": post_id,
                "title": results[0]['title'],
                "category": results[0]['category'],
                "current_score": results[0]['ai_score'],
                "analysis_history": [dict(row) for row in results]
            }
    finally:
        conn.close()

@app.get("/scores")
async def get_all_scores(limit: int = 100):
    """Get all scored posts"""
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    bp.id,
                    bp.title,
                    bp.category,
                    bp.author,
                    bp.ai_score,
                    bp.last_scored_at,
                    pa.technical_accuracy_score,
                    pa.clarity_score,
                    pa.completeness_score,
                    pa.code_quality_score,
                    pa.seo_score,
                    pa.engagement_score
                FROM blog_posts bp
                LEFT JOIN LATERAL (
                    SELECT * FROM post_analysis
                    WHERE post_id = bp.id
                    ORDER BY analyzed_at DESC
                    LIMIT 1
                ) pa ON true
                WHERE bp.ai_score IS NOT NULL
                ORDER BY bp.ai_score DESC
                LIMIT %s
                """,
                (limit,)
            )
            results = cur.fetchall()
            return {"posts": [dict(row) for row in results]}
    finally:
        conn.close()

@app.post("/reindex")
async def reindex_vector_db():
    """Rebuild vector database from all posts"""
    if not vector_db:
        raise HTTPException(status_code=503, detail="Vector DB not available")

    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id, title, content, ai_score FROM blog_posts")
            posts = cur.fetchall()

        # Clear existing data
        vector_db.delete_collection()

        # Add posts to vector DB
        text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=1000,
            chunk_overlap=200
        )

        for post in posts:
            chunks = text_splitter.split_text(post['content'])
            vector_db.add_texts(
                texts=chunks,
                metadatas=[{
                    'post_id': post['id'],
                    'title': post['title'],
                    'score': post.get('ai_score', 0)
                }] * len(chunks)
            )

        vector_db.persist()

        return {
            "message": "Vector database reindexed",
            "posts_indexed": len(posts)
        }

    finally:
        conn.close()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

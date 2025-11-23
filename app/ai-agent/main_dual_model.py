"""
AI RAG Agent for Blog Post Scoring - DUAL MODEL SUPPORT
Supports both Local Models (Ollama) and OpenAI (ChatGPT)
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
from langchain_community.embeddings import OllamaEmbeddings
from langchain_community.vectorstores import Chroma
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.prompts import ChatPromptTemplate

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="AI RAG Agent - Dual Model",
    description="Blog post quality scoring with local or cloud LLM",
    version="2.0.0"
)

# ============================================================================
# CONFIGURATION - Choose Your Model
# ============================================================================

# Model selection: "ollama" or "openai"
MODEL_PROVIDER = os.getenv("MODEL_PROVIDER", "ollama")  # Default to local

# Database
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@postgresql:5432/blogdb")
VECTOR_DB_PATH = os.getenv("VECTOR_DB_PATH", "./chroma_db")

# OpenAI Configuration
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4-turbo-preview")

# Ollama Configuration
OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://ollama:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "llama3")  # or mistral, gemma, codellama

# ============================================================================
# INITIALIZE LLM AND EMBEDDINGS
# ============================================================================

llm = None
embeddings = None
model_info = {"provider": MODEL_PROVIDER, "model": "none", "status": "not initialized"}

try:
    if MODEL_PROVIDER.lower() == "openai":
        # Use OpenAI (ChatGPT)
        if not OPENAI_API_KEY:
            raise ValueError("OPENAI_API_KEY is required for OpenAI provider")

        logger.info(f"Initializing OpenAI with model: {OPENAI_MODEL}")
        llm = ChatOpenAI(
            model=OPENAI_MODEL,
            temperature=0.3,
            api_key=OPENAI_API_KEY
        )
        embeddings = OpenAIEmbeddings(api_key=OPENAI_API_KEY)
        model_info = {
            "provider": "openai",
            "model": OPENAI_MODEL,
            "status": "ready",
            "cost_per_post": "$0.01-0.02"
        }

    elif MODEL_PROVIDER.lower() == "ollama":
        # Use Ollama (Local)
        logger.info(f"Initializing Ollama with model: {OLLAMA_MODEL} at {OLLAMA_BASE_URL}")
        llm = Ollama(
            model=OLLAMA_MODEL,
            base_url=OLLAMA_BASE_URL,
            temperature=0.3
        )
        embeddings = OllamaEmbeddings(
            model=OLLAMA_MODEL,
            base_url=OLLAMA_BASE_URL
        )
        model_info = {
            "provider": "ollama",
            "model": OLLAMA_MODEL,
            "base_url": OLLAMA_BASE_URL,
            "status": "ready",
            "cost_per_post": "$0.00 (free)"
        }

    else:
        raise ValueError(f"Invalid MODEL_PROVIDER: {MODEL_PROVIDER}. Must be 'openai' or 'ollama'")

except Exception as e:
    logger.error(f"Failed to initialize LLM: {e}")
    logger.warning("Running in DEMO MODE (random scores)")
    model_info["status"] = f"error: {str(e)}"

# Vector database
vector_db = None
if embeddings:
    try:
        vector_db = Chroma(
            persist_directory=VECTOR_DB_PATH,
            embedding_function=embeddings
        )
        logger.info("Vector database initialized successfully")
    except Exception as e:
        logger.error(f"Failed to initialize vector database: {e}")

# ============================================================================
# DATABASE
# ============================================================================

def get_db_connection():
    return psycopg2.connect(DATABASE_URL, cursor_factory=RealDictCursor)

# ============================================================================
# MODELS
# ============================================================================

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

class ModelSwitchRequest(BaseModel):
    provider: str  # "openai" or "ollama"
    model: Optional[str] = None  # Optional model name

# ============================================================================
# SCORING PROMPT (Works for both OpenAI and Ollama)
# ============================================================================

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

IMPORTANT: Return ONLY a valid JSON object in this EXACT format (no markdown, no extra text):
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

# ============================================================================
# CORE FUNCTIONS
# ============================================================================

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
    """Analyze post with LLM (OpenAI or Ollama)"""
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
        logger.info(f"Analyzing with {model_info['provider']} model: {model_info['model']}")

        if MODEL_PROVIDER.lower() == "openai":
            response = llm.invoke(prompt)
            content = response.content
        else:  # ollama
            response = llm.invoke(prompt)
            content = response

        # Extract JSON from response (handle markdown code blocks)
        content = content.strip()
        if content.startswith("```json"):
            content = content[7:]  # Remove ```json
        if content.startswith("```"):
            content = content[3:]  # Remove ```
        if content.endswith("```"):
            content = content[:-3]  # Remove ```
        content = content.strip()

        result = json.loads(content)
        logger.info(f"Successfully analyzed post {post['id']}")
        return result

    except json.JSONDecodeError as e:
        logger.error(f"JSON parsing error: {e}")
        logger.error(f"LLM response was: {content}")
        raise HTTPException(status_code=500, detail=f"Invalid JSON from LLM: {str(e)}")
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
                    f"{model_info['provider']}:{model_info['model']}"
                )
            )

            conn.commit()
            logger.info(f"Stored scores for post {post_id}: {total}/100 (using {model_info['provider']})")

    finally:
        conn.close()

# ============================================================================
# API ENDPOINTS
# ============================================================================

@app.get("/")
async def root():
    return {
        "service": "AI RAG Agent - Dual Model",
        "version": "2.0.0",
        "status": "running",
        "model": model_info
    }

@app.get("/health")
async def health():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "model": model_info
    }

@app.get("/model")
async def get_model_info():
    """Get current model configuration"""
    return model_info

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
        "status": "queued",
        "model": model_info['provider']
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
        "status": "queued",
        "model": model_info['provider']
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
            "posts_indexed": len(posts),
            "model": model_info['provider']
        }

    finally:
        conn.close()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

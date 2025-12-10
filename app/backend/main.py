"""
Kubernetes Blog Platform - Backend API
FastAPI application for managing blog posts about Kubernetes
"""

from fastapi import FastAPI, HTTPException, Depends, Request, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from sqlalchemy import create_engine, Column, Integer, String, Text, DateTime, text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from pydantic import BaseModel
from datetime import datetime
from typing import List, Optional
import os
import signal
import asyncio
import logging
import json
import httpx
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
import time

# JSON Logging Configuration
class JSONFormatter(logging.Formatter):
    """Custom JSON formatter for structured logging"""
    def format(self, record):
        log_data = {
            "timestamp": datetime.utcnow().isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "module": record.module,
            "function": record.funcName,
            "line": record.lineno,
        }

        # Add exception info if present
        if record.exc_info:
            log_data["exception"] = self.formatException(record.exc_info)

        # Add extra fields
        if hasattr(record, "request_id"):
            log_data["request_id"] = record.request_id
        if hasattr(record, "user_id"):
            log_data["user_id"] = record.user_id
        if hasattr(record, "http_method"):
            log_data["http_method"] = record.http_method
        if hasattr(record, "path"):
            log_data["path"] = record.path
        if hasattr(record, "status_code"):
            log_data["status_code"] = record.status_code
        if hasattr(record, "duration"):
            log_data["duration"] = record.duration

        return json.dumps(log_data)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    handlers=[
        logging.StreamHandler()
    ]
)

# Set JSON formatter for all handlers
for handler in logging.root.handlers:
    handler.setFormatter(JSONFormatter())

logger = logging.getLogger(__name__)

# Database configuration
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres:postgres@postgresql:5432/blogdb"
)

# AI Agent configuration
AI_AGENT_URL = os.getenv("AI_AGENT_URL", "http://ai-agent:8000")
AI_SCORING_ENABLED = os.getenv("AI_SCORING_ENABLED", "true").lower() == "true"

engine = create_engine(DATABASE_URL, pool_size=10, max_overflow=20, pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Prometheus Metrics
REQUEST_COUNT = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)
REQUEST_DURATION = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration in seconds',
    ['method', 'endpoint']
)
DB_CONNECTIONS = Gauge(
    'db_connections_active',
    'Active database connections'
)
POSTS_TOTAL = Gauge(
    'blog_posts_total',
    'Total number of blog posts'
)

# Rate Limiter
limiter = Limiter(key_func=get_remote_address)

# Graceful Shutdown State
is_shutting_down = False
shutdown_event = asyncio.Event()
in_flight_requests = 0
request_lock = asyncio.Lock()

# Database Models
class BlogPost(Base):
    __tablename__ = "blog_posts"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(255), nullable=False)
    content = Column(Text, nullable=False)
    category = Column(String(100), nullable=False)
    author = Column(String(100), nullable=False)
    tags = Column(String(255))
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    ai_score = Column(Integer, nullable=True)
    last_scored_at = Column(DateTime, nullable=True)

# Pydantic Models
class BlogPostCreate(BaseModel):
    title: str
    content: str
    category: str
    author: str
    tags: Optional[str] = None

class BlogPostResponse(BaseModel):
    id: int
    title: str
    content: str
    category: str
    author: str
    tags: Optional[str]
    created_at: datetime
    updated_at: datetime
    ai_score: Optional[int] = None
    last_scored_at: Optional[datetime] = None

    class Config:
        from_attributes = True

# FastAPI app
app = FastAPI(
    title="K8s Blog Platform API",
    description="Backend API for Kubernetes blog platform",
    version="1.0.0"
)

# Rate limiter state
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Shutdown middleware - reject new requests during shutdown
@app.middleware("http")
async def shutdown_middleware(request: Request, call_next):
    global is_shutting_down, in_flight_requests

    if is_shutting_down and request.url.path not in ["/health", "/ready", "/metrics"]:
        logger.warning(f"Rejecting request during shutdown: {request.url.path}")
        return Response(
            content="Service is shutting down",
            status_code=503,
            headers={"Retry-After": "30"}
        )

    # Track in-flight requests
    async with request_lock:
        in_flight_requests += 1
    
    try:
        response = await call_next(request)
        return response
    finally:
        async with request_lock:
            in_flight_requests -= 1

# Logging middleware
@app.middleware("http")
async def logging_middleware(request: Request, call_next):
    start_time = time.time()

    # Generate request ID
    request_id = f"{int(start_time * 1000)}"

    # Log request
    logger.info(
        "HTTP request received",
        extra={
            "request_id": request_id,
            "http_method": request.method,
            "path": str(request.url.path),
            "client_ip": request.client.host if request.client else "unknown",
            "user_agent": request.headers.get("user-agent", "unknown")
        }
    )

    response = await call_next(request)

    duration = time.time() - start_time

    # Log response
    logger.info(
        "HTTP request completed",
        extra={
            "request_id": request_id,
            "http_method": request.method,
            "path": str(request.url.path),
            "status_code": response.status_code,
            "duration": round(duration * 1000, 2)  # milliseconds
        }
    )

    return response

# Metrics middleware
@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    start_time = time.time()

    response = await call_next(request)

    duration = time.time() - start_time
    endpoint = request.url.path
    method = request.method
    status = response.status_code

    REQUEST_COUNT.labels(method=method, endpoint=endpoint, status=status).inc()
    REQUEST_DURATION.labels(method=method, endpoint=endpoint).observe(duration)

    return response

# Dependency
def get_db():
    db = SessionLocal()
    DB_CONNECTIONS.inc()
    try:
        yield db
    finally:
        DB_CONNECTIONS.dec()
        db.close()

# AI Scoring Functions
async def trigger_ai_scoring(post_id: int):
    """
    Trigger AI scoring for a blog post in the background
    Sends request to AI agent service
    """
    if not AI_SCORING_ENABLED:
        logger.info(f"AI scoring disabled, skipping post {post_id}")
        return

    try:
        async with httpx.AsyncClient(timeout=90.0) as client:  # Increased timeout for Ollama LLM
            response = await client.post(
                f"{AI_AGENT_URL}/score",
                json={"post_id": post_id}
            )

            if response.status_code == 200:
                logger.info(
                    f"AI scoring triggered successfully for post {post_id}",
                    extra={"post_id": post_id, "ai_agent_response": response.json()}
                )
            else:
                logger.warning(
                    f"AI scoring request failed for post {post_id}: {response.status_code}",
                    extra={"post_id": post_id, "status_code": response.status_code}
                )
    except httpx.TimeoutException:
        logger.warning(f"AI scoring request timeout for post {post_id}", extra={"post_id": post_id})
    except Exception as e:
        logger.error(
            f"Error triggering AI scoring for post {post_id}: {str(e)}",
            extra={"post_id": post_id, "error": str(e)}
        )

# Signal handlers for graceful shutdown
def handle_sigterm(signum, frame):
    """Handle SIGTERM signal for graceful shutdown"""
    global is_shutting_down
    logger.warning(f"Received signal {signum}, starting graceful shutdown", extra={"signal": signum})
    is_shutting_down = True

# Register signal handlers
signal.signal(signal.SIGTERM, handle_sigterm)
signal.signal(signal.SIGINT, handle_sigterm)

# Create tables and update metrics
@app.on_event("startup")
async def startup():
    logger.info("Application startup initiated")
    Base.metadata.create_all(bind=engine)
    # Initialize post count metric
    db = SessionLocal()
    try:
        count = db.query(BlogPost).count()
        POSTS_TOTAL.set(count)
        logger.info(f"Application started successfully", extra={"total_posts": count})
    except Exception as e:
        logger.error(f"Error during startup: {str(e)}", exc_info=True)
        raise
    finally:
        db.close()

@app.on_event("shutdown")
async def shutdown():
    """Graceful shutdown - wait for in-flight requests, then close database connections"""
    global is_shutting_down, in_flight_requests
    is_shutting_down = True
    logger.info("Graceful shutdown initiated")

    # Wait for in-flight requests to complete (max 25 seconds, Kubernetes gives us 30)
    shutdown_timeout = 25
    elapsed = 0
    while in_flight_requests > 0 and elapsed < shutdown_timeout:
        logger.info(f"Waiting for {in_flight_requests} in-flight requests to complete...")
        await asyncio.sleep(0.5)
        elapsed += 0.5

    if in_flight_requests > 0:
        logger.warning(f"Shutdown timeout reached with {in_flight_requests} requests still in-flight")
    else:
        logger.info("All in-flight requests completed")

    # Close database connections
    engine.dispose()
    logger.info("Database connections closed, shutdown complete")

# Health check
@app.get("/health")
async def health_check():
    """Health check endpoint for Kubernetes probes"""
    try:
        db = SessionLocal()
        db.execute(text("SELECT 1"))
        db.close()
        db_status = "connected"
    except Exception as e:
        db_status = f"error: {str(e)}"

    return {
        "status": "healthy" if db_status == "connected" else "degraded",
        "service": "k8s-blog-backend",
        "version": "1.0.0",
        "database": db_status
    }

# Readiness check
@app.get("/ready")
async def readiness_check():
    """Readiness probe - checks if app is ready to serve traffic"""
    global is_shutting_down

    # Return not ready during shutdown
    if is_shutting_down:
        raise HTTPException(status_code=503, detail="Shutting down")

    try:
        db = SessionLocal()
        db.execute(text("SELECT 1"))
        db.close()
        return {"status": "ready"}
    except Exception:
        raise HTTPException(status_code=503, detail="Not ready")

# Metrics endpoint for Prometheus
@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

# API Endpoints
@app.get("/")
async def root():
    return {
        "message": "Kubernetes Blog Platform API",
        "docs": "/docs",
        "health": "/health"
    }

@app.get("/api/posts", response_model=List[BlogPostResponse])
@limiter.limit("100/minute")
async def get_posts(
    request: Request,
    category: Optional[str] = None,
    skip: int = 0,
    limit: int = 10,
    db: Session = Depends(get_db)
):
    """Get all blog posts with pagination and optional category filter"""
    query = db.query(BlogPost).order_by(BlogPost.created_at.desc())

    if category:
        query = query.filter(BlogPost.category == category)

    posts = query.offset(skip).limit(min(limit, 100)).all()
    return posts

@app.get("/api/posts/{post_id}", response_model=BlogPostResponse)
async def get_post(post_id: int, db: Session = Depends(get_db)):
    """Get a specific blog post"""
    post = db.query(BlogPost).filter(BlogPost.id == post_id).first()
    
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    
    return post

@app.post("/api/posts", response_model=BlogPostResponse, status_code=201)
@limiter.limit("10/minute")
async def create_post(
    request: Request,
    post: BlogPostCreate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
):
    """Create a new blog post and trigger AI scoring"""
    db_post = BlogPost(**post.dict())
    db.add(db_post)
    db.commit()
    db.refresh(db_post)

    # Update metrics
    POSTS_TOTAL.inc()

    # Trigger AI scoring in background
    background_tasks.add_task(trigger_ai_scoring, db_post.id)

    logger.info(
        f"Created new post {db_post.id}, AI scoring queued",
        extra={"post_id": db_post.id, "title": db_post.title}
    )

    return db_post

@app.put("/api/posts/{post_id}", response_model=BlogPostResponse)
@limiter.limit("20/minute")
async def update_post(
    request: Request,
    post_id: int,
    post: BlogPostCreate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
):
    """Update a blog post and trigger AI re-scoring"""
    db_post = db.query(BlogPost).filter(BlogPost.id == post_id).first()

    if not db_post:
        raise HTTPException(status_code=404, detail="Post not found")

    for key, value in post.dict().items():
        setattr(db_post, key, value)

    db_post.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(db_post)

    # Trigger AI re-scoring in background
    background_tasks.add_task(trigger_ai_scoring, db_post.id)

    logger.info(
        f"Updated post {db_post.id}, AI re-scoring queued",
        extra={"post_id": db_post.id, "title": db_post.title}
    )

    return db_post

@app.delete("/api/posts/{post_id}", status_code=204)
@limiter.limit("10/minute")
async def delete_post(request: Request, post_id: int, db: Session = Depends(get_db)):
    """Delete a blog post"""
    db_post = db.query(BlogPost).filter(BlogPost.id == post_id).first()

    if not db_post:
        raise HTTPException(status_code=404, detail="Post not found")

    db.delete(db_post)
    db.commit()

    # Update metrics
    POSTS_TOTAL.dec()

    return None

@app.get("/api/categories")
async def get_categories():
    """Get available categories"""
    return {
        "categories": [
            "Kubernetes Features",
            "Security Best Practices",
            "CI/CD Workflows",
            "Helm and Package Management",
            "Networking",
            "Storage",
            "Monitoring and Observability",
            "GitOps"
        ]
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

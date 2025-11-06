"""
Kubernetes Blog Platform - Backend API
FastAPI application for managing blog posts about Kubernetes
"""

from fastapi import FastAPI, HTTPException, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from sqlalchemy import create_engine, Column, Integer, String, Text, DateTime, text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from pydantic import BaseModel
from datetime import datetime
from typing import List, Optional
import os
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
import time

# Database configuration
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres:postgres@postgresql:5432/blogdb"
)

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

# Create tables and update metrics
@app.on_event("startup")
async def startup():
    Base.metadata.create_all(bind=engine)
    # Initialize post count metric
    db = SessionLocal()
    try:
        count = db.query(BlogPost).count()
        POSTS_TOTAL.set(count)
    finally:
        db.close()

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
async def create_post(request: Request, post: BlogPostCreate, db: Session = Depends(get_db)):
    """Create a new blog post"""
    db_post = BlogPost(**post.dict())
    db.add(db_post)
    db.commit()
    db.refresh(db_post)

    # Update metrics
    POSTS_TOTAL.inc()

    return db_post

@app.put("/api/posts/{post_id}", response_model=BlogPostResponse)
@limiter.limit("20/minute")
async def update_post(
    request: Request,
    post_id: int,
    post: BlogPostCreate,
    db: Session = Depends(get_db)
):
    """Update a blog post"""
    db_post = db.query(BlogPost).filter(BlogPost.id == post_id).first()

    if not db_post:
        raise HTTPException(status_code=404, detail="Post not found")

    for key, value in post.dict().items():
        setattr(db_post, key, value)

    db_post.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(db_post)
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

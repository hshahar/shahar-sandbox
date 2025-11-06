"""
Test configuration and fixtures for backend tests
"""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from main import app, Base, get_db

# Use in-memory SQLite for testing
SQLALCHEMY_DATABASE_URL = "sqlite:///./test.db"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False}
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(scope="function")
def db_session():
    """Create a fresh database for each test"""
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function")
def client(db_session):
    """Create a test client with database override"""
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db

    with TestClient(app) as test_client:
        yield test_client

    app.dependency_overrides.clear()


@pytest.fixture
def sample_post_data():
    """Sample blog post data for testing"""
    return {
        "title": "Introduction to Kubernetes",
        "content": "Kubernetes is a powerful container orchestration platform...",
        "category": "Kubernetes Features",
        "author": "SHA",
        "tags": "kubernetes,containers,orchestration"
    }


@pytest.fixture
def multiple_posts_data():
    """Multiple blog posts for testing pagination and filtering"""
    return [
        {
            "title": "Kubernetes Security Best Practices",
            "content": "Security is paramount in Kubernetes...",
            "category": "Security Best Practices",
            "author": "SHA",
            "tags": "security,kubernetes"
        },
        {
            "title": "CI/CD with ArgoCD",
            "content": "ArgoCD enables GitOps workflows...",
            "category": "CI/CD Workflows",
            "author": "SHA",
            "tags": "cicd,argocd,gitops"
        },
        {
            "title": "Helm Chart Development",
            "content": "Helm simplifies Kubernetes application packaging...",
            "category": "Helm and Package Management",
            "author": "SHA",
            "tags": "helm,packaging"
        }
    ]

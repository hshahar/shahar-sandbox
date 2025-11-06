"""
API endpoint tests for blog platform
"""

import pytest
from fastapi import status


class TestHealthEndpoints:
    """Test health and readiness endpoints"""

    def test_health_check(self, client):
        """Test health endpoint returns correct status"""
        response = client.get("/health")
        assert response.status_code == status.HTTP_200_OK
        data = response.json()
        assert data["status"] in ["healthy", "degraded"]
        assert data["service"] == "k8s-blog-backend"
        assert "version" in data

    def test_readiness_check(self, client):
        """Test readiness endpoint"""
        response = client.get("/ready")
        assert response.status_code == status.HTTP_200_OK
        assert response.json()["status"] == "ready"

    def test_metrics_endpoint(self, client):
        """Test Prometheus metrics endpoint"""
        response = client.get("/metrics")
        assert response.status_code == status.HTTP_200_OK
        assert "http_requests_total" in response.text
        assert "http_request_duration_seconds" in response.text


class TestRootEndpoint:
    """Test root endpoint"""

    def test_root_endpoint(self, client):
        """Test root returns API information"""
        response = client.get("/")
        assert response.status_code == status.HTTP_200_OK
        data = response.json()
        assert "message" in data
        assert data["docs"] == "/docs"


class TestBlogPostCRUD:
    """Test CRUD operations for blog posts"""

    def test_create_post(self, client, sample_post_data):
        """Test creating a new blog post"""
        response = client.post("/api/posts", json=sample_post_data)
        assert response.status_code == status.HTTP_201_CREATED
        data = response.json()
        assert data["title"] == sample_post_data["title"]
        assert data["content"] == sample_post_data["content"]
        assert data["category"] == sample_post_data["category"]
        assert data["author"] == sample_post_data["author"]
        assert "id" in data
        assert "created_at" in data
        assert "updated_at" in data

    def test_get_all_posts_empty(self, client):
        """Test getting posts when database is empty"""
        response = client.get("/api/posts")
        assert response.status_code == status.HTTP_200_OK
        assert response.json() == []

    def test_get_all_posts(self, client, multiple_posts_data):
        """Test getting all blog posts"""
        # Create multiple posts
        for post_data in multiple_posts_data:
            client.post("/api/posts", json=post_data)

        response = client.get("/api/posts")
        assert response.status_code == status.HTTP_200_OK
        posts = response.json()
        assert len(posts) == 3
        # Check ordering (newest first)
        assert posts[0]["title"] == multiple_posts_data[-1]["title"]

    def test_get_posts_pagination(self, client, multiple_posts_data):
        """Test pagination of blog posts"""
        # Create multiple posts
        for post_data in multiple_posts_data:
            client.post("/api/posts", json=post_data)

        # Test skip and limit
        response = client.get("/api/posts?skip=1&limit=2")
        assert response.status_code == status.HTTP_200_OK
        posts = response.json()
        assert len(posts) == 2

    def test_get_posts_by_category(self, client, multiple_posts_data):
        """Test filtering posts by category"""
        # Create multiple posts
        for post_data in multiple_posts_data:
            client.post("/api/posts", json=post_data)

        response = client.get("/api/posts?category=Security+Best+Practices")
        assert response.status_code == status.HTTP_200_OK
        posts = response.json()
        assert len(posts) == 1
        assert posts[0]["category"] == "Security Best Practices"

    def test_get_post_by_id(self, client, sample_post_data):
        """Test getting a specific blog post by ID"""
        # Create a post
        create_response = client.post("/api/posts", json=sample_post_data)
        post_id = create_response.json()["id"]

        # Get the post
        response = client.get(f"/api/posts/{post_id}")
        assert response.status_code == status.HTTP_200_OK
        data = response.json()
        assert data["id"] == post_id
        assert data["title"] == sample_post_data["title"]

    def test_get_nonexistent_post(self, client):
        """Test getting a post that doesn't exist"""
        response = client.get("/api/posts/9999")
        assert response.status_code == status.HTTP_404_NOT_FOUND
        assert response.json()["detail"] == "Post not found"

    def test_update_post(self, client, sample_post_data):
        """Test updating a blog post"""
        # Create a post
        create_response = client.post("/api/posts", json=sample_post_data)
        post_id = create_response.json()["id"]

        # Update the post
        updated_data = {
            **sample_post_data,
            "title": "Updated: Introduction to Kubernetes",
            "content": "Updated content about Kubernetes..."
        }
        response = client.put(f"/api/posts/{post_id}", json=updated_data)
        assert response.status_code == status.HTTP_200_OK
        data = response.json()
        assert data["title"] == updated_data["title"]
        assert data["content"] == updated_data["content"]

    def test_update_nonexistent_post(self, client, sample_post_data):
        """Test updating a post that doesn't exist"""
        response = client.put("/api/posts/9999", json=sample_post_data)
        assert response.status_code == status.HTTP_404_NOT_FOUND
        assert response.json()["detail"] == "Post not found"

    def test_delete_post(self, client, sample_post_data):
        """Test deleting a blog post"""
        # Create a post
        create_response = client.post("/api/posts", json=sample_post_data)
        post_id = create_response.json()["id"]

        # Delete the post
        response = client.delete(f"/api/posts/{post_id}")
        assert response.status_code == status.HTTP_204_NO_CONTENT

        # Verify it's deleted
        get_response = client.get(f"/api/posts/{post_id}")
        assert get_response.status_code == status.HTTP_404_NOT_FOUND

    def test_delete_nonexistent_post(self, client):
        """Test deleting a post that doesn't exist"""
        response = client.delete("/api/posts/9999")
        assert response.status_code == status.HTTP_404_NOT_FOUND
        assert response.json()["detail"] == "Post not found"


class TestCategories:
    """Test categories endpoint"""

    def test_get_categories(self, client):
        """Test getting available categories"""
        response = client.get("/api/categories")
        assert response.status_code == status.HTTP_200_OK
        data = response.json()
        assert "categories" in data
        assert len(data["categories"]) > 0
        assert "Kubernetes Features" in data["categories"]
        assert "Security Best Practices" in data["categories"]


class TestValidation:
    """Test input validation"""

    def test_create_post_missing_fields(self, client):
        """Test creating a post with missing required fields"""
        invalid_data = {
            "title": "Test Post"
            # Missing other required fields
        }
        response = client.post("/api/posts", json=invalid_data)
        assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY

    def test_create_post_invalid_json(self, client):
        """Test creating a post with invalid JSON"""
        response = client.post(
            "/api/posts",
            data="invalid json",
            headers={"Content-Type": "application/json"}
        )
        assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY


class TestRateLimiting:
    """Test rate limiting functionality"""

    def test_rate_limit_create_posts(self, client, sample_post_data):
        """Test rate limiting on post creation (10/minute)"""
        # Note: This test might be slow as it creates many posts
        # In a real scenario, you'd mock the limiter or use time manipulation
        responses = []
        for _ in range(12):
            response = client.post("/api/posts", json=sample_post_data)
            responses.append(response.status_code)

        # At least one request should be rate limited
        assert status.HTTP_429_TOO_MANY_REQUESTS in responses

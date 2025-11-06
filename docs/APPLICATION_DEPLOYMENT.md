# Application Deployment Guide

## Overview

The SHA K8s Blog Platform consists of three main components:
- **Frontend**: React application (Vite + TypeScript)
- **Backend**: Python FastAPI REST API
- **Database**: PostgreSQL 15

## Application Structure

```
app/
├── frontend/
│   ├── src/              # React application source
│   ├── Dockerfile        # Multi-stage build with nginx
│   ├── nginx.conf        # nginx configuration for SPA routing
│   ├── package.json      # Node.js dependencies
│   └── vite.config.ts    # Vite configuration
└── backend/
    ├── main.py           # FastAPI application
    ├── Dockerfile        # Python application container
    └── requirements.txt  # Python dependencies
```

## Building Docker Images

### Frontend Build

```powershell
cd app\frontend
docker build -t sha-blog-frontend:dev .
```

**Build Process:**
1. Stage 1: Node.js builder - installs dependencies and builds React app
2. Stage 2: nginx - serves the static build artifacts

**Features:**
- Multi-stage build for optimized image size
- SPA routing support (all routes go to index.html)
- API proxy to backend at `/api/`
- Health check endpoint at `/health`

### Backend Build

```powershell
cd app\backend
docker build -t sha-blog-backend:dev .
```

**Build Process:**
- Python 3.11-slim base image
- Installs dependencies from requirements.txt
- Runs as non-root user (appuser, UID 1000)
- Exposes port 8000 for FastAPI/Uvicorn

**Features:**
- FastAPI REST API with async support
- PostgreSQL database integration via SQLAlchemy
- Health and readiness endpoints at `/health`
- CORS enabled for frontend integration

## Helm Deployment Configuration

### Backend Configuration (`values-dev.yaml`)

```yaml
backend:
  enabled: true
  replicas: 1
  image:
    repository: sha-blog-backend
    tag: "dev"
    pullPolicy: IfNotPresent
  service:
    port: 8000
```

**Environment Variables Set:**
- `ENVIRONMENT`: dev/staging/prod
- `PORT`: Application port (8000)
- `DATABASE_HOST`: PostgreSQL service name
- `DATABASE_PORT`: 5432
- `DATABASE_NAME`: Database name from values
- `DATABASE_USER`: From Kubernetes secret
- `DATABASE_PASSWORD`: From Kubernetes secret
- `DATABASE_URL`: Full PostgreSQL connection string

### Frontend Configuration (`values-dev.yaml`)

```yaml
frontend:
  enabled: true
  replicas: 1
  image:
    repository: sha-blog-frontend  # or nginx for basic deployment
    tag: "dev"  # or "1.25-alpine" for nginx
    pullPolicy: IfNotPresent
  service:
    port: 80
```

### Database Configuration

```yaml
postgresql:
  enabled: true
  database: sha_blog_dev  # Changes per environment
  image:
    repository: postgres
    tag: "15-alpine"
  persistence:
    size: 1Gi  # Increases in staging/prod
```

## Deployment Process

### 1. Build Images Locally

```powershell
# Build backend
cd app\backend
docker build -t sha-blog-backend:dev .

# Build frontend
cd ..\frontend
docker build -t sha-blog-frontend:dev .
```

### 2. Update Helm Values

Ensure `values-dev.yaml` references the correct images:
- `backend.image.repository`: sha-blog-backend
- `frontend.image.repository`: sha-blog-frontend
- `backend.service.port`: 8000 (not 80)

### 3. Deploy via Terraform

```powershell
cd terraform
terraform apply -var-file="environments/dev.tfvars" -auto-approve
```

Or use the deployment script:
```powershell
.\START-DEPLOY.bat
```

## Accessing the Application

### Development Environment

- **Frontend**: http://sha-dev.blog.local
- **Backend API**: http://sha-dev.blog.local/api/
- **Backend Direct**: http://sha-dev.blog.local (via backend service)

### API Endpoints

```
GET  /                    - Root endpoint with API info
GET  /health              - Health check
GET  /api/posts           - List all blog posts
POST /api/posts           - Create new post
GET  /api/posts/{id}      - Get specific post
PUT  /api/posts/{id}      - Update post
DELETE /api/posts/{id}    - Delete post
GET  /api/posts/category/{category} - Get posts by category
```

## Troubleshooting

### Backend Issues

**Symptom**: Backend pod in CrashLoopBackOff

**Check**:
```powershell
kubectl logs -n sha-dev <backend-pod-name>
```

**Common Issues**:
1. Database connection failure
   - Verify DATABASE_URL environment variable
   - Check PostgreSQL service name matches
   - Confirm database credentials in secrets

2. Port mismatch
   - Backend listens on port 8000
   - Service and deployment port must match
   - Update probes to use correct port

3. Health probe failures
   - Ensure `/health` endpoint is accessible
   - Check initialDelaySeconds (30s for liveness, 15s for readiness)
   - Verify no network policies blocking traffic

### Frontend Issues

**Symptom**: ImagePullBackOff

**Causes**:
- Image not built locally
- Image name mismatch in values
- `pullPolicy: IfNotPresent` but image doesn't exist

**Solution**:
```powershell
# Check if image exists
docker images sha-blog-frontend

# Rebuild if needed
cd app\frontend
docker build -t sha-blog-frontend:dev .
```

**Symptom**: 404 errors on page refresh

**Cause**: nginx not configured for SPA routing

**Solution**: Ensure nginx.conf has:
```nginx
location / {
    try_files $uri $uri/ /index.html;
}
```

### Database Issues

**Symptom**: "could not translate host name"

**Cause**: Database hostname incorrect

**Fix**: Update DATABASE_URL to use full service name:
```
postgresql://<user>:<pass>@<fullname>-postgresql:5432/<dbname>
```

Where `<fullname>` is from Helm template: `{{ include "microservices-app.fullname" . }}`

## CI/CD Integration (Future)

### GitHub Actions Workflow

```yaml
name: Build and Deploy

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build Frontend
        run: |
          cd app/frontend
          docker build -t ghcr.io/${{ github.repository }}/frontend:${{ github.sha }} .
          docker push ghcr.io/${{ github.repository }}/frontend:${{ github.sha }}
      
      - name: Build Backend
        run: |
          cd app/backend
          docker build -t ghcr.io/${{ github.repository }}/backend:${{ github.sha }} .
          docker push ghcr.io/${{ github.repository }}/backend:${{ github.sha }}
      
      - name: Update Helm Values
        run: |
          yq eval '.backend.image.tag = "${{ github.sha }}"' -i helm/microservices-app/values-dev.yaml
          yq eval '.frontend.image.tag = "${{ github.sha }}"' -i helm/microservices-app/values-dev.yaml
      
      - name: Deploy via ArgoCD
        run: |
          # ArgoCD will auto-sync changes
          git add helm/microservices-app/values-dev.yaml
          git commit -m "Update image tags to ${{ github.sha }}"
          git push
```

## Environment Differences

### Development
- Single replica
- Lower resource limits
- Basic authentication
- Local persistent storage

### Staging
- 2 replicas with autoscaling
- Argo Rollouts with Canary (10%→25%→50%→100%)
- Vault integration for secrets
- Network policies enabled

### Production
- 3+ replicas with strict autoscaling
- Conservative Canary rollout (5%→10%→25%→50%→100%)
- Full observability stack
- Strict network policies and security contexts

## Security Considerations

1. **Non-root containers**: Both frontend and backend run as non-root users
2. **Read-only filesystem**: Enabled where possible with necessary volume mounts
3. **Security contexts**: Drop all capabilities, use seccomp profile
4. **Secrets management**: Database credentials stored in Kubernetes secrets
5. **Network policies**: Control pod-to-pod communication

## Next Steps

1. **Push images to registry**: Move from local Docker to container registry (GHCR, ECR, etc.)
2. **Implement CI/CD**: Automate build and deployment
3. **Add monitoring**: Custom metrics for application-specific KPIs
4. **Implement caching**: Redis for session management and API caching
5. **Add authentication**: JWT-based auth with OAuth2
6. **API documentation**: Swagger/OpenAPI integration in FastAPI


# GitOps Workflow with ArgoCD

This guide demonstrates the complete GitOps workflow for developing, deploying, and managing the Kubernetes Blog Platform using ArgoCD.

## Table of Contents

1. [GitOps Principles](#gitops-principles)
2. [Repository Structure](#repository-structure)
3. [Development Workflow](#development-workflow)
4. [Deployment Workflow](#deployment-workflow)
5. [Environment Promotion](#environment-promotion)
6. [Rollback Procedures](#rollback-procedures)
7. [Best Practices](#best-practices)

---

## GitOps Principles

GitOps is a way to do Kubernetes cluster management and application delivery using Git as the single source of truth.

### Core Principles

1. **Declarative**: System state described declaratively (YAML manifests)
2. **Versioned**: All configuration in Git with full version history
3. **Automated**: Changes automatically applied to cluster
4. **Reconciled**: System continuously reconciled with desired state

### Benefits

✅ **Audit Trail**: Every change tracked in Git  
✅ **Rollback**: Easy revert to any previous state  
✅ **Disaster Recovery**: Rebuild cluster from Git  
✅ **Collaboration**: Standard Git workflow (PR, code review)  
✅ **Consistency**: Same process for all environments  
✅ **Security**: No direct cluster access needed  

---

## Repository Structure

```
k8s-blog-platform/
├── .github/workflows/          # CI/CD Pipelines
│   ├── build-images.yaml       # Build & push Docker images
│   └── update-manifests.yaml   # Update Helm values with new image tags
│
├── app/                        # Application Source Code
│   ├── frontend/               # React app
│   └── backend/                # FastAPI app
│
├── helm/microservices-app/     # Helm Chart (GitOps manifests)
│   ├── Chart.yaml
│   ├── values.yaml             # Base values
│   ├── values-dev.yaml         # Dev environment
│   ├── values-staging.yaml     # Staging environment
│   ├── values-prod.yaml        # Production environment
│   └── templates/              # Kubernetes resource templates
│
├── argocd/                     # ArgoCD Application definitions
│   ├── app-of-apps.yaml
│   └── applications/
│       ├── dev-application.yaml
│       ├── staging-application.yaml
│       └── prod-application.yaml
│
└── terraform/                  # Infrastructure as Code
    └── main.tf                 # ArgoCD installation
```

### Branch Strategy

| Branch | Purpose | Deploys To | Auto-Sync |
|--------|---------|------------|-----------|
| `develop` | Development | Dev namespace | ✅ Yes |
| `staging` | Pre-production testing | Staging namespace | ✅ Yes |
| `main` | Production releases | Production namespace | ❌ Manual |
| `feature/*` | Feature development | - | - |
| `hotfix/*` | Urgent production fixes | - | - |

---

## Development Workflow

### Scenario: Adding a New Blog Feature

#### Step 1: Create Feature Branch

```powershell
# Update local repository
git checkout develop
git pull origin develop

# Create feature branch
git checkout -b feature/add-comment-system

# Verify current branch
git branch
```

#### Step 2: Develop Feature

```powershell
# Edit backend API
code app/backend/main.py

# Add comment endpoint
"""
@app.post("/api/posts/{post_id}/comments")
async def create_comment(post_id: int, comment: Comment):
    # Implementation
    pass
"""

# Edit frontend
code app/frontend/src/components/CommentSection.tsx

# Add UI for comments
```

#### Step 3: Test Locally

```powershell
# Run backend locally
cd app/backend
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn main:app --reload

# Run frontend locally (separate terminal)
cd app/frontend
npm install
npm run dev
```

#### Step 4: Build and Test Docker Images

```powershell
# Build backend image
docker build -t k8s-blog-backend:feature ./app/backend

# Build frontend image
docker build -t k8s-blog-frontend:feature ./app/frontend

# Test with docker-compose (optional)
docker-compose up -d

# Test endpoints
curl http://localhost:8000/api/health
curl http://localhost:3000
```

#### Step 5: Commit Changes

```powershell
git add app/backend/main.py app/frontend/src/
git commit -m "feat: add comment system to blog posts

- Add POST /api/posts/{id}/comments endpoint
- Add CommentSection React component
- Include comment validation and storage"

git push origin feature/add-comment-system
```

#### Step 6: Create Pull Request

```
Title: feat: add comment system to blog posts

Description:
- Adds comment functionality to blog posts
- Backend validates and stores comments in PostgreSQL
- Frontend displays comment list with form
- Includes unit tests

Closes #123
```

#### Step 7: Code Review and Merge

Once approved:

```powershell
# Merge via GitHub UI or CLI
gh pr merge feature/add-comment-system --squash

# Or manually
git checkout develop
git merge feature/add-comment-system
git push origin develop
```

---

## Deployment Workflow

### Automatic Deployment Flow

```
┌────────────────────────────────────────────────────────────┐
│ 1. Developer pushes to develop branch                      │
└────────────────┬───────────────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────────────────────┐
│ 2. GitHub Actions triggered                                │
│    - Runs tests                                            │
│    - Builds Docker images                                  │
│    - Tags with commit SHA (abc123)                         │
│    - Pushes to container registry                          │
└────────────────┬───────────────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────────────────────┐
│ 3. GitHub Actions updates Helm values                      │
│    - Updates values-dev.yaml                               │
│    - Sets backend.image.tag: abc123                        │
│    - Sets frontend.image.tag: abc123                       │
│    - Commits and pushes changes                            │
└────────────────┬───────────────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────────────────────┐
│ 4. ArgoCD polls Git repository (every 3 minutes)           │
│    - Detects change in values-dev.yaml                     │
│    - Compares with current cluster state                   │
│    - Identifies OutOfSync status                           │
└────────────────┬───────────────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────────────────────┐
│ 5. ArgoCD auto-syncs (because automated policy enabled)    │
│    - Generates Kubernetes manifests from Helm              │
│    - Applies changes to dev namespace                      │
│    - Performs rolling update                               │
└────────────────┬───────────────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────────────────────┐
│ 6. Kubernetes deploys new version                          │
│    - Creates new ReplicaSet with new image                 │
│    - Gradually terminates old pods                         │
│    - Creates new pods with new image                       │
│    - Waits for health checks to pass                       │
└────────────────┬───────────────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────────────────────┐
│ 7. ArgoCD monitors deployment                              │
│    - Checks pod health status                              │
│    - Updates application status to "Healthy"               │
│    - Logs sync completion                                  │
└────────────────────────────────────────────────────────────┘
```

### Monitoring Deployment

```powershell
# Watch ArgoCD application status
argocd app get k8s-blog-dev --refresh
argocd app wait k8s-blog-dev

# Watch Kubernetes pods
kubectl get pods -n dev -w

# Check rollout status
kubectl rollout status deployment/backend -n dev
kubectl rollout status deployment/frontend -n dev

# View application logs
kubectl logs -n dev deployment/backend -f
kubectl logs -n dev deployment/frontend -f
```

### Deployment Verification

```powershell
# Check application health
curl http://dev.myapp.local/api/health

# Test new feature
curl -X POST http://dev.myapp.local/api/posts/1/comments `
  -H "Content-Type: application/json" `
  -d '{"author": "John", "text": "Great post!"}'

# View in browser
Start-Process "http://dev.myapp.local"
```

---

## Environment Promotion

### Dev → Staging

Once feature is tested in dev:

```powershell
# Merge develop to staging
git checkout staging
git pull origin staging
git merge develop

# Review changes
git log --oneline develop..staging

# Push to staging
git push origin staging

# GitHub Actions automatically:
# 1. Builds images (same code, different tag)
# 2. Updates values-staging.yaml
# 3. ArgoCD syncs to staging namespace

# Monitor staging deployment
argocd app get k8s-blog-staging --refresh
kubectl get pods -n staging -w
```

### Staging → Production

After thorough testing in staging:

```powershell
# Create release tag
git checkout main
git pull origin main
git merge staging

# Tag release
$version = "v1.2.3"
git tag -a $version -m "Release $version - Add comment system"

# Push to main
git push origin main --tags

# GitHub Actions builds production images
# Manual sync required for production

# View pending changes
argocd app diff k8s-blog-prod

# Sync to production (manual approval)
argocd app sync k8s-blog-prod

# Or via UI:
# 1. Open http://argocd-dev.local
# 2. Select k8s-blog-prod
# 3. Click "Sync" → "Synchronize"

# Monitor production deployment
argocd app wait k8s-blog-prod
kubectl get pods -n production -w
```

### Hotfix Workflow

For urgent production fixes:

```powershell
# Create hotfix branch from main
git checkout main
git pull origin main
git checkout -b hotfix/security-patch

# Apply fix
# ...
git commit -m "fix: critical security vulnerability"

# Merge to main
git checkout main
git merge hotfix/security-patch
git tag -a v1.2.4 -m "Hotfix v1.2.4 - Security patch"
git push origin main --tags

# Deploy to production immediately
argocd app sync k8s-blog-prod

# Backport to staging and develop
git checkout staging
git merge hotfix/security-patch
git push origin staging

git checkout develop
git merge hotfix/security-patch
git push origin develop
```

---

## Rollback Procedures

### Method 1: ArgoCD Rollback (Recommended)

```powershell
# View deployment history
argocd app history k8s-blog-dev

# Output:
ID  DATE                   REVISION                              MESSAGE
5   2025-11-06 14:30:00    abc123 (HEAD)                        feat: add comments
4   2025-11-06 12:15:00    xyz789                               feat: improve UI
3   2025-11-06 10:00:00    def456                               fix: api bug

# Rollback to previous version
argocd app rollback k8s-blog-dev 4

# Confirm rollback
argocd app wait k8s-blog-dev
```

### Method 2: Git Revert (GitOps Way)

```powershell
# Identify problematic commit
git log --oneline

# Revert commit
git revert abc123

# Push revert
git push origin develop

# ArgoCD automatically syncs the revert
argocd app wait k8s-blog-dev
```

### Method 3: Kubernetes Rollback (Emergency)

```powershell
# Rollback deployment directly
kubectl rollout undo deployment/backend -n dev
kubectl rollout undo deployment/frontend -n dev

# Note: ArgoCD will detect drift and may revert this change
# To prevent, temporarily disable auto-sync:
argocd app set k8s-blog-dev --sync-policy none

# Fix in Git, then re-enable auto-sync
argocd app set k8s-blog-dev --sync-policy automated
```

### Rollback Production

```powershell
# Check current production version
kubectl get deployment backend -n production -o jsonpath='{.spec.template.spec.containers[0].image}'

# View Git tags
git tag -l --sort=-v:refname

# Rollback to previous tag
git checkout v1.2.2
git tag -a v1.2.3-rollback -m "Rollback to v1.2.2"
git push origin v1.2.3-rollback

# Update values-prod.yaml with previous image tags
git checkout main
# Edit helm/microservices-app/values-prod.yaml
git commit -m "rollback: revert to v1.2.2"
git push origin main

# Sync production
argocd app sync k8s-blog-prod
```

---

## CI/CD Pipeline Configuration

### Build and Push Images

`.github/workflows/build-images.yaml`:

```yaml
name: Build and Push Docker Images

on:
  push:
    branches: [develop, staging, main]
    paths:
      - 'app/**'

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      packages: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Set image tags
        id: tags
        run: |
          BRANCH=${GITHUB_REF##*/}
          SHA_SHORT=$(echo $GITHUB_SHA | cut -c1-7)
          echo "backend_tag=ghcr.io/${{ github.repository }}/backend:${BRANCH}-${SHA_SHORT}" >> $GITHUB_OUTPUT
          echo "frontend_tag=ghcr.io/${{ github.repository }}/frontend:${BRANCH}-${SHA_SHORT}" >> $GITHUB_OUTPUT

      - name: Build and push backend
        uses: docker/build-push-action@v5
        with:
          context: ./app/backend
          push: true
          tags: ${{ steps.tags.outputs.backend_tag }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Build and push frontend
        uses: docker/build-push-action@v5
        with:
          context: ./app/frontend
          push: true
          tags: ${{ steps.tags.outputs.frontend_tag }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Update Helm values
        run: |
          BRANCH=${GITHUB_REF##*/}
          VALUES_FILE="helm/microservices-app/values-${BRANCH}.yaml"
          
          # Update image tags in values file
          yq eval -i ".backend.image.tag = \"${BRANCH}-$(echo $GITHUB_SHA | cut -c1-7)\"" $VALUES_FILE
          yq eval -i ".frontend.image.tag = \"${BRANCH}-$(echo $GITHUB_SHA | cut -c1-7)\"" $VALUES_FILE

      - name: Commit updated values
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add helm/microservices-app/values-*.yaml
          git commit -m "chore: update image tags to ${GITHUB_SHA:0:7}"
          git push
```

---

## Best Practices

### 1. Git Hygiene

✅ **DO**:
- Use meaningful commit messages (conventional commits)
- Keep commits atomic and focused
- Tag production releases
- Use branch protection rules

❌ **DON'T**:
- Commit secrets or credentials
- Force push to main branches
- Merge without code review

### 2. ArgoCD Configuration

✅ **DO**:
- Enable auto-sync for dev/staging
- Use manual sync for production
- Configure sync waves for ordered deployment
- Set resource limits for ArgoCD

❌ **DON'T**:
- Auto-sync production without approval process
- Ignore sync errors
- Disable prune in production (carefully)

### 3. Deployment Strategy

✅ **DO**:
- Test in dev before promoting
- Use canary or blue-green for production
- Monitor metrics after deployment
- Have rollback plan ready

❌ **DON'T**:
- Deploy directly to production
- Skip staging environment
- Deploy during peak hours
- Deploy on Fridays (if possible)

### 4. Security

✅ **DO**:
- Use External Secrets Operator
- Scan images for vulnerabilities
- Sign container images (cosign)
- Enable RBAC for ArgoCD

❌ **DON'T**:
- Store secrets in Git
- Use `:latest` image tag
- Give broad cluster permissions
- Expose ArgoCD publicly without auth

---

## Troubleshooting

### Pipeline Fails to Build

```powershell
# Check GitHub Actions logs
gh run list --branch develop
gh run view <run-id>

# Test build locally
docker build -t test ./app/backend
```

### ArgoCD Not Detecting Changes

```powershell
# Force refresh
argocd app get k8s-blog-dev --refresh

# Check repository connection
argocd repo list
argocd repo get https://github.com/yourusername/k8s-blog-platform.git

# Manually trigger sync
argocd app sync k8s-blog-dev
```

### Deployment Stuck in Progressing

```powershell
# Check pod status
kubectl get pods -n dev
kubectl describe pod <pod-name> -n dev

# Check events
kubectl get events -n dev --sort-by='.lastTimestamp'

# View deployment status
kubectl rollout status deployment/backend -n dev
```

---

## Additional Resources

- **GitOps Principles**: https://opengitops.dev/
- **ArgoCD Best Practices**: https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/
- **Conventional Commits**: https://www.conventionalcommits.org/
- **GitHub Actions**: https://docs.github.com/en/actions

---

**Next Steps**: Read [ARGOCD_SETUP.md](./ARGOCD_SETUP.md) for ArgoCD installation and configuration.

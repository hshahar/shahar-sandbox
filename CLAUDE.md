# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SHA Kubernetes Blog Platform - A production-ready Kubernetes microservices platform demonstrating GitOps, progressive delivery, AI/ML integration, and cloud-native best practices. The platform features a React frontend, FastAPI backend, PostgreSQL database, real-time AI scoring, ELK Stack logging, and comprehensive monitoring.

## Common Commands

### Local Development

```powershell
# Backend development
cd app/backend
pip install -r requirements.txt
pytest --cov=. --cov-report=term-missing    # Run tests with coverage
python main.py                               # Run backend locally

# Frontend development
cd app/frontend
npm ci                                       # Install dependencies
npm run dev                                  # Run dev server
npm run build                                # Build for production

# Run single test
cd app/backend
pytest test_api.py::TestHealthEndpoints::test_health_check -v
```

### Infrastructure & Deployment

```powershell
# Deploy infrastructure to local Kubernetes
cd terraform
terraform init
terraform apply -var-file="environments/dev.tfvars" -auto-approve

# Deploy to specific environment
terraform apply -var-file="environments/staging.tfvars"
terraform apply -var-file="environments/prod.tfvars"

# Helm operations
helm lint helm/microservices-app
helm lint helm/microservices-app --values helm/microservices-app/values-dev.yaml
helm template k8s-blog ./helm/microservices-app --values helm/microservices-app/values-dev.yaml

# Validate Helm across all environments
helm lint helm/microservices-app --values helm/microservices-app/values-dev.yaml
helm lint helm/microservices-app --values helm/microservices-app/values-staging.yaml
helm lint helm/microservices-app --values helm/microservices-app/values-prod.yaml
```

### Kubernetes Operations

```powershell
# Check deployment status
kubectl get pods -n sha-dev
kubectl get pods -n sha-staging
kubectl get pods -n sha-production

# View logs
kubectl logs -n sha-dev -l app=backend -f
kubectl logs -n sha-dev -l app=frontend -f
kubectl logs -n sha-dev -l app=ai-agent -f

# Port-forward services
kubectl port-forward -n sha-dev svc/backend 8000:8000
kubectl port-forward -n sha-dev svc/frontend 3000:3000
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
kubectl port-forward -n logging svc/kibana 5601:5601
```

### GitOps & CI/CD

```powershell
# ArgoCD operations
argocd app list
argocd app sync sha-k8s-blog-dev
argocd app get sha-k8s-blog-dev
argocd app rollback sha-k8s-blog-dev

# Check ArgoCD status
kubectl get applications -n argocd
kubectl get pods -n argocd
```

## Architecture

### Multi-Environment GitOps Flow

The repository uses a branch-based GitOps workflow with ArgoCD:

- **`develop` branch** → `sha-dev` namespace (auto-sync enabled, 1 replica)
- **`staging` branch** → `sha-staging` namespace (auto-sync, canary deployments, 2 replicas)
- **`main` branch** → `sha-production` namespace (manual sync, canary deployments, 3 replicas)

### Application Stack

**Frontend (React + Vite)**
- Location: [app/frontend/](app/frontend/)
- Port: 3000
- Build output: Nginx static serving
- Key file: [app/frontend/src/App.tsx](app/frontend/src/App.tsx)

**Backend (FastAPI)**
- Location: [app/backend/](app/backend/)
- Port: 8000
- Entry point: [app/backend/main.py](app/backend/main.py)
- Database: PostgreSQL with SQLAlchemy ORM
- Features:
  - Graceful shutdown with in-flight request tracking (v1.2.0)
  - Prometheus metrics at `/metrics`
  - Rate limiting (SlowAPI)
  - Structured JSON logging for ELK Stack
  - Background AI scoring triggers

**Database (PostgreSQL)**
- Deployed as StatefulSet
- Persistent storage via PVC
- Health checks via readiness/liveness probes

**AI Agent (Real-time Scoring)**
- Location: [app/ai-agent/](app/ai-agent/)
- Dual model support: Ollama (free, local) or OpenAI (premium)
- Main file: [app/ai-agent/main_dual_model.py](app/ai-agent/main_dual_model.py)
- Scores posts on 6 metrics: technical accuracy, clarity, completeness, code quality, SEO, engagement
- Triggered automatically on post create/update via backend background tasks

### Infrastructure Components

The following are deployed by Terraform ([terraform/main.tf](terraform/main.tf)):

1. **Calico CNI** - NetworkPolicy enforcement
2. **NGINX Ingress Controller** - Traffic routing
3. **ArgoCD** - GitOps continuous delivery
4. **HashiCorp Vault** - Secrets management
5. **Argo Rollouts** - Progressive delivery (canary deployments)
6. **KEDA** - Event-driven autoscaling
7. **Prometheus Stack** - Monitoring (includes Grafana)
8. **External Secrets Operator** - Vault to Kubernetes secret sync

### Helm Charts Structure

```
helm/
├── microservices-app/          # Main application (frontend + backend + postgres)
│   ├── values.yaml             # Base values
│   ├── values-dev.yaml         # Development overrides
│   ├── values-staging.yaml     # Staging overrides (canary enabled)
│   └── values-prod.yaml        # Production overrides (canary enabled)
├── ai-agent/                   # AI scoring service
├── elk-stack/                  # Centralized logging
├── cloudnative-pg/             # CloudNativePG operator
├── ollama/                     # Local LLM inference
└── karpenter-nodepool/         # AWS Karpenter node provisioning
```

### CI/CD Pipeline

**GitHub Actions Workflow**: [.github/workflows/golden-pipeline.yaml](.github/workflows/golden-pipeline.yaml)

Pipeline stages:
1. **Lint & Test** - Python/Node.js linting, unit tests, Helm validation
2. **Security Scan** - Trivy filesystem scan, dependency checks (Safety, npm audit)
3. **Code Quality** - SonarQube analysis (optional)
4. **Build Images** - Docker buildx with SBOM and provenance (parallel: backend + frontend)
5. **Container Scan** - Trivy image vulnerability scanning
6. **Sign Images** - Cosign keyless signing
7. **Generate SBOM** - Syft in SPDX format
8. **Policy Check** - Kyverno policy validation
9. **Performance Test** - k6 load testing (staging/prod only)
10. **Update Manifests** - Automated Helm values update with new image tags
11. **Notify ArgoCD** - Trigger sync + changelog generation + Slack/Teams notifications
12. **Monitor Deployment** - Health check + automated rollback on failure

**Important**: The pipeline automatically updates Helm values files with new image tags and commits them with `[skip ci]` to prevent infinite loops.

## Key Implementation Details

### Graceful Shutdown (Backend v1.2.0)

The backend implements graceful shutdown to prevent request failures during pod termination:

- Shutdown middleware tracks in-flight requests
- `/ready` endpoint returns 503 during shutdown (removes pod from service endpoints)
- Waits up to 25 seconds for in-flight requests to complete
- Kubernetes `terminationGracePeriodSeconds: 30` provides time buffer
- PreStop hook waits 5 seconds to allow service mesh updates

Reference: [docs/GRACEFUL_SHUTDOWN.md](docs/GRACEFUL_SHUTDOWN.md)

### AI Scoring Integration

Backend triggers AI scoring as a background task (non-blocking):

```python
# In app/backend/main.py
@app.post("/api/posts", response_model=BlogPostResponse, status_code=201)
async def create_post(post: BlogPostCreate, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    # ... save post to database ...
    background_tasks.add_task(trigger_ai_scoring, db_post.id)
    return db_post
```

AI agent is optional - controlled by `AI_SCORING_ENABLED` environment variable.

### Logging Structure

All logs use JSON format for ELK Stack ingestion:

```python
# JSON log format in app/backend/main.py
{
  "timestamp": "2024-11-24T10:30:45.123Z",
  "level": "INFO",
  "message": "HTTP request completed",
  "http_method": "POST",
  "path": "/api/posts",
  "status_code": 201,
  "duration": 45.2,
  "request_id": "1234567890"
}
```

Filebeat DaemonSet collects all pod logs → Logstash → Elasticsearch → Kibana.

### Progressive Delivery (Argo Rollouts)

Staging and production use canary deployments:

- **Traffic split**: 10% → 25% → 50% → 100%
- **Analysis**: Prometheus metrics (error rate, latency)
- **Auto-rollback**: If metrics exceed thresholds
- **Manual promotion**: Enabled in production

Only the backend uses Argo Rollouts (frontend is stateless and safer to deploy directly).

### Security Implementation

**Network Policies**: Calico enforces default-deny in production:
- Frontend can only talk to backend
- Backend can only talk to PostgreSQL and AI agent
- PostgreSQL accepts connections only from backend

**Pod Security**: PSA enforcement via namespace labels:
- Dev: `baseline`
- Staging/Prod: `restricted`
- All pods run as non-root (UID 1000)
- Read-only root filesystem where possible
- Seccomp profile: `RuntimeDefault`

**Secrets Management**: Vault + External Secrets Operator

**Kyverno Policies**: Enforces image signing, trusted registries, resource limits

## Development Workflow

### Feature Development

1. Create feature branch from `develop`
2. Make changes locally
3. Run tests: `pytest app/backend --cov` and `npm test --prefix app/frontend`
4. Commit and push
5. Create Pull Request
6. CI/CD pipeline runs automatically
7. Merge to `develop` → auto-deploys to `sha-dev`

### Environment Promotion

```bash
# Dev → Staging
git checkout staging
git merge develop
git push
# Auto-deploys to sha-staging with canary

# Staging → Production
git checkout main
git merge staging
git push
# Updates manifests, requires manual ArgoCD sync
argocd app sync sha-k8s-blog-prod
```

### Local Testing Before Commit

```powershell
# Backend
cd app/backend
pylint main.py --exit-zero
pytest --cov=. --cov-report=term-missing

# Frontend
cd app/frontend
npm run lint || true
npm run build

# Helm validation
helm lint helm/microservices-app --values helm/microservices-app/values-dev.yaml
```

## Important Conventions

### Image Tagging

Images are tagged with format: `{branch}-{short-sha}`
- Example: `develop-a1b2c3d`, `main-x9y8z7w`
- Tags are automatically updated in Helm values by CI/CD pipeline

### Commit Messages

Use conventional commits for changelog generation:
- `feat:` - New feature
- `fix:` - Bug fix
- `chore:` - Maintenance (e.g., dependency updates)
- `docs:` - Documentation changes
- `test:` - Test additions/modifications

### ArgoCD Sync Policy

- **Dev**: Auto-sync enabled, self-heal enabled
- **Staging**: Auto-sync enabled, manual rollback
- **Production**: Manual sync only

## AWS EKS Deployment

For cloud deployment, use Terraform EKS module:

```powershell
cd terraform/eks
terraform init
terraform apply

# Configure kubectl
aws eks update-kubeconfig --region us-west-2 --name sha-blog-eks

# Deploy application
helm install sha-blog ../../helm/microservices-app --namespace sha-dev
```

EKS features:
- Spot instances (70% cost savings)
- Auto-scaling: 2-10 nodes
- Karpenter for intelligent node provisioning
- Cost: ~$105/month with shutdown scripts

Reference: [terraform/eks/README.md](terraform/eks/README.md)

## Monitoring & Observability

**Grafana Dashboards** (port-forward: `kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80`):
- Request rate, error rate, P95 latency per service
- CPU/Memory usage per pod
- Database connection pool metrics
- Argo Rollouts canary analysis

**Kibana** (port-forward: `kubectl port-forward -n logging svc/kibana 5601:5601`):
- Centralized logs from all pods
- Structured JSON logs with request tracking
- Common queries: error logs, slow requests, specific endpoints

**Prometheus Metrics**:
- Backend exposes `/metrics` endpoint
- Custom metrics: `http_requests_total`, `http_request_duration_seconds`, `blog_posts_total`
- ServiceMonitors auto-discovered by Prometheus

## Troubleshooting Tips

### Pods Not Starting

```powershell
kubectl describe pod <pod-name> -n sha-dev
kubectl get events -n sha-dev --sort-by='.lastTimestamp'
```

Common issues:
- Image pull errors: Check GitHub Container Registry credentials
- Resource limits: Check namespace ResourceQuota
- Security policies: Kyverno may block non-compliant resources

### ArgoCD Not Syncing

```powershell
argocd app get sha-k8s-blog-dev
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### AI Agent Not Scoring Posts

Check if AI agent is deployed and backend can reach it:
```powershell
kubectl get pods -n sha-dev -l app=ai-agent
kubectl exec -n sha-dev <backend-pod> -- wget -O- http://ai-agent:8000/health
```

### Database Connection Issues

Verify PostgreSQL is running and accessible:
```powershell
kubectl get statefulset -n sha-dev postgresql
kubectl exec -n sha-dev <backend-pod> -- nc -zv postgresql 5432
```

## Additional Documentation

- [README.md](README.md) - Comprehensive project documentation
- [docs/GITOPS_WORKFLOW.md](docs/GITOPS_WORKFLOW.md) - Detailed GitOps workflow
- [docs/PROGRESSIVE_DELIVERY.md](docs/PROGRESSIVE_DELIVERY.md) - Argo Rollouts canary deployments
- [docs/REALTIME_AI_SCORING.md](docs/REALTIME_AI_SCORING.md) - AI agent setup and configuration
- [docs/ELK_STACK_GUIDE.md](docs/ELK_STACK_GUIDE.md) - Logging infrastructure
- [docs/KEDA_AUTOSCALING.md](docs/KEDA_AUTOSCALING.md) - Event-driven autoscaling
- [docs/SECURITY.md](docs/SECURITY.md) - Security architecture and policies
- [argocd/README.md](argocd/README.md) - ArgoCD setup and access

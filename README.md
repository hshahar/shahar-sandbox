# SHA Kubernetes Blog Platform - Complete Documentation

**Last Updated:** 2025-11-24

This is the **master documentation** file containing all essential information for the SHA Kubernetes Blog Platform.

---

## Table of Contents

1. [Project Structure](#project-structure)
2. [Quick Start](#quick-start)
3. [Architecture Overview](#architecture-overview)
4. [Technology Stack](#technology-stack)
5. [Common Commands](#common-commands)
6. [CI/CD Pipeline](#cicd-pipeline)
7. [AI Agent & Real-Time Scoring](#ai-agent--real-time-scoring)
8. [ELK Stack Logging](#elk-stack-logging)
9. [AWS EKS Deployment](#aws-eks-deployment)
10. [Monitoring & Observability](#monitoring--observability)
11. [Security](#security)
12. [Troubleshooting](#troubleshooting)
13. [Development Workflow](#development-workflow)

---

## Project Structure

```
testshahar/
├── app/                          # Application code
│   ├── backend/                  # FastAPI backend
│   ├── frontend/                 # React frontend
│   └── ai-agent/                 # AI scoring agent
├── helm/                         # Helm charts
│   ├── microservices-app/        # Main application chart
│   ├── ai-agent/                 # AI agent chart
│   ├── elk-stack/                # ELK logging stack
│   ├── cloudnative-pg/           # PostgreSQL operator
│   └── ollama/                   # Local LLM chart
├── terraform/                    # Infrastructure as Code
│   ├── main.tf                   # Main infrastructure
│   ├── eks/                      # AWS EKS deployment
│   └── environments/             # Environment configs
├── argocd/                       # GitOps configurations
│   ├── applications/             # ArgoCD app definitions
│   └── install/                  # ArgoCD install scripts
├── scripts/                      # All automation scripts
│   ├── deploy-ai-agent.ps1       # AI agent deployment
│   ├── add-hosts-sha.ps1         # Host file configuration
│   ├── test-ai-scoring.ps1       # AI scoring tests
│   └── ...                       # Other utility scripts
├── manifests/                    # Standalone Kubernetes manifests
│   ├── elk-manifest.yaml         # ELK stack manifest
│   ├── external-services.yaml    # External services
│   └── ...                       # Other manifests
├── run.ps1                       # Main wrapper script
└── MASTER_DOCUMENTATION.md       # This file
```

**Key Directories:**
- **scripts/** - Contains ALL PowerShell/Bash automation scripts
- **manifests/** - Contains standalone YAML/JSON configuration files
- **helm/** - Helm charts remain in their original structure
- **argocd/** - GitOps configurations remain in their original structure

---

## Quick Start

### Prerequisites
- Kubernetes cluster (Rancher Desktop/Docker Desktop/AWS EKS)
- Terraform >= 1.0
- Helm >= 3.x
- kubectl
- AWS CLI (for EKS deployments)

### 10-Minute Setup

```powershell
# 1. Deploy infrastructure
cd terraform
terraform init
terraform apply -var-file="environments/dev.tfvars" -auto-approve

# 2. Add hostnames to hosts file (run as Administrator)
.\scripts\add-hosts-sha.ps1

# 3. Check deployment status
kubectl get pods -n sha-dev

# 4. Access application
# http://sha-dev.blog.local
```

---

## Architecture Overview

### Multi-Environment Structure

**Namespaces:**
- `sha-dev` - Development (auto-sync, 1 replica, 1Gi storage)
- `sha-staging` - Staging (auto-sync, 2 replicas, 5Gi storage, canary enabled)
- `sha-production` - Production (manual sync, 3 replicas, 10Gi storage, canary enabled)
- `argocd` - GitOps controller
- `monitoring` - Prometheus + Grafana
- `vault` - Secrets management
- `keda` - Event-driven autoscaling
- `argo-rollouts` - Progressive delivery
- `logging` - ELK Stack

### GitOps Workflow

**Branch → Environment Mapping:**
- `develop` branch → `sha-dev` namespace (auto-sync)
- `staging` branch → `sha-staging` namespace (auto-sync, canary)
- `main` branch → `sha-production` namespace (manual sync, canary)

### Infrastructure Components

**Deployed by Terraform:**
1. Calico CNI - NetworkPolicy enforcement
2. NGINX Ingress Controller - Traffic routing
3. ArgoCD - GitOps deployment automation
4. Vault - Secrets management
5. Argo Rollouts - Canary deployments
6. KEDA - Event-driven autoscaling
7. Prometheus Stack - Monitoring
8. External Secrets Operator - Vault sync

**Application Stack:**
- Frontend: React + Vite (Nginx)
- Backend: FastAPI (Python) with Prometheus metrics
- Database: PostgreSQL 15 (StatefulSet)
- AI Agent: Real-time scoring with Ollama/OpenAI
- Logging: ELK Stack (Elasticsearch, Logstash, Kibana, Filebeat)

---

## Technology Stack

- **Infrastructure**: Terraform + Helm + Kubernetes
- **GitOps**: ArgoCD
- **Applications**: React + FastAPI + PostgreSQL
- **AI/ML**: Real-time AI scoring (Ollama/OpenAI)
- **Logging**: ELK Stack
- **Progressive Delivery**: Argo Rollouts (Canary)
- **Autoscaling**: KEDA + HPA
- **Monitoring**: Prometheus + Grafana
- **Security**: Vault, Calico CNI, NetworkPolicies, Kyverno
- **CI/CD**: GitHub Actions (golden pipeline)

---

## Common Commands

### Deployment

```powershell
# Deploy to specific environment
.\run.ps1 deploy dev
.\run.ps1 deploy staging
.\run.ps1 deploy prod

# Check status
.\run.ps1 status dev
.\run.ps1 pods dev
.\run.ps1 services dev
```

### Testing

```powershell
# Backend tests
cd app/backend
pytest --cov=. --cov-report=term-missing

# Frontend tests
cd app/frontend
npm test -- --run

# Helm validation
helm lint helm/microservices-app
```

### Monitoring

```powershell
# Port-forward Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Access: http://localhost:3000 (admin/admin)

# Port-forward Kibana (ELK)
kubectl port-forward -n logging svc/kibana 5601:5601
# Access: http://localhost:5601
```

### ArgoCD Operations

```powershell
# Install ArgoCD (automated)
cd argocd/install
.\00-install-argocd.ps1
.\02-install-apps.ps1

# Sync manually
argocd app sync sha-k8s-blog-dev

# Check status
argocd app list
argocd app get sha-k8s-blog-dev
```

### AI Agent Operations

```powershell
# Check AI agent status
kubectl get pods -n sha-dev -l app=ai-agent

# View logs
kubectl logs -n sha-dev -l app=ai-agent -f

# Manually trigger scoring
curl -X POST http://localhost:8000/score -H "Content-Type: application/json" -d '{"post_id": 1}'
```

---

## CI/CD Pipeline

### Current Pipeline (.github/workflows/golden-pipeline.yaml)

**Stages:**
1. **Lint & Test** - Python, Node.js, Helm validation
2. **Security Scan** - Trivy filesystem + dependency scanning
3. **Build Images** - Docker buildx with SBOM/provenance
4. **Container Scan** - Trivy image scanning
5. **Sign Images** - Cosign keyless signing
6. **Generate SBOM** - Syft in SPDX format
7. **Policy Check** - Kyverno validation
8. **Update Manifests** - Automated Helm values update
9. **Notify ArgoCD** - Auto-sync in dev, manual for staging/prod

### Recommended CI/CD Improvements

#### Option 1: GitHub Actions (Current - RECOMMENDED)

**Already implemented!** You have a complete golden pipeline.

**To enable:**
1. Push code to GitHub
2. GitHub Actions triggers automatically
3. ArgoCD syncs changes to cluster

**Enhancements to add:**

```yaml
# .github/workflows/golden-pipeline.yaml additions:

# Add automated rollback on failure
- name: Rollback on failure
  if: failure()
  run: |
    argocd app rollback sha-k8s-blog-${{ env.ENVIRONMENT }} 1

# Add Slack notifications
- name: Notify Slack
  uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK }}

# Add performance testing
- name: Run performance tests
  run: |
    k6 run performance-tests.js

# Add integration tests
- name: Integration tests
  run: |
    pytest app/backend/test_integration.py
```

#### Option 2: GitLab CI/CD

**If moving to GitLab:**

```yaml
# .gitlab-ci.yml
stages:
  - lint
  - test
  - build
  - scan
  - deploy

lint:
  stage: lint
  script:
    - helm lint helm/microservices-app
    - pylint app/backend

test:
  stage: test
  script:
    - pytest app/backend --cov
    - npm test --prefix app/frontend

build:
  stage: build
  script:
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA

scan:
  stage: scan
  script:
    - trivy image $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA

deploy:
  stage: deploy
  script:
    - argocd app sync sha-k8s-blog-dev
```

#### Option 3: Jenkins

**If using Jenkins:**

```groovy
// Jenkinsfile
pipeline {
    agent any

    stages {
        stage('Lint') {
            steps {
                sh 'helm lint helm/microservices-app'
            }
        }

        stage('Test') {
            steps {
                sh 'pytest app/backend --cov'
            }
        }

        stage('Build') {
            steps {
                sh 'docker build -t sha-blog:${BUILD_NUMBER} .'
            }
        }

        stage('Deploy') {
            steps {
                sh 'argocd app sync sha-k8s-blog-dev'
            }
        }
    }
}
```

### CI/CD Best Practices (Your Setup)

**✅ Already Implemented:**
- Automated testing
- Security scanning (Trivy)
- Image signing (Cosign)
- SBOM generation (Syft)
- GitOps deployment (ArgoCD)
- Multi-environment support

**🔄 Recommended Additions:**
1. **Automated Rollback** - Add rollback on deployment failure
2. **Notifications** - Slack/Teams integration
3. **Performance Testing** - Add k6 or Locust tests
4. **Integration Tests** - End-to-end testing
5. **Staging Promotion** - Automated promotion workflow
6. **Deployment Approval** - Manual approval for production

---

## AI Agent & Real-Time Scoring

### Overview
Automatic AI scoring for blog posts using RAG (Retrieval Augmented Generation).

### Features
- **Real-time scoring**: Automatic on create/update
- **Dual model support**: Ollama (free) or OpenAI (premium)
- **6 quality metrics**: Technical accuracy, clarity, completeness, code quality, SEO, engagement
- **Visual display**: Color-coded score badges (⭐ 90+, ✨ 80+, 👍 70+)

### Model Comparison

| Model | Cost | Speed | Quality | Best For |
|-------|------|-------|---------|----------|
| Ollama (Llama3) | $0 | 10-15s | 85-90% | Dev/test, high volume |
| OpenAI GPT-4 | ~$0.01-0.02/post | 5-8s | 95%+ | Production |

### Deployment

```bash
# Option 1: Free local model
.\scripts\deploy-ai-agent.ps1 -UseOllama

# Option 2: OpenAI (premium)
.\scripts\deploy-ai-agent.ps1 -OpenAIKey "sk-your-key"
```

### How It Works
1. User creates/updates post → Backend saves to DB
2. Backend triggers AI agent (non-blocking background task)
3. AI agent retrieves post, finds similar posts (RAG)
4. AI analyzes with LLM and calculates scores
5. Scores stored in database
6. Frontend displays score badge (5-15 seconds)

---

## ELK Stack Logging

### Architecture

```
Container Logs → Filebeat → Logstash → Elasticsearch → Kibana
```

### Components
- **Elasticsearch**: Search engine (10Gi storage)
- **Logstash**: Log processing pipeline
- **Kibana**: Web UI for visualization
- **Filebeat**: DaemonSet log collector

### Deployment

```bash
# Install ELK stack
helm install elk-stack ./helm/elk-stack --namespace logging --create-namespace

# Access Kibana
kubectl port-forward -n logging svc/kibana 5601:5601
# http://localhost:5601
```

### Common Kibana Queries

```
# Backend errors
k8s_container: "backend" AND level: "ERROR"

# HTTP 500 errors
status_code: 500

# Slow requests
duration > 500

# Specific endpoint
path: "/api/posts" AND http_method: "POST"
```

---

## AWS EKS Deployment

### Cost-Optimized Cloud Infrastructure

**Features:**
- Region: us-west-2 (Oregon)
- Spot instances (70% cheaper)
- Auto-scaling: 2-10 nodes
- EBS gp3 storage (20% cheaper)
- Cost management: Shutdown scripts

**Cost Breakdown:**
- Running 24/7: ~$150-160/month
- With shutdown: ~$105/month (saves $50-60)

### Deployment

```bash
cd terraform/eks

# Deploy EKS cluster (15-20 minutes)
terraform init
terraform apply

# Configure kubectl
aws eks update-kubeconfig --region us-west-2 --name sha-blog-eks

# Deploy application
helm install sha-blog ../../helm/microservices-app \
  --namespace sha-dev \
  --values ../../helm/microservices-app/values-eks.yaml

# Shutdown to save costs
.\shutdown-cluster.ps1

# Startup again
.\startup-cluster.ps1
```

---

## Monitoring & Observability

### Grafana Dashboards

**Metrics:**
- Request rate (req/sec by service)
- Error rate (5xx errors %)
- P95 latency (ms)
- CPU/Memory usage per pod
- Pod uptime/ready ratio
- Database connections
- Network I/O

**Access:**
```powershell
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# http://localhost:3000 (admin/admin)
```

### Prometheus ServiceMonitors

- Backend `/metrics` endpoint
- Frontend Nginx metrics
- PostgreSQL exporter
- Argo Rollouts metrics
- KEDA scaler metrics

### Alerts (Production Only)

- Error rate > 1%
- P95 latency > 300ms
- CPU > 80%, Memory > 85%
- Pod not ready > 5 minutes

---

## Security

### Network Security
- Calico CNI with NetworkPolicies
- Default-deny in production
- Explicit allow rules (frontend→backend→postgres)

### Pod Security
- PSA enforcement: baseline (dev), restricted (staging/prod)
- Non-root users (UID 1000)
- Read-only root filesystem
- Seccomp profiles (RuntimeDefault)
- Dropped capabilities

### Secrets Management
- Vault for centralized storage
- External Secrets Operator for sync
- Kubernetes Secrets for backward compatibility

### Runtime Security
- Kyverno policies (audit or enforce)
- Image signature verification (Cosign)
- Trusted registry enforcement
- SBOM attestation

---

## Troubleshooting

### Pods Stuck in Pending
```powershell
kubectl get pvc -n sha-dev
kubectl describe nodes
kubectl get events -n sha-dev
```

### Ingress Not Working
```powershell
# Verify hosts file
Get-Content C:\Windows\System32\drivers\etc\hosts | Select-String "sha-"

# Check Ingress Controller
kubectl get pods -n ingress-nginx

# Check Ingress
kubectl describe ingress -n sha-dev
```

### ArgoCD Not Syncing
```powershell
# Check application health
argocd app get sha-k8s-blog-dev

# Force refresh
argocd app sync sha-k8s-blog-dev --force
```

### AI Agent Not Scoring
```powershell
# Check if AI agent is deployed
kubectl get pods -n sha-dev -l app=ai-agent

# Check backend logs for triggers
kubectl logs -n sha-dev -l app=backend | Select-String "AI scoring"

# Check AI agent logs
kubectl logs -n sha-dev -l app=ai-agent -f

# Test connectivity
kubectl exec -n sha-dev <backend-pod> -- wget -O- http://ai-agent:8000/health
```

---

## Development Workflow

### Feature Development Flow

1. **Create feature branch**
   ```bash
   git checkout -b feature/my-feature
   ```

2. **Develop locally**
   ```bash
   # Backend
   cd app/backend
   python main.py

   # Frontend
   cd app/frontend
   npm run dev
   ```

3. **Test**
   ```bash
   pytest app/backend
   npm test --prefix app/frontend
   ```

4. **Commit and push**
   ```bash
   git add .
   git commit -m "feat: add my feature"
   git push origin feature/my-feature
   ```

5. **Create Pull Request**
   - CI/CD pipeline runs automatically
   - Review checks pass
   - Merge to `develop`

6. **Auto-deploy to dev**
   - ArgoCD detects change
   - Auto-syncs to `sha-dev` namespace
   - Verify in dev environment

7. **Promote to staging**
   ```bash
   git checkout staging
   git merge develop
   git push
   ```

8. **Canary deployment in staging**
   - Argo Rollouts progressive delivery
   - 10% → 25% → 50% → 100%
   - Auto-rollback on failure

9. **Promote to production**
   ```bash
   git checkout main
   git merge staging
   git push
   ```

10. **Manual sync in production**
    ```bash
    argocd app sync sha-k8s-blog-prod
    ```

---

## Key Files & Locations

**Infrastructure:**
- `terraform/main.tf` - Local Kubernetes infrastructure
- `terraform/eks/` - AWS EKS infrastructure
- `terraform/environments/*.tfvars` - Environment configs

**Helm Charts:**
- `helm/microservices-app/` - Main application chart
- `helm/ai-agent/` - AI scoring agent
- `helm/ollama/` - Local LLM inference
- `helm/elk-stack/` - ELK logging stack

**Application:**
- `app/backend/main.py` - FastAPI backend with AI integration
- `app/frontend/src/App.tsx` - React frontend with AI score display
- `app/ai-agent/main_dual_model.py` - AI agent (Ollama/OpenAI)

**GitOps:**
- `argocd/app-of-apps.yaml` - ArgoCD master application
- `argocd/applications/*.yaml` - Environment-specific apps
- `.github/workflows/golden-pipeline.yaml` - CI/CD pipeline

---

## Additional Documentation

- [CLAUDE.md](CLAUDE.md) - Complete development guide
- [README.md](README.md) - Project overview
- [GETTING_STARTED.md](GETTING_STARTED.md) - Quick start
- [docs/REALTIME_AI_SCORING.md](docs/REALTIME_AI_SCORING.md) - AI deployment guide
- [docs/ELK_STACK_GUIDE.md](docs/ELK_STACK_GUIDE.md) - Logging guide
- [terraform/eks/README.md](terraform/eks/README.md) - EKS deployment guide

---

**Built with ❤️ for production-ready Kubernetes deployments**

*Demonstrating GitOps best practices with ArgoCD, Helm, AI/ML, and modern cloud-native security*

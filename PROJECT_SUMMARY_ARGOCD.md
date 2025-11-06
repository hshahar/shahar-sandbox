# Kubernetes Blog Platform - Project Summary

## 🎯 Project Overview

A production-ready, GitOps-powered blog platform for sharing Kubernetes knowledge, built with modern DevOps practices and automated deployment using ArgoCD.

### Purpose
- Share knowledge about Kubernetes features, security best practices, and CI/CD workflows
- Demonstrate GitOps principles with ArgoCD
- Showcase multi-environment deployment strategies
- Implement Kubernetes security best practices

---

## 🏗️ Architecture

### Technology Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| **GitOps** | ArgoCD | Automated deployment from Git |
| **Package Management** | Helm 3.x | Application templating and versioning |
| **Container Orchestration** | Kubernetes 1.25+ | Workload management |
| **Frontend** | React + Vite | Blog user interface |
| **Backend** | FastAPI (Python) | REST API for blog posts |
| **Database** | PostgreSQL 15 | Persistent data storage |
| **Ingress** | NGINX Ingress Controller | HTTP routing |
| **IaC** | Terraform | Infrastructure provisioning |
| **CI/CD** | GitHub Actions | Image builds and GitOps updates |
| **Local K8s** | Rancher Desktop | Development environment |

### Application Flow

```
Developer → Git Push → GitHub Actions → Build Images → Update Helm Values
                                                              ↓
                                                         Commit to Git
                                                              ↓
ArgoCD (Polls Git) → Detect Change → Helm Template → Deploy to K8s
                                                              ↓
                                      Frontend ← Ingress ← User Browser
                                          ↓
                                      Backend API
                                          ↓
                                      PostgreSQL
```

---

## 📁 Project Structure

```
k8s-blog-platform/
├── app/                              # Application Source Code
│   ├── backend/                      # FastAPI backend
│   │   ├── main.py                   # API endpoints for blog posts
│   │   ├── requirements.txt          # Python dependencies
│   │   └── Dockerfile                # Multi-stage Python image
│   └── frontend/                     # React frontend
│       ├── src/
│       │   ├── App.tsx               # Main React component
│       │   └── main.tsx              # Entry point
│       ├── package.json              # Node dependencies
│       ├── vite.config.ts            # Vite configuration
│       └── Dockerfile                # Multi-stage Node image
│
├── argocd/                           # ArgoCD Applications (GitOps)
│   ├── app-of-apps.yaml              # Master application
│   └── applications/
│       ├── dev-application.yaml      # Dev environment (auto-sync)
│       ├── staging-application.yaml  # Staging environment (auto-sync)
│       └── prod-application.yaml     # Production (manual sync)
│
├── helm/microservices-app/           # Helm Chart
│   ├── Chart.yaml                    # Chart metadata
│   ├── values.yaml                   # Default values
│   ├── values-dev.yaml               # Dev: 1 replica, 1Gi disk
│   ├── values-staging.yaml           # Staging: 2 replicas, 5Gi disk
│   ├── values-prod.yaml              # Production: 3 replicas, 10Gi disk
│   └── templates/
│       ├── frontend-deployment.yaml  # React deployment with SecurityContext
│       ├── backend-deployment.yaml   # FastAPI deployment with SecurityContext
│       ├── postgresql-statefulset.yaml # Database with PVC
│       ├── services.yaml             # ClusterIP services
│       ├── ingress.yaml              # HTTP routing
│       ├── configmaps.yaml           # Application configuration
│       ├── secrets.yaml              # Database credentials (base64)
│       ├── networkpolicy.yaml        # Network isolation rules
│       ├── kyverno-policies.yaml     # Admission policies
│       └── _helpers.tpl              # Helm template helpers
│
├── terraform/                        # Infrastructure as Code
│   ├── main.tf                       # ArgoCD + Ingress installation
│   ├── variables.tf                  # Configurable parameters
│   ├── outputs.tf                    # Terraform outputs
│   └── environments/
│       ├── dev.tfvars                # Dev configuration
│       ├── staging.tfvars            # Staging configuration
│       └── prod.tfvars               # Production configuration
│
├── .github/workflows/                # CI/CD Pipelines
│   └── build-and-push.yaml           # Build images, update Helm values
│
├── scripts/                          # Automation Scripts (PowerShell)
│   ├── deploy-argocd.ps1             # Full deployment automation
│   ├── sync-app.ps1                  # Manual ArgoCD sync
│   ├── setup.ps1                     # Initial cluster setup
│   └── cleanup.ps1                   # Resource cleanup
│
└── docs/                             # Documentation
    ├── ARGOCD_SETUP.md               # ArgoCD installation guide
    ├── GITOPS_WORKFLOW.md            # GitOps development workflow
    ├── SECURITY.md                   # Security implementation details
    └── ARCHITECTURE.md               # System architecture diagrams
```

---

## 🚀 Deployment Environments

### Development

- **Purpose**: Daily development and testing
- **Branch**: `develop`
- **Namespace**: `dev`
- **Sync Policy**: Automated (self-heal enabled)
- **Replicas**: 1 frontend, 1 backend
- **Disk**: 1Gi PostgreSQL storage
- **Security**: Pod Security Admission (baseline), NetworkPolicy enabled
- **Access**: http://dev.myapp.local

### Staging

- **Purpose**: Pre-production validation
- **Branch**: `staging`
- **Namespace**: `staging`
- **Sync Policy**: Automated (self-heal enabled)
- **Replicas**: 2 frontend, 2 backend (HPA enabled)
- **Disk**: 5Gi PostgreSQL storage
- **Security**: PSA (restricted), User Namespaces, Kyverno audit mode
- **Access**: http://staging.myapp.local

### Production

- **Purpose**: Live environment
- **Branch**: `main`
- **Namespace**: `production`
- **Sync Policy**: Manual approval required
- **Replicas**: 3 frontend, 3 backend (HPA enabled)
- **Disk**: 10Gi PostgreSQL storage
- **Security**: PSA (restricted), User Namespaces, Kyverno enforce mode
- **Access**: http://prod.myapp.local

---

## 🔄 GitOps Workflow

### 1. Development

```bash
# Create feature branch
git checkout -b feature/new-blog-category

# Make code changes
code app/backend/main.py

# Commit changes
git commit -m "feat: add new blog category endpoint"
git push origin feature/new-blog-category

# Create Pull Request
gh pr create
```

### 2. Automated Build (GitHub Actions)

```yaml
Trigger: Push to develop/staging/main
Steps:
  1. Validate Helm charts
  2. Build Docker images (backend + frontend)
  3. Tag images with branch-commitsha
  4. Push to ghcr.io
  5. Update Helm values-{env}.yaml with new image tags
  6. Commit values changes back to Git [skip ci]
```

### 3. ArgoCD Sync

```
ArgoCD (every 3 minutes):
  1. Poll Git repository
  2. Detect changes in helm/microservices-app/
  3. Compare desired state (Git) vs actual state (Kubernetes)
  4. Generate Kubernetes manifests from Helm
  5. Apply changes to cluster (rolling update)
  6. Monitor health and sync status
```

### 4. Verification

```powershell
# Check ArgoCD status
argocd app get k8s-blog-dev

# Watch Kubernetes deployment
kubectl get pods -n dev -w

# Test application
curl http://dev.myapp.local/api/health
```

---

## 🛡️ Security Implementation

### Pod Security Admission (PSA)

- **Dev**: `baseline` - Allows most workloads, prevents privilege escalation
- **Staging/Prod**: `restricted` - Enforces hardened security standards
- Applied via namespace labels in Terraform

### SecurityContext Hardening

All pods implement:
```yaml
securityContext:
  runAsNonRoot: true           # Prevent root execution
  runAsUser: 1000              # Explicit non-root UID
  fsGroup: 1000                # File ownership
  readOnlyRootFilesystem: true # Immutable filesystem
  allowPrivilegeEscalation: false
  seccompProfile:
    type: RuntimeDefault       # Syscall filtering
  capabilities:
    drop: ["ALL"]              # Drop all Linux capabilities
```

### NetworkPolicy

- **Default-Deny**: All traffic blocked by default
- **Explicit Allow Rules**:
  - Frontend ← Ingress Controller
  - Backend ← Frontend
  - PostgreSQL ← Backend only
  - All pods → DNS (kube-dns)
  - Backend → External APIs (configurable)

### Kyverno Policies (Staging/Prod)

1. **Image Verification**: Require signed images (cosign)
2. **Disallow Privileged**: Block privileged containers
3. **Require Read-Only**: Enforce read-only root filesystem
4. **Disallow Latest Tag**: Prevent `:latest` image tags
5. **Require Resource Limits**: Enforce CPU/memory limits

### User Namespaces (Staging/Prod)

- Host privilege isolation via `hostUsers: false`
- Requires Kubernetes 1.33+
- Maps container UIDs to different host UIDs

---

## 📊 Resource Requirements

### Minimum (Dev Environment)

| Component | CPU | Memory | Disk |
|-----------|-----|--------|------|
| ArgoCD | 750m | 896Mi | - |
| NGINX Ingress | 100m | 90Mi | - |
| Frontend | 100m | 128Mi | - |
| Backend | 200m | 256Mi | - |
| PostgreSQL | 250m | 256Mi | 1Gi |
| **Total** | **1.4 CPU** | **1.6 GB RAM** | **1 GB Disk** |

### Production Environment

| Component | CPU | Memory | Disk |
|-----------|-----|--------|------|
| ArgoCD | 1 CPU | 1.5 GB | - |
| NGINX Ingress | 200m | 256Mi | - |
| Frontend (3x) | 300m | 384Mi | - |
| Backend (3x) | 600m | 768Mi | - |
| PostgreSQL | 500m | 512Mi | 10Gi |
| **Total** | **2.6 CPU** | **3.4 GB RAM** | **10 GB Disk** |

---

## 🔧 Quick Start Guide

### Prerequisites

- Rancher Desktop (or any local Kubernetes cluster)
- Terraform >= 1.0
- Helm >= 3.x
- kubectl
- Git
- PowerShell 5.1+

### Installation (5 minutes)

```powershell
# 1. Clone repository
git clone https://github.com/yourusername/k8s-blog-platform.git
cd k8s-blog-platform

# 2. Deploy infrastructure
.\scripts\deploy-argocd.ps1 -Environment dev

# 3. Access ArgoCD
# Password displayed in terminal
Start-Process "http://argocd-dev.local"

# 4. Access application
Start-Process "http://dev.myapp.local"
```

### Update Application

```powershell
# Make code changes
code app/backend/main.py

# Commit and push
git add .
git commit -m "feat: add new endpoint"
git push origin develop

# GitHub Actions builds images (2-3 minutes)
# ArgoCD syncs automatically (1-3 minutes)

# Monitor deployment
argocd app wait k8s-blog-dev
kubectl get pods -n dev -w
```

---

## 🎓 Key Learnings and Benefits

### GitOps Advantages

✅ **Declarative**: Infrastructure as code in Git  
✅ **Version Controlled**: Full audit trail  
✅ **Automated**: Push to Git triggers deployment  
✅ **Rollback**: Revert Git commit to rollback  
✅ **Drift Detection**: ArgoCD ensures Git = Cluster  
✅ **Multi-Environment**: Manage all envs from one repo  

### ArgoCD vs Traditional CI/CD

| Aspect | Traditional CI/CD | ArgoCD GitOps |
|--------|------------------|---------------|
| Deployment | CI pushes to cluster | ArgoCD pulls from Git |
| Credentials | CI needs cluster access | Pull-based (more secure) |
| Drift Detection | None | Automatic |
| Rollback | Manual/complex | Git revert |
| Audit Trail | Limited | Full Git history |
| Multi-Cluster | Complex | Native support |

---

## 🤝 Contributing

1. Fork repository
2. Create feature branch (`git checkout -b feature/amazing`)
3. Commit changes (`git commit -m 'feat: add amazing feature'`)
4. Push branch (`git push origin feature/amazing`)
5. Open Pull Request
6. ArgoCD deploys to dev after merge

---

## 📞 Support

- **Issues**: GitHub Issues
- **Documentation**: `/docs` folder
- **ArgoCD UI**: http://argocd-dev.local
- **Application**: http://dev.myapp.local

---

## 📝 License

MIT License - See LICENSE file

---

## 🙏 Acknowledgments

- **ArgoCD Team**: For excellent GitOps tool
- **Helm Community**: For package management
- **Kubernetes Community**: For container orchestration
- **FastAPI**: For modern Python web framework
- **React Team**: For UI library

---

**Built with ❤️ for the Kubernetes community**

*Demonstrating GitOps best practices with ArgoCD, Helm, and Kubernetes security in 2025*

---

## 📈 Project Stats

- **Files**: 48+ source files
- **Documentation**: 14 markdown files (English)
- **Helm Templates**: 12 Kubernetes resource types
- **ArgoCD Applications**: 3 environments
- **Terraform Modules**: Infrastructure automation
- **CI/CD Pipelines**: GitHub Actions
- **Security Features**: PSA, NetworkPolicy, SecurityContext, Kyverno, User Namespaces
- **Languages**: Python (Backend), TypeScript/React (Frontend), HCL (Terraform), YAML (K8s/Helm)

---

**Last Updated**: November 6, 2025  
**Kubernetes Version**: 1.25+  
**ArgoCD Version**: 2.13+  
**Project Status**: Production-Ready

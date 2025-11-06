# SHA's Kubernetes Blog Platform with ArgoCD

A modern GitOps-based blog platform for sharing Kubernetes knowledge, best practices, security insights, and CI/CD workflows. Built with ArgoCD for automated deployment and Helm for package management.

Personalized for **SHA** with custom naming conventions throughout the infrastructure.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     ArgoCD (GitOps)                     │
│   Automated sync from Git → Kubernetes deployments     │
└─────────────────────────────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        ▼                  ▼                  ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│   Dev Env     │  │ Staging Env   │  │  Prod Env     │
│   (Auto-sync) │  │  (Auto-sync)  │  │ (Manual sync) │
└───────────────┘  └───────────────┘  └───────────────┘

Each Environment Contains:
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Frontend   │────▶│   Backend    │────▶│  PostgreSQL  │
│   (React)    │     │  (FastAPI)   │     │   Database   │
└──────────────┘     └──────────────┘     └──────────────┘
       │                                            │
       └────────────── NGINX Ingress ──────────────┘
```

## 📚 Technology Stack

### Core Infrastructure
- **GitOps**: ArgoCD for declarative deployment
- **Package Management**: Helm Charts with multi-environment values
- **Container Orchestration**: Kubernetes (Rancher Desktop)
- **CNI**: Calico for NetworkPolicy enforcement
- **IaC**: Terraform for infrastructure automation
- **Ingress**: NGINX Ingress Controller

### Application Stack
- **Frontend**: React.js + Vite (blog UI)
- **Backend**: FastAPI (Python REST API)
- **Database**: PostgreSQL 15

### CI/CD & Deployment
- **CI/CD Pipeline**: GitHub Actions (multi-stage golden pipeline)
- **Progressive Delivery**: Argo Rollouts (Canary deployments with auto-rollback)
- **Autoscaling**: KEDA (event-driven autoscaling with 80+ scalers)
- **Container Signing**: Cosign (keyless signing with Sigstore)
- **SBOM Generation**: Syft (SPDX format)
- **Security Scanning**: Trivy (filesystem + container images)
- **Policy Enforcement**: Kyverno (runtime validation)

### Monitoring & Observability
- **Metrics**: Prometheus (time-series database)
- **Dashboards**: Grafana (P95 latency, error rate, CPU/Mem, uptime)
- **Service Monitoring**: ServiceMonitors for all components
- **Alerts**: AlertManager (production only)

### Security
- **Network Security**: Calico CNI with NetworkPolicies (default-deny)
- **Secrets Management**: HashiCorp Vault + External Secrets Operator
- **Pod Security**: PSA (baseline dev, restricted staging/prod)
- **Container Security**: Non-root users, read-only filesystem, capabilities dropped
- **Runtime Security**: Kyverno policies, seccomp profiles
- **User Namespaces**: Enabled in staging/production

## 🚀 Quick Start

### Prerequisites

- **Rancher Desktop** (or any local Kubernetes cluster)
- **Terraform** >= 1.0
- **Helm** >= 3.x
- **kubectl**
- **Git**
- **PowerShell** (for automation scripts)

### 1. Clone Repository

```powershell
git clone https://github.com/yourusername/k8s-blog-platform.git
cd k8s-blog-platform
```

### 2. Initialize Infrastructure

```powershell
# Deploy infrastructure (Ingress, ArgoCD)
cd terraform
terraform init
terraform apply -var-file="environments/dev.tfvars"
```

This will install:
- NGINX Ingress Controller
- Calico CNI for NetworkPolicy support
- ArgoCD with UI
- Namespace with Pod Security Standards

### 3. Verify Calico Installation

```powershell
# Check Calico pods
kubectl get pods -n calico-system

# Verify NetworkPolicy support
.\scripts\verify-calico.ps1 -Namespace dev
```

### 4. Access ArgoCD

```powershell
# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

# Add to hosts file
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "127.0.0.1 argocd-dev.local"

# Open browser
Start-Process "http://argocd-dev.local"
```

Login: `admin` / [password from above]

### 4. Deploy Applications via ArgoCD

```powershell
# Apply the App-of-Apps pattern
kubectl apply -f argocd/app-of-apps.yaml

# ArgoCD will automatically deploy all environments
# Check status:
kubectl get applications -n argocd
argocd app list
```

### 5. Access Blog Platform

```powershell
# Add to hosts file
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "127.0.0.1 dev.myapp.local"

# Open browser
Start-Process "http://dev.myapp.local"
```

## 📖 Documentation

**📚 [COMPLETE DOCUMENTATION INDEX](DOCUMENTATION_INDEX.md)** - Master index of all 28 documents organized by category and role

### Getting Started
- **[Quick Start Guide](GETTING_STARTED.md)** - Get up and running in 10 minutes
- **[Quick Start (Fastest)](QUICKSTART.md)** - Absolute fastest path
- **[ArgoCD Setup Guide](./docs/ARGOCD_SETUP.md)** - Complete ArgoCD installation and configuration
- **[GitOps Workflow](./docs/GITOPS_WORKFLOW.md)** - Development and deployment workflow
- **[Monitoring Access](./docs/MONITORING_ACCESS.md)** - Credentials and access to Grafana, ArgoCD, Prometheus

### CI/CD & Deployments
- **[CI/CD Pipeline](./docs/CI_CD_PIPELINE.md)** - Golden pipeline with security scanning, signing, SBOM
- **[Progressive Delivery](./docs/PROGRESSIVE_DELIVERY.md)** - Canary deployments with Argo Rollouts
- **[Application Deployment](./docs/APPLICATION_DEPLOYMENT.md)** - Build and deploy React/FastAPI applications

### Infrastructure & Operations
- **[Terraform S3 Backend](./docs/TERRAFORM_S3_BACKEND.md)** - Remote state management for team collaboration
- **[KEDA Autoscaling](./docs/KEDA_AUTOSCALING.md)** - Event-driven autoscaling with Prometheus, queues, cron

### Security & Operations
- **[Security Implementation](./docs/SECURITY.md)** - Network policies, PSA, Vault, Kyverno
- **[Vault Guide](./docs/VAULT_GUIDE.md)** - HashiCorp Vault secrets management

### Reference & Troubleshooting
- **[Architecture](ARCHITECTURE.md)** - System design and components
- **[Troubleshooting](TROUBLESHOOTING.md)** - Common issues and solutions
- **[Cheat Sheet](CHEATSHEET.md)** - Quick command reference
- **[Quick Reference](QUICK_REFERENCE.md)** - Common tasks
- **[Helm Chart Documentation](./helm/microservices-app/README.md)** - Chart structure and values

### Project Information
- **[Improvements Summary](IMPROVEMENTS_SUMMARY.md)** - Recent enhancements and upgrades
- **[Contributing Guide](CONTRIBUTING.md)** - How to contribute

## 🔧 Project Structure

```
k8s-blog-platform/
├── app/                          # Application source code
│   ├── frontend/                 # React blog frontend
│   │   ├── src/
│   │   ├── Dockerfile
│   │   └── package.json
│   └── backend/                  # FastAPI backend
│       ├── main.py
│       ├── Dockerfile
│       └── requirements.txt
│
├── argocd/                       # ArgoCD GitOps manifests
│   ├── app-of-apps.yaml          # Master application
│   └── applications/             # Environment applications
│       ├── dev-application.yaml
│       ├── staging-application.yaml
│       └── prod-application.yaml
│
├── helm/                         # Helm Charts
│   └── microservices-app/        # Main application chart
│       ├── Chart.yaml
│       ├── values.yaml           # Default values
│       ├── values-dev.yaml       # Dev overrides (1Gi disk)
│       ├── values-staging.yaml   # Staging overrides (5Gi disk)
│       ├── values-prod.yaml      # Production overrides (10Gi disk)
│       └── templates/            # Kubernetes manifests
│           ├── frontend-deployment.yaml
│           ├── backend-deployment.yaml
│           ├── postgresql-statefulset.yaml
│           ├── services.yaml
│           ├── ingress.yaml
│           ├── networkpolicy.yaml
│           └── secrets.yaml
│
├── terraform/                    # Infrastructure as Code
│   ├── main.tf                   # Main Terraform config (ArgoCD, Ingress)
│   ├── variables.tf
│   ├── outputs.tf
│   └── environments/
│       ├── dev.tfvars            # Dev config (minimal resources)
│       ├── staging.tfvars
│       └── prod.tfvars
│
├── .github/                      # CI/CD pipelines
│   └── workflows/
│       ├── build-images.yaml     # Build and push Docker images
│       └── sync-argocd.yaml      # Trigger ArgoCD sync
│
├── scripts/                      # Automation scripts
│   ├── setup.ps1                 # Initial setup
│   ├── deploy-argocd.ps1         # ArgoCD deployment
│   ├── sync-app.ps1              # Manual sync application
│   └── cleanup.ps1               # Cleanup resources
│
└── docs/                         # Documentation
    ├── ARGOCD_SETUP.md
    ├── GITOPS_WORKFLOW.md
    ├── SECURITY.md
    └── ARCHITECTURE.md
```

## 🔄 GitOps Workflow

### Development Flow

```
Developer         GitHub Actions       ArgoCD           Kubernetes
    │                   │                 │                 │
    │ 1. Push code      │                 │                 │
    ├──────────────────▶│                 │                 │
    │                   │ 2. Build image  │                 │
    │                   │    Sign + SBOM  │                 │
    │                   │                 │                 │
    │                   │ 3. Update       │                 │
    │                   │    Helm values  │                 │
    │                   ├────────────────▶│                 │
    │                   │                 │ 4. Detect       │
    │                   │                 │    changes      │
    │                   │                 │                 │
    │                   │                 │ 5. Sync         │
    │                   │                 ├────────────────▶│
    │                   │                 │                 │
    │                   │                 │ 6. Canary       │
    │                   │                 │    Rollout      │
    │                   │                 │    (10→25→50%)  │
    │                   │                 │                 │
    │                   │                 │ 7. Full deploy  │
    │                   │                 │    or rollback  │
    │                   │                 │                 │
```

### Deployment Environments

| Environment | Branch | Sync Policy | Canary | Replicas | Disk | Auto-Heal |
|------------|--------|-------------|--------|----------|------|-----------|
| **Dev** | `develop` | Auto-sync | ❌ No | 1 | 1Gi | ✅ Yes |
| **Staging** | `staging` | Auto-sync | ✅ Yes | 2 | 5Gi | ✅ Yes |
| **Production** | `main` | Manual | ✅ Yes | 3 | 10Gi | ❌ No |

### CI/CD Pipeline Stages

```
┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
│   Lint   │──▶│ Security │──▶│  Build   │──▶│   Scan   │
│  & Test  │   │   Scan   │   │  Images  │   │  Images  │
└──────────┘   └──────────┘   └──────────┘   └──────────┘
                                                    │
┌──────────┐   ┌──────────┐   ┌──────────┐        │
│  Deploy  │◀──│  Policy  │◀──│   SBOM   │◀───────┘
│  (GitOps)│   │  Check   │   │  + Sign  │
└──────────┘   └──────────┘   └──────────┘
```

**Pipeline Features**:
- Trivy security scanning (SARIF reports)
- Cosign image signing (keyless)
- Syft SBOM generation (SPDX format)
- Kyverno policy validation
- Automated Helm values updates

## 🛡️ Security Features

### Supply Chain Security
- **Container Signing**: Cosign with Sigstore (keyless signing)
- **SBOM Generation**: Complete dependency inventory (SPDX format)
- **Vulnerability Scanning**: Trivy for source code and images
- **Policy Enforcement**: Kyverno runtime validation
- **Image Verification**: Signature checks before deployment

### Network Security
- **CNI**: Calico for advanced NetworkPolicy support
- **Default-Deny**: All ingress traffic blocked by default
- **Explicit Allow**: Only required connections permitted
- **Namespace Isolation**: Traffic segmentation between environments

### Pod Security
- **Pod Security Admission**: Baseline (dev), Restricted (staging/prod)
- **Non-root Users**: All containers run as UID 1000
- **Read-only Filesystem**: Immutable container filesystems
- **Seccomp Profiles**: RuntimeDefault profile enforced
- **Capabilities**: All capabilities dropped
- **User Namespaces**: Host privilege isolation (staging/prod)

### Secrets Management
- **HashiCorp Vault**: Centralized secrets storage
- **External Secrets Operator**: Auto-sync Vault → Kubernetes
- **Dynamic Secrets**: On-demand credential generation
- **Secret Rotation**: Automated credential updates
- **Audit Logging**: Complete access trail

## 📊 Monitoring & Observability

### Grafana Dashboards

Access: `http://grafana-{env}.local` (default password: `admin`)

**Key Metrics**:
- **Request Rate**: Requests per second by service
- **Error Rate**: Percentage of failed requests (5xx errors)
- **Latency P95**: 95th percentile response time
- **CPU Usage**: Per-pod CPU consumption
- **Memory Usage**: Per-pod memory consumption
- **Pod Uptime**: Ready pods ratio
- **Active Rollouts**: Canary deployment progress
- **Database Connections**: Connection pool utilization
- **Network I/O**: RX/TX bandwidth usage

### Prometheus Metrics

Exposed metrics endpoints:
- Backend: `/metrics` (HTTP requests, latency, errors)
- Frontend: `/metrics` (Nginx stats)
- PostgreSQL: Exporter with connection metrics

### Alerts (Production Only)

Configured AlertManager rules:
- Error rate > 1%
- P95 latency > 300ms
- CPU usage > 80%
- Memory usage > 85%
- Pod not ready for > 5 minutes

## 📊 Blog Platform Features

### Content Management
- ✅ Create/Edit/Delete posts about Kubernetes topics
- ✅ Categories: Features, Security, CI/CD, Best Practices
- ✅ Markdown support for technical content
- ✅ Code syntax highlighting
- ✅ Tags and search functionality
- ✅ User authentication and authorization

### Topics Covered
- 🚀 **New Kubernetes Features**: Latest releases, APIs, enhancements
- 🔒 **Security Best Practices**: Pod Security, NetworkPolicy, Kyverno
- 🔄 **CI/CD Workflows**: GitOps, ArgoCD, GitHub Actions
- 📦 **Package Management**: Helm, Kustomize, Operators
- 🏗️ **Architecture Patterns**: Microservices, Service Mesh, Observability

## 🔨 Development

### Build and Run Locally

```powershell
# Build Docker images
docker build -t k8s-blog-frontend:latest ./app/frontend
docker build -t k8s-blog-backend:latest ./app/backend

# Push to registry (replace with your registry)
docker tag k8s-blog-frontend:latest ghcr.io/yourusername/k8s-blog-frontend:latest
docker push ghcr.io/yourusername/k8s-blog-frontend:latest
```

### Update Application

```powershell
# Make changes to code
# Commit and push
git add .
git commit -m "feat: add new blog post feature"
git push origin develop

# GitHub Actions builds new image
# ArgoCD detects change and deploys automatically (1-3 minutes)
```

### Manual Sync with ArgoCD

```powershell
# Sync specific environment
argocd app sync sha-k8s-blog-dev

# Or use script
.\scripts\sync-app.ps1 -Environment dev

# Force hard refresh
argocd app sync sha-k8s-blog-dev --force
```

### View Sync Status

```powershell
# Check all applications
kubectl get applications -n argocd

# Get detailed status
argocd app get sha-k8s-blog-dev

# View sync history
argocd app history sha-k8s-blog-dev
```

## 📈 Monitoring & Observability

### ArgoCD Dashboard

Access the ArgoCD UI to monitor:
- Application health status
- Sync status and history
- Resource tree visualization
- Event logs and errors
- Git commit information

### Application Health

```powershell
# Check application health
kubectl get applications -n argocd
argocd app list

# View pod status
kubectl get pods -n dev
kubectl get pods -n staging
kubectl get pods -n production

# Check logs
kubectl logs -n dev deployment/frontend -f
kubectl logs -n dev deployment/backend -f
```

### Resource Usage

```powershell
# Check resource usage (requires metrics-server)
kubectl top nodes
kubectl top pods -n dev
kubectl top pods -n staging
```

## 🧹 Cleanup

```powershell
# Remove all applications via ArgoCD
kubectl delete -f argocd/app-of-apps.yaml

# Or delete individually
kubectl delete application k8s-blog-dev -n argocd
kubectl delete application k8s-blog-staging -n argocd
kubectl delete application k8s-blog-prod -n argocd

# Destroy infrastructure
cd terraform
terraform destroy -var-file="environments/dev.tfvars"
```

## 🎯 Why ArgoCD?

### GitOps Benefits

1. **Git as Single Source of Truth**: All configuration in version control
2. **Automated Deployment**: Changes automatically deployed on git push
3. **Rollback Capability**: Easy rollback to any previous Git commit
4. **Audit Trail**: Full history of who changed what and when
5. **Drift Detection**: ArgoCD detects manual changes and can revert them
6. **Multi-Environment Management**: Manage dev/staging/prod from one place

### vs Traditional Deployment

| Traditional CI/CD | ArgoCD GitOps |
|------------------|---------------|
| kubectl apply in CI pipeline | ArgoCD pulls from Git |
| No drift detection | Automatic drift detection |
| Manual rollback | Git revert = instant rollback |
| Push-based | Pull-based (more secure) |
| Hard to audit | Full Git history |
| Environment inconsistency | Declarative consistency |

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'feat: add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request
6. ArgoCD will deploy to dev automatically after merge

## 📝 ArgoCD Commands Cheatsheet

```powershell
# Login to ArgoCD CLI
argocd login sha-argocd-dev.local --username admin --insecure

# List applications
argocd app list

# Get application details
argocd app get sha-k8s-blog-dev

# Sync application
argocd app sync sha-k8s-blog-dev

# View sync status
argocd app wait sha-k8s-blog-dev

# View application history
argocd app history sha-k8s-blog-dev

# Rollback to previous version
argocd app rollback sha-k8s-blog-dev 1

# View application logs
argocd app logs sha-k8s-blog-dev

# Delete application
argocd app delete sha-k8s-blog-dev
```

## 🌟 Features Roadmap

- [x] ArgoCD GitOps deployment
- [x] Multi-environment support
- [x] Security hardening (PSA, NetworkPolicy, SecurityContext)
- [x] Helm chart templating
- [ ] OAuth2 authentication
- [ ] Comment system with moderation
- [ ] RSS feed generation
- [ ] Email notifications for new posts
- [ ] Analytics dashboard
- [ ] Multi-language support
- [ ] Dark mode
- [ ] GraphQL API
- [ ] Elasticsearch for search
- [ ] Prometheus + Grafana monitoring
- [ ] Distributed tracing with Jaeger

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/k8s-blog-platform/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/k8s-blog-platform/discussions)
- **Documentation**: [Wiki](https://github.com/yourusername/k8s-blog-platform/wiki)

## 🙏 Acknowledgments

- Kubernetes community
- ArgoCD project team
- Helm community
- All open-source contributors

## 📜 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file.

---

**Built with ❤️ for the Kubernetes community**

*Demonstrating GitOps best practices with ArgoCD, Helm, and modern Kubernetes security*

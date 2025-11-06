# ArgoCD Setup and Configuration Guide

Complete guide for setting up ArgoCD with the Kubernetes Blog Platform.

## Table of Contents

1. [What is ArgoCD?](#what-is-argocd)
2. [Installation](#installation)
3. [Initial Configuration](#initial-configuration)
4. [Application Deployment](#application-deployment)
5. [GitOps Workflow](#gitops-workflow)
6. [Troubleshooting](#troubleshooting)

---

## What is ArgoCD?

ArgoCD is a declarative, GitOps continuous delivery tool for Kubernetes. It automates the deployment of applications by monitoring Git repositories and synchronizing changes to your Kubernetes cluster.

### Key Features

- **Declarative**: All configuration stored in Git
- **Automated**: Continuous synchronization from Git to Kubernetes
- **Auditable**: Full deployment history and Git commit tracking
- **Rollback**: Easy rollback to any previous state
- **Multi-Cluster**: Manage multiple clusters from single instance
- **Health Assessment**: Real-time application health monitoring

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Git Repository                       │
│  (Helm Charts, Kubernetes Manifests, Values Files)     │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                      ArgoCD Server                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ Application  │  │ Repo Server  │  │  Controller  │ │
│  │ Controller   │  │              │  │              │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                  Kubernetes Cluster                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐│
│  │   Dev    │  │ Staging  │  │   Prod   │  │ ...     ││
│  │Namespace │  │Namespace │  │Namespace │  │         ││
│  └──────────┘  └──────────┘  └──────────┘  └─────────┘│
└─────────────────────────────────────────────────────────┘
```

---

## Installation

### Method 1: Via Terraform (Recommended)

Our Terraform configuration automatically installs ArgoCD:

```powershell
cd terraform
terraform init
terraform apply -var-file="environments/dev.tfvars"
```

This installs:
- ArgoCD server, controller, and repo server
- NGINX Ingress Controller
- Calico CNI for NetworkPolicy enforcement
- Minimal resource configuration for local development

### Verify Calico Installation

```powershell
# Check Calico pods
kubectl get pods -n calico-system -l k8s-app=calico-node

# Verify NetworkPolicy support
kubectl get networkpolicy -A

# Run verification script
.\scripts\verify-calico.ps1 -Namespace dev
```

### Method 2: Manual Helm Installation

```powershell
# Add ArgoCD Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install ArgoCD
helm install argocd argo/argo-cd `
  --namespace argocd `
  --create-namespace `
  --set server.ingress.enabled=true `
  --set server.ingress.ingressClassName=nginx `
  --set server.ingress.hosts[0]=argocd-dev.local `
  --set server.extraArgs[0]="--insecure"

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

### Method 3: Manifest Installation

```powershell
# Install ArgoCD via official manifests
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Expose with port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

---

## Initial Configuration

### 1. Access ArgoCD UI

```powershell
# Get initial admin password
$password = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
$decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($password))
Write-Host "ArgoCD Password: $decoded"

# Add to hosts file
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "127.0.0.1 argocd-dev.local"

# Open browser
Start-Process "http://argocd-dev.local"
```

Login credentials:
- **Username**: `admin`
- **Password**: [output from above command]

### 2. Install ArgoCD CLI (Optional but Recommended)

```powershell
# Download latest release
$version = "v2.13.2"  # Latest as of Nov 2025
Invoke-WebRequest -Uri "https://github.com/argoproj/argo-cd/releases/download/$version/argocd-windows-amd64.exe" -OutFile "argocd.exe"

# Move to PATH
Move-Item argocd.exe C:\Windows\System32\argocd.exe

# Verify installation
argocd version

# Login via CLI
argocd login argocd-dev.local --username admin --insecure
```

### 3. Change Admin Password

```powershell
# Via CLI
argocd account update-password

# Or via UI: User Info → Update Password
```

### 4. Configure Git Repository

#### Public Repository (No Auth Required)

```powershell
# Via CLI
argocd repo add https://github.com/yourusername/k8s-blog-platform.git

# Or via UI: Settings → Repositories → Connect Repo
```

#### Private Repository (SSH Key)

```powershell
# Generate SSH key
ssh-keygen -t ed25519 -C "argocd@k8s-blog-platform" -f ~/.ssh/argocd_ed25519

# Add public key to GitHub: Settings → SSH Keys → New SSH key
Get-Content ~/.ssh/argocd_ed25519.pub

# Add to ArgoCD
argocd repo add git@github.com:yourusername/k8s-blog-platform.git `
  --ssh-private-key-path ~/.ssh/argocd_ed25519
```

#### Private Repository (HTTPS Token)

```powershell
# Create GitHub Personal Access Token
# GitHub → Settings → Developer settings → Personal access tokens

# Add to ArgoCD
argocd repo add https://github.com/yourusername/k8s-blog-platform.git `
  --username yourusername `
  --password ghp_yourtoken
```

---

## Application Deployment

### App-of-Apps Pattern

We use the **App-of-Apps pattern** where a single Application manages all other Applications.

#### 1. Deploy Master Application

```powershell
# Apply the App-of-Apps
kubectl apply -f argocd/app-of-apps.yaml

# Verify deployment
kubectl get application -n argocd
```

#### 2. Verify Applications

```powershell
# Check all applications
argocd app list

# Expected output:
NAME              CLUSTER                         NAMESPACE   PROJECT  STATUS  HEALTH
app-of-apps       https://kubernetes.default.svc  argocd      default  Synced  Healthy
k8s-blog-dev      https://kubernetes.default.svc  dev         default  Synced  Healthy
k8s-blog-staging  https://kubernetes.default.svc  staging     default  Synced  Healthy
k8s-blog-prod     https://kubernetes.default.svc  production  default  Synced  Healthy
```

### Manual Application Creation

If you prefer not to use App-of-Apps:

```powershell
# Create dev application via CLI
argocd app create k8s-blog-dev `
  --repo https://github.com/yourusername/k8s-blog-platform.git `
  --path helm/microservices-app `
  --dest-server https://kubernetes.default.svc `
  --dest-namespace dev `
  --helm-set-file values=helm/microservices-app/values-dev.yaml `
  --sync-policy automated `
  --auto-prune `
  --self-heal

# Sync application
argocd app sync k8s-blog-dev
```

### Application Sync Policies

#### Auto-Sync (Dev/Staging)

```yaml
syncPolicy:
  automated:
    prune: true      # Delete resources removed from Git
    selfHeal: true   # Revert manual changes
    allowEmpty: false
  syncOptions:
    - CreateNamespace=true
```

#### Manual Sync (Production)

```yaml
syncPolicy:
  syncOptions:
    - CreateNamespace=true
  # No automated sync - requires manual approval
```

---

## GitOps Workflow

### Development Workflow

```
┌──────────────┐
│ 1. Developer │
│ Code Change  │
└───────┬──────┘
        │
        ▼
┌──────────────┐
│  2. Git Push │
│  to develop  │
└───────┬──────┘
        │
        ▼
┌───────────────┐
│ 3. GitHub     │
│ Actions Build │
│ Docker Image  │
└───────┬───────┘
        │
        ▼
┌───────────────┐
│ 4. Update     │
│ Helm Values   │
│ (image tag)   │
└───────┬───────┘
        │
        ▼
┌───────────────┐
│ 5. ArgoCD     │
│ Detects Change│
│ (1-3 minutes) │
└───────┬───────┘
        │
        ▼
┌───────────────┐
│ 6. Auto-Sync  │
│ to Kubernetes │
│ Dev Namespace │
└───────────────┘
```

### Step-by-Step Example

#### 1. Make Code Changes

```powershell
# Edit backend code
code app/backend/main.py

# Add new feature
# ...
```

#### 2. Commit and Push

```powershell
git add app/backend/main.py
git commit -m "feat: add new blog post endpoint"
git push origin develop
```

#### 3. GitHub Actions Builds Image

`.github/workflows/build-images.yaml` automatically:
- Builds Docker image
- Tags with commit SHA: `ghcr.io/yourusername/k8s-blog-backend:abc123`
- Pushes to container registry
- Updates `helm/microservices-app/values-dev.yaml` with new tag

#### 4. ArgoCD Syncs

ArgoCD polls Git every 3 minutes (default) and detects the change:

```powershell
# Monitor sync progress
argocd app get k8s-blog-dev --refresh

# Watch live
argocd app wait k8s-blog-dev
```

#### 5. Verify Deployment

```powershell
# Check pod rollout
kubectl get pods -n dev -w

# Check application
curl http://dev.myapp.local/api/health
```

### Rollback to Previous Version

```powershell
# View deployment history
argocd app history k8s-blog-dev

# Output:
ID  DATE                   REVISION
3   2025-11-06 10:30:15    abc123 (HEAD)
2   2025-11-06 09:15:42    xyz789
1   2025-11-06 08:00:00    def456

# Rollback to revision 2
argocd app rollback k8s-blog-dev 2

# Or revert Git commit and let ArgoCD sync
git revert abc123
git push origin develop
```

### Promote to Staging

```powershell
# Merge develop to staging branch
git checkout staging
git merge develop
git push origin staging

# ArgoCD auto-syncs staging environment
argocd app wait k8s-blog-staging
```

### Promote to Production

```powershell
# Create release tag
git checkout main
git merge staging
git tag -a v1.2.3 -m "Release v1.2.3"
git push origin main --tags

# Manual sync required for production
argocd app sync k8s-blog-prod

# Or via UI: k8s-blog-prod → Sync → Synchronize
```

---

## Advanced Configuration

### 1. Configure Sync Frequency

```powershell
# Default is 3 minutes, change to 1 minute
kubectl patch configmap argocd-cm -n argocd --type merge -p '
{
  "data": {
    "timeout.reconciliation": "60s"
  }
}'

# Restart ArgoCD
kubectl rollout restart deployment argocd-application-controller -n argocd
```

### 2. Enable Notifications

```powershell
# Install ArgoCD Notifications
helm upgrade argocd argo/argo-cd -n argocd `
  --set notifications.enabled=true `
  --set notifications.notifiers.slack.enabled=true

# Configure Slack webhook
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  service.slack: |
    token: $slack-token
  trigger.on-deployed: |
    - when: app.status.operationState.phase in ['Succeeded']
      send: [app-deployed]
  template.app-deployed: |
    message: |
      Application {{.app.metadata.name}} deployed successfully!
      Revision: {{.app.status.sync.revision}}
EOF
```

### 3. Configure Resource Exclusions

Exclude certain resources from sync:

```powershell
kubectl patch configmap argocd-cm -n argocd --type merge -p '
{
  "data": {
    "resource.exclusions": |
      - apiGroups:
        - "*"
        kinds:
        - Secret
        clusters:
        - "*"
        name: "argocd-*"
  }
}'
```

### 4. Enable Metrics and Monitoring

```powershell
# Expose ArgoCD metrics
kubectl port-forward -n argocd svc/argocd-metrics 8082:8082

# Scrape with Prometheus
# Add to prometheus.yml:
scrape_configs:
  - job_name: 'argocd'
    static_configs:
      - targets: ['argocd-metrics.argocd.svc:8082']
```

---

## Troubleshooting

### Application Stuck in "Progressing"

```powershell
# Check application status
argocd app get k8s-blog-dev

# View recent events
argocd app logs k8s-blog-dev

# Check pod status
kubectl get pods -n dev
kubectl describe pod <pod-name> -n dev

# Force hard refresh
argocd app sync k8s-blog-dev --force
```

### "OutOfSync" Status

```powershell
# View diff between Git and cluster
argocd app diff k8s-blog-dev

# Manual sync
argocd app sync k8s-blog-dev

# Enable auto-sync if disabled
argocd app set k8s-blog-dev --sync-policy automated
```

### Git Repository Connection Failed

```powershell
# Test repository connection
argocd repo get https://github.com/yourusername/k8s-blog-platform.git

# Re-add repository
argocd repo rm https://github.com/yourusername/k8s-blog-platform.git
argocd repo add https://github.com/yourusername/k8s-blog-platform.git
```

### Helm Template Errors

```powershell
# Validate Helm chart locally
helm template k8s-blog ./helm/microservices-app -f helm/microservices-app/values-dev.yaml

# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-repo-server -f
```

### Slow Sync Performance

```powershell
# Increase sync timeout
argocd app set k8s-blog-dev --sync-option Timeout=600

# Check resource limits
kubectl top pods -n argocd
kubectl describe pod -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### Reset ArgoCD Admin Password

```powershell
# Generate new password
$newPassword = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 16 | % {[char]$_})

# Update secret
kubectl patch secret argocd-secret -n argocd `
  -p '{"stringData": {"admin.password": "'$(echo -n $newPassword | argocd account bcrypt --stdin)'"}}'

Write-Host "New password: $newPassword"
```

---

## Best Practices

### 1. Use App-of-Apps Pattern
- Single entry point for all applications
- Easier management and GitOps workflow

### 2. Separate Environments
- Different branches/paths for dev/staging/prod
- Manual sync for production

### 3. Resource Limits
- Set appropriate CPU/memory limits in Helm values
- Monitor resource usage

### 4. Secrets Management
- Never commit secrets to Git
- Use External Secrets Operator or Sealed Secrets

### 5. Sync Waves
- Order resource creation with `argocd.argoproj.io/sync-wave`
- Example: Create namespace → Deploy database → Deploy app

### 6. Health Checks
- Configure custom health checks for complex apps
- Use `argocd.argoproj.io/health` annotations

### 7. Prune and Self-Heal
- Enable for dev/staging
- Disable or be cautious in production

---

## Additional Resources

- **ArgoCD Documentation**: https://argo-cd.readthedocs.io/
- **ArgoCD GitHub**: https://github.com/argoproj/argo-cd
- **Best Practices**: https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/
- **Examples**: https://github.com/argoproj/argocd-example-apps

---

**Next Steps**: See [GITOPS_WORKFLOW.md](./GITOPS_WORKFLOW.md) for detailed workflow examples.

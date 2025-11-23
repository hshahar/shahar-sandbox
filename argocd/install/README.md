# ArgoCD Installation Guide

This directory contains scripts and configuration files to install ArgoCD on your Kubernetes cluster.

## Prerequisites

- Kubernetes cluster (Docker Desktop, Minikube, kind, or cloud provider)
- `kubectl` configured and connected to your cluster
- `helm` v3+ installed
- Ingress controller (nginx) installed

## Installation Steps

### Option 1: Using PowerShell (Windows)

1. **Install ArgoCD:**
   ```powershell
   cd argocd/install
   .\00-install-argocd.ps1
   ```

2. **Install App-of-Apps:**
   ```powershell
   .\02-install-apps.ps1
   ```

### Option 2: Using Bash (Linux/Mac/WSL)

1. **Install ArgoCD:**
   ```bash
   cd argocd/install
   chmod +x *.sh
   ./00-install-argocd.sh
   ```

2. **Install App-of-Apps:**
   ```bash
   ./02-install-apps.sh
   ```

## Configuration Files

- **01-values-argocd.yaml** - ArgoCD Helm values with ingress, RBAC, and repository configuration
- **03-values-apps.yaml** - App-of-Apps pattern configuration with AppProject and root Application

## Accessing ArgoCD

After installation:

1. **URL:** http://sha-argocd.blog.local (or your configured domain)
2. **Username:** `admin`
3. **Password:** Get it from the installation output or run:
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

## What Gets Installed

1. **ArgoCD Server** - Web UI and API server
2. **ArgoCD Application Controller** - Monitors applications and syncs with Git
3. **ArgoCD Repo Server** - Clones Git repositories and renders manifests
4. **ArgoCD Redis** - Caching
5. **ArgoCD App-of-Apps** - Root application that manages child applications

## App-of-Apps Pattern

The installation creates:

- **AppProject:** `sha-blog-platform` - Defines permissions and allowed resources
- **Root Application:** `sha-blog-root-apps` - Syncs from `argocd/applications/` directory
  - Automatically creates child applications for dev, staging, and prod environments
  - Auto-sync and self-heal enabled

## Customization

### Before Installation

Edit `01-values-argocd.yaml` to customize:

1. **Domain name:**
   ```yaml
   server:
     ingress:
       hosts:
         - argocd.YOUR_DOMAIN  # Change this
   ```

2. **GitHub credentials:**
   ```yaml
   credentialTemplates:
     gh-org-template:
       url: https://github.com/YOUR_ORG
       username: YOUR_USERNAME
       password: YOUR_GITHUB_PAT  # Personal Access Token
   ```

3. **OIDC (optional):**
   Uncomment and configure the `oidc.config` section for SSO

### After Installation

You can update configuration:

```bash
# Edit values
vim 01-values-argocd.yaml

# Upgrade
helm upgrade argocd argo/argo-cd \
  --namespace argocd \
  -f 01-values-argocd.yaml
```

## Verification

Check ArgoCD status:

```bash
# Check pods
kubectl -n argocd get pods

# Check applications
kubectl -n argocd get applications

# Check AppProjects
kubectl -n argocd get appprojects
```

## Troubleshooting

### Pods not starting

```bash
kubectl -n argocd describe pod <pod-name>
kubectl -n argocd logs <pod-name>
```

### Can't access UI

1. Check ingress:
   ```bash
   kubectl -n argocd get ingress
   ```

2. Verify hosts file entry:
   ```
   127.0.0.1 sha-argocd.blog.local
   ```

3. Port-forward as fallback:
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```
   Access at: https://localhost:8080

### Applications not syncing

1. Check repository credentials:
   ```bash
   kubectl -n argocd get secret -l argocd.argoproj.io/secret-type=repository
   ```

2. Check application status:
   ```bash
   kubectl -n argocd get app sha-blog-root-apps -o yaml
   ```

## Uninstallation

```bash
# Remove applications
helm uninstall argocd-apps -n argocd

# Remove ArgoCD
helm uninstall argocd -n argocd

# Delete namespace
kubectl delete namespace argocd
```

## Next Steps

After ArgoCD is installed:

1. Access the UI at http://sha-argocd.blog.local
2. Login with admin credentials
3. The root app will automatically sync and create child applications for:
   - `sha-blog-dev` - Development environment
   - `sha-blog-staging` - Staging environment
   - `sha-blog-prod` - Production environment
4. Monitor sync status in the UI
5. Push changes to Git and watch ArgoCD auto-sync

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD Helm Chart](https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd)
- [App-of-Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)

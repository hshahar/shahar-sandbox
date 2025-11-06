# ArgoCD Configuration for SHA K8s Blog Platform

## Overview

ArgoCD provides GitOps continuous delivery for your Kubernetes applications. Currently, ArgoCD is installed but not configured with any applications.

## Current State

✅ **Installed**: ArgoCD is running in the `argocd` namespace
❌ **Not Configured**: No applications are being managed by ArgoCD yet

**Why?** ArgoCD works best with Git repositories. Your application is currently deployed directly via Terraform/Helm, which is fine for development.

## Access ArgoCD

### Login Credentials

- **URL**: http://sha-argocd-dev.local
- **Username**: `admin`
- **Password**: Get it with:
  ```powershell
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
  ```

### Default Password

The initial admin password is automatically generated during ArgoCD installation and stored in a Kubernetes secret. For the SHA K8s Blog Platform deployment, retrieve it using the command above.

**Example:**
```powershell
PS> kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
BYp4qek7BGmNidv6
```

Then login at http://sha-argocd-dev.local with:
- Username: `admin`
- Password: `BYp4qek7BGmNidv6` (or your generated password)

### Change Password (Recommended)

After first login, change the password:

**Via UI:**
1. Login to ArgoCD
2. Click on "User Info" (top right)
3. Click "Update Password"
4. Enter current password and new password

**Via CLI:**
```powershell
# Login first
argocd login sha-argocd-dev.local --username admin --password <current-password>

# Change password
argocd account update-password
```

### Password Reset

If you forget the password, reset it:

```powershell
# Delete the secret to regenerate it
kubectl delete secret argocd-initial-admin-secret -n argocd

# Restart ArgoCD server to regenerate
kubectl rollout restart deployment argocd-server -n argocd

# Wait for restart
kubectl rollout status deployment argocd-server -n argocd

# Get new password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

## Setup Options

### Option 1: Deploy via ArgoCD (GitOps - Recommended for Production)

#### Step 1: Push Code to Git Repository

```powershell
# Initialize Git if not already done
git init
git add .
git commit -m "Initial commit"

# Add your remote repository
git remote add origin https://github.com/yourusername/sha-k8s-blog.git
git push -u origin main
```

#### Step 2: Update ArgoCD Application Manifest

Edit `argocd/applications/sha-blog-dev.yaml` and update the `repoURL`:

```yaml
source:
  repoURL: https://github.com/yourusername/sha-k8s-blog.git  # Your actual repo!
  targetRevision: HEAD
  path: helm/microservices-app
```

#### Step 3: Apply ArgoCD Application

```powershell
kubectl apply -f argocd/applications/sha-blog-dev.yaml
```

#### Step 4: Sync in ArgoCD UI

1. Go to http://sha-argocd-dev.local
2. Login with admin credentials
3. Click on the `sha-blog-dev` application
4. Click "SYNC" button
5. Click "SYNCHRONIZE"

Your application will now be managed by ArgoCD! Any changes pushed to Git will automatically deploy.

### Option 2: Continue with Terraform/Helm (Current Approach)

This is what we're doing now - deploying directly with Terraform. It's simpler for local development but doesn't provide GitOps benefits.

```powershell
# Deploy/Update
cd terraform
terraform apply -var-file="environments/dev.tfvars" -auto-approve
```

**Pros:**
- ✅ Faster local development
- ✅ No Git repository required
- ✅ Direct control

**Cons:**
- ❌ No Git history of deployments
- ❌ No automatic sync
- ❌ Manual rollbacks

## GitOps Benefits

When using ArgoCD:

1. **Declarative**: Git is the single source of truth
2. **Automated**: Changes in Git automatically deploy
3. **Auditable**: Full history of who deployed what and when
4. **Rollback**: Easy rollback to any previous Git commit
5. **Multi-cluster**: Deploy to dev/staging/prod from one place

## Hybrid Approach (Recommended for Development)

You can use both:

1. **Infrastructure**: Deploy with Terraform (ArgoCD, Prometheus, etc.)
2. **Applications**: Deploy with ArgoCD (your blog app)

This gives you the best of both worlds!

## ArgoCD CLI (Optional)

Install ArgoCD CLI for command-line management:

```powershell
# Windows
winget install Argo.ArgoCD

# Or download from https://github.com/argoproj/argo-cd/releases
```

### CLI Commands

```powershell
# Login
argocd login sha-argocd-dev.local --username admin --password <password>

# List applications
argocd app list

# Get application status
argocd app get sha-blog-dev

# Sync application
argocd app sync sha-blog-dev

# View application logs
argocd app logs sha-blog-dev

# Rollback to previous version
argocd app rollback sha-blog-dev
```

## Creating Additional Applications

Create more applications for staging and production:

```powershell
# Copy and modify for staging
cp argocd/applications/sha-blog-dev.yaml argocd/applications/sha-blog-staging.yaml

# Edit staging application to use values-staging.yaml
# Then apply
kubectl apply -f argocd/applications/sha-blog-staging.yaml
```

## Monitoring ArgoCD

### Health Status

Check if ArgoCD components are healthy:

```powershell
kubectl get pods -n argocd
kubectl get applications -n argocd
```

### Application Status

```powershell
# Get application status
kubectl get application sha-blog-dev -n argocd -o yaml

# Watch application sync status
kubectl get application sha-blog-dev -n argocd -w
```

## Troubleshooting

### Application Not Syncing

```powershell
# Check application status
kubectl describe application sha-blog-dev -n argocd

# Check ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller -f
```

### Repository Connection Issues

```powershell
# Check repository credentials
kubectl get secret -n argocd | grep repo

# Test repository connection
argocd repo list
```

### Sync Errors

1. Check the application in the UI for error details
2. Verify Helm chart syntax: `helm template helm/microservices-app`
3. Check resource quotas: `kubectl describe namespace sha-dev`

## Next Steps

To fully enable GitOps:

1. **Push to Git**: Commit all your code to a Git repository
2. **Update Manifest**: Modify `argocd/applications/sha-blog-dev.yaml` with your repo URL
3. **Apply**: `kubectl apply -f argocd/applications/sha-blog-dev.yaml`
4. **Verify**: Check ArgoCD UI to see your application syncing

## Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [GitOps Principles](https://opengitops.dev/)


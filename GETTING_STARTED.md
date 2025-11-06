# 🚀 Getting Started - SHA K8s Blog Platform

Welcome to the SHA Kubernetes Blog Platform! This guide will help you get the infrastructure up and running in minutes.

## ✅ What's Included?

A complete, production-ready Kubernetes infrastructure with:

### 📁 Project Components:
- ✅ **50+ Kubernetes manifests** (Helm templates)
- ✅ **Terraform IaC** (Infrastructure as Code)
- ✅ **PowerShell automation scripts**
- ✅ **Comprehensive documentation**
- ✅ **Multi-environment configuration** (Dev/Staging/Production)
- ✅ **CI/CD pipeline templates**
- ✅ **Monitoring and observability stack**
- ✅ **Security implementations**

### 🎯 Key Features:
- ✅ **GitOps with ArgoCD** - Automated deployment from Git
- ✅ **Progressive Delivery** - Argo Rollouts with Canary deployments
- ✅ **Event-Driven Autoscaling** - KEDA with 80+ scalers
- ✅ **Monitoring Stack** - Prometheus + Grafana with custom dashboards
- ✅ **Secrets Management** - HashiCorp Vault + External Secrets
- ✅ **Network Security** - Calico CNI with NetworkPolicies
- ✅ **Ingress Controller** - NGINX with TLS support
- ✅ **Infrastructure as Code** - Terraform with remote state support
- ✅ **Application Stack** - React frontend + FastAPI backend + PostgreSQL

## 📋 Prerequisites

Before you begin, ensure you have:

### Required:
- ✅ **Kubernetes Cluster** - Docker Desktop (recommended) or Rancher Desktop
- ✅ **kubectl** - Kubernetes command-line tool
- ✅ **Terraform** - v1.0 or later
- ✅ **PowerShell** - Version 5.1 or PowerShell Core 7+
- ✅ **Administrator Access** - For hosts file modification

### Recommended:
- ✅ **Helm** - v3.0 or later (for manual chart operations)
- ✅ **Docker** - For building application images
- ✅ **Git** - For version control
- ✅ **AWS CLI** - If using S3 backend for Terraform state

### System Requirements:
- **OS**: Windows 10/11, macOS, or Linux
- **RAM**: Minimum 8GB (16GB recommended)
- **CPU**: 4+ cores recommended
- **Disk**: 20GB free space

## 🚀 Quick Start (10 Minutes)

### Step 1: Start Kubernetes

**Docker Desktop:**
```powershell
# Verify Docker Desktop is running
docker info

# Check Kubernetes context
kubectl config current-context
# Expected: docker-desktop

# Verify cluster
kubectl cluster-info
```

**If using Rancher Desktop:**
```powershell
kubectl config use-context rancher-desktop
```

### Step 2: Install Terraform

```powershell
# Install via winget
winget install Hashicorp.Terraform

# Verify installation
terraform --version
```

### Step 3: Deploy Infrastructure

```powershell
# Navigate to terraform directory
cd C:\Users\ILPETSHHA.old\dev\testshahar\terraform

# Initialize Terraform
terraform init

# Deploy to development environment
terraform apply -var-file="environments/dev.tfvars" -auto-approve
```

**Expected deployment time:** 5-10 minutes

**What gets deployed:**
- ArgoCD (GitOps)
- Grafana (Monitoring dashboards)
- Prometheus (Metrics collection)
- Vault (Secrets management)
- Argo Rollouts (Progressive delivery)
- KEDA (Event-driven autoscaling)
- NGINX Ingress (Traffic routing)
- Calico (Network policies)
- Blog application (Frontend + Backend + Database)

### Step 4: Configure DNS

**Run as Administrator:**
```powershell
# Add hostnames to Windows hosts file
cd C:\Users\ILPETSHHA.old\dev\testshahar\scripts
.\add-hosts-sha.ps1
```

**Hostnames added:**
- `sha-dev.blog.local` - Blog application
- `sha-argocd-dev.local` - ArgoCD UI
- `sha-grafana-dev.local` - Grafana dashboard
- `sha-vault-dev.local` - Vault UI

### Step 5: Access Services

**ArgoCD:**
```powershell
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

# Open in browser
Start-Process "http://sha-argocd-dev.local"
```
- Username: `admin`
- Password: (from command above)

**Grafana:**
```powershell
# Open in browser
Start-Process "http://sha-grafana-dev.local"
```
- Username: `admin`
- Password: `admin` (change on first login)

**Blog Application:**
```powershell
# Open in browser
Start-Process "http://sha-dev.blog.local"
```

### Step 6: Verify Deployment

```powershell
# Check all pods are running
kubectl get pods -n sha-dev
kubectl get pods -n argocd
kubectl get pods -n monitoring

# Check ingresses
kubectl get ingress -n sha-dev
kubectl get ingress -n argocd
kubectl get ingress -n monitoring

# Check services
kubectl get svc -n sha-dev
```

## 📖 Next Steps

### 1. Build Application Images

The backend is already built, but you can rebuild:

```powershell
# Build backend
cd C:\Users\ILPETSHHA.old\dev\testshahar\app\backend
docker build -t sha-blog-backend:dev .

# Build frontend (optional - npm install may be slow)
cd C:\Users\ILPETSHHA.old\dev\testshahar\app\frontend
docker build -t sha-blog-frontend:dev .
```

### 2. Explore Monitoring

**Grafana Dashboards:**
1. Login to http://sha-grafana-dev.local
2. Import dashboard from ConfigMap (see [MONITORING_ACCESS.md](docs/MONITORING_ACCESS.md))
3. View metrics: CPU, Memory, HTTP requests, latency

**Prometheus:**
```powershell
# Port-forward to access Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Open http://localhost:9090
```

### 3. Configure ArgoCD (Optional)

Enable GitOps deployment:

1. Push code to Git repository
2. Update `argocd/applications/sha-blog-dev.yaml` with your repo URL
3. Apply ArgoCD application:
   ```powershell
   kubectl apply -f argocd/applications/sha-blog-dev.yaml
   ```

See [argocd/README.md](argocd/README.md) for details.

### 4. Enable Autoscaling

**Configure KEDA:**
```yaml
# helm/microservices-app/values-dev.yaml
autoscaling:
  enabled: true
  type: keda

backend:
  autoscaling:
    minReplicas: 2
    maxReplicas: 10
    cpu:
      enabled: true
      targetUtilization: "70"
```

**Redeploy:**
```powershell
terraform apply -var-file="environments/dev.tfvars" -auto-approve
```

See [KEDA_AUTOSCALING.md](docs/KEDA_AUTOSCALING.md) for advanced configuration.

## 📚 Documentation Guide

### Essential Reading:
1. **[README.md](README.md)** - Project overview and architecture
2. **[MONITORING_ACCESS.md](docs/MONITORING_ACCESS.md)** - Service credentials and access
3. **[APPLICATION_DEPLOYMENT.md](docs/APPLICATION_DEPLOYMENT.md)** - Build and deploy applications

### Infrastructure:
4. **[terraform/README.md](terraform/README.md)** - Terraform usage guide
5. **[TERRAFORM_S3_BACKEND.md](docs/TERRAFORM_S3_BACKEND.md)** - Remote state management
6. **[KEDA_AUTOSCALING.md](docs/KEDA_AUTOSCALING.md)** - Event-driven autoscaling

### GitOps & Deployment:
7. **[argocd/README.md](argocd/README.md)** - ArgoCD setup and GitOps workflow
8. **[PROGRESSIVE_DELIVERY.md](docs/PROGRESSIVE_DELIVERY.md)** - Canary deployments
9. **[CI_CD_PIPELINE.md](docs/CI_CD_PIPELINE.md)** - GitHub Actions pipeline

### Security:
10. **[SECURITY.md](docs/SECURITY.md)** - Network policies and security
11. **[VAULT_GUIDE.md](docs/VAULT_GUIDE.md)** - Secrets management

## 🔧 Development Workflow

### Deploy to Development

```powershell
# Make changes to Helm charts or Terraform
cd C:\Users\ILPETSHHA.old\dev\testshahar\terraform

# Plan changes
terraform plan -var-file="environments/dev.tfvars"

# Apply changes
terraform apply -var-file="environments/dev.tfvars" -auto-approve

# Check status
kubectl get pods -n sha-dev -w
```

### View Logs

```powershell
# Backend logs
kubectl logs -n sha-dev deployment/sha-k8s-blog-dev-sha-microservices-app-backend -f

# Frontend logs
kubectl logs -n sha-dev deployment/sha-k8s-blog-dev-sha-microservices-app-frontend -f

# PostgreSQL logs
kubectl logs -n sha-dev statefulset/sha-k8s-blog-dev-sha-microservices-app-postgresql -f
```

### Debug Issues

```powershell
# Describe pod
kubectl describe pod <pod-name> -n sha-dev

# Get events
kubectl get events -n sha-dev --sort-by='.lastTimestamp'

# Check ingress
kubectl describe ingress -n sha-dev

# Test service connectivity
kubectl run test-pod --rm -it --image=busybox --restart=Never -n sha-dev -- /bin/sh
# Inside pod: wget -O- http://backend:8000/health
```

## 🌍 Deploy to Other Environments

### Staging Deployment

```powershell
cd C:\Users\ILPETSHHA.old\dev\testshahar\terraform

# Deploy to staging
terraform apply -var-file="environments/staging.tfvars" -auto-approve

# Add staging hosts
# Edit scripts/add-hosts-sha.ps1 to include staging URLs
```

### Production Deployment

**⚠️ Important:** Production requires additional considerations:

1. **Backup Terraform State:**
   ```powershell
   Copy-Item terraform.tfstate terraform.tfstate.prod.backup
   ```

2. **Enable S3 Backend** (recommended):
   ```powershell
   # Run setup script
   .\terraform\scripts\setup-s3-backend.ps1 -BucketName "sha-k8s-terraform-state" -Region "us-east-1"
   
   # Copy backend config
   Copy-Item terraform\backend-s3.tf.example terraform\backend-s3.tf
   
   # Migrate state
   terraform init -migrate-state
   ```

3. **Review Production Values:**
   - Check `terraform/environments/prod.tfvars`
   - Verify replica counts
   - Review resource limits
   - Confirm monitoring and alerting

4. **Deploy:**
   ```powershell
   terraform apply -var-file="environments/prod.tfvars"
   ```

## 🎓 Learning Resources

### Key Concepts Demonstrated:

**Infrastructure as Code:**
- Terraform for infrastructure provisioning
- Helm for application packaging
- GitOps with ArgoCD

**Kubernetes:**
- Deployments, Services, StatefulSets
- ConfigMaps and Secrets
- Ingress and NetworkPolicies
- Horizontal Pod Autoscaling (HPA)
- KEDA ScaledObjects

**CI/CD:**
- GitHub Actions workflows
- Automated testing and deployment
- Progressive delivery with Argo Rollouts

**Observability:**
- Prometheus metrics collection
- Grafana visualization
- ServiceMonitors and alerts

**Security:**
- Vault secrets management
- Network policies
- Pod security standards

### Recommended Skills:
- ✅ Kubernetes administration
- ✅ Terraform (IaC)
- ✅ Helm chart development
- ✅ Container orchestration
- ✅ GitOps methodology
- ✅ Monitoring and observability
- ✅ Security best practices

## 🔍 Troubleshooting

### Common Issues

**Pods not starting:**
```powershell
# Check pod status
kubectl get pods -n sha-dev

# Describe failing pod
kubectl describe pod <pod-name> -n sha-dev

# Check logs
kubectl logs <pod-name> -n sha-dev
```

**Can't access services:**
```powershell
# Verify hosts file
Get-Content C:\Windows\System32\drivers\etc\hosts | Select-String "sha-"

# Check ingress
kubectl get ingress -n sha-dev
kubectl describe ingress -n sha-dev

# Check NGINX Ingress Controller
kubectl get pods -n ingress-nginx
```

**Terraform state locked:**
```powershell
# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

**Database connection issues:**
```powershell
# Check PostgreSQL pod
kubectl get pods -n sha-dev | Select-String "postgresql"

# Check logs
kubectl logs -n sha-dev statefulset/sha-k8s-blog-dev-sha-microservices-app-postgresql

# Verify DATABASE_URL environment variable
kubectl get deployment -n sha-dev sha-k8s-blog-dev-sha-microservices-app-backend -o yaml | Select-String "DATABASE"
```

See [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for more solutions.

## 📞 Getting Help

1. **Check Documentation:**
   - Review relevant docs in [docs/](docs/) directory
   - Check [README.md](README.md) for architecture overview

2. **Review Logs:**
   ```powershell
   kubectl logs -n sha-dev <pod-name>
   kubectl get events -n sha-dev
   ```

3. **Verify Configuration:**
   ```powershell
   # Check Helm values
   helm get values sha-k8s-blog-dev -n sha-dev
   
   # Check Terraform state
   terraform show
   ```

4. **Community Resources:**
   - Kubernetes Documentation: https://kubernetes.io/docs/
   - Terraform Documentation: https://www.terraform.io/docs/
   - KEDA Documentation: https://keda.sh/docs/
   - ArgoCD Documentation: https://argo-cd.readthedocs.io/

## 🎯 What's Next?

### Short Term:
- [ ] Explore Grafana dashboards
- [ ] Test autoscaling with load
- [ ] Configure ArgoCD for GitOps
- [ ] Build custom application images
- [ ] Set up alerts in Prometheus

### Medium Term:
- [ ] Enable remote Terraform state (S3)
- [ ] Implement CI/CD pipeline
- [ ] Deploy to staging environment
- [ ] Configure custom domains
- [ ] Set up SSL certificates

### Long Term:
- [ ] Deploy to production
- [ ] Implement backup strategy
- [ ] Add more applications
- [ ] Integrate additional monitoring tools
- [ ] Implement disaster recovery

## 🌟 Project Highlights

This platform includes:
- ✅ **50+ configuration files** professionally structured
- ✅ **10+ documentation files** covering all aspects
- ✅ **3 environments** (Dev/Staging/Production)
- ✅ **8+ infrastructure components** (ArgoCD, Grafana, Prometheus, Vault, etc.)
- ✅ **Production-ready** architecture
- ✅ **GitOps-enabled** with ArgoCD
- ✅ **Event-driven autoscaling** with KEDA
- ✅ **Comprehensive monitoring** with Prometheus + Grafana
- ✅ **Security hardened** with Vault and NetworkPolicies

## 🎊 You're Ready!

The infrastructure is now deployed and ready for use. Explore the services, review the documentation, and start building amazing applications!

**Happy Deploying! 🚀**

---

*Created by SHA - Kubernetes Blog Platform*

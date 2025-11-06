# Quick Start Guide – Deploy in 5 Minutes! 🚀

## Prerequisites

1. **Docker Desktop or Rancher Desktop** with Kubernetes enabled
2. **kubectl, helm, terraform** installed

### Quick install (Windows):

```powershell
winget install suse.RancherDesktop
winget install Kubernetes.kubectl
winget install Helm.Helm
winget install Hashicorp.Terraform
```

## Deployment in 3 Steps

### Step 1: Check the cluster

```powershell
kubectl cluster-info
kubectl get nodes
```

You should see that the cluster is running ✅

### Step 2: Run the setup script

```powershell
cd scripts
.\setup.ps1
```

Choose option 1 (Development)

### Step 3: Add hosts (as Administrator)

```powershell
# Run PowerShell as Administrator
.\scripts\add-hosts.ps1
```

## Verification

### Access via browser:

```
http://dev.myapp.local
```

### Check status:

```powershell
.\run.ps1 status dev
```

### View logs:

```powershell
.\run.ps1 logs dev
```

## Useful commands

```powershell
# Deploy
.\run.ps1 deploy dev

# Status
.\run.ps1 status dev

# Logs
.\run.ps1 logs dev

# Cleanup
.\run.ps1 cleanup dev

# Help
.\run.ps1 help
```

## Quick Troubleshooting

### Pods not starting?

```powershell
kubectl describe pods -n dev
kubectl get events -n dev --sort-by='.lastTimestamp'
```

### Ingress not working?

```powershell
# Check that the Ingress Controller is running
kubectl get pods -n ingress-nginx

# Use port-forward instead
kubectl port-forward -n dev service/myapp-dev-frontend 8080:80
# Go to: http://localhost:8080
```

### Database not starting?

```powershell
# Check PVC
kubectl get pvc -n dev

# Check logs
kubectl logs -n dev -l app=postgresql
```

## Deploying to other environments

### Staging:

```powershell
.\run.ps1 deploy staging
# Add hosts: 127.0.0.1 staging.myapp.local
# Go to: http://staging.myapp.local
```

### Production:

```powershell
.\run.ps1 deploy prod
# Add hosts: 127.0.0.1 prod.myapp.local
# Go to: http://prod.myapp.local
```

## Additional documentation

* [README.md](README.md) – Full guide
* [USAGE.md](USAGE.md) – Detailed explanations
* [ENVIRONMENTS.md](ENVIRONMENTS.md) – Environment differences

## Support

Stuck? Check:

1. That Kubernetes is running: `kubectl get nodes`
2. That your machine has enough resources (at least 4GB RAM)
3. That nothing is blocked by the firewall
4. The logs: `.\run.ps1 logs dev`

That’s it! You’re ready to go! 🎉

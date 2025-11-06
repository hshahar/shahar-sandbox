# ⚡ Cheat Sheet - פקודות מהירות

## 🚀 התקנה ראשונית

```powershell
# התקן כלים
winget install suse.RancherDesktop
winget install Kubernetes.kubectl
winget install Helm.Helm
winget install Hashicorp.Terraform

# הרץ setup
.\scripts\setup.ps1

# הוסף hosts (כמנהל)
.\scripts\add-hosts.ps1
```

## 📦 Wrapper Commands (מומלץ!)

```powershell
.\run.ps1 setup              # התקנה מלאה
.\run.ps1 deploy dev         # פריסה ל-dev
.\run.ps1 status dev         # סטטוס
.\run.ps1 logs dev           # לוגים (עם follow)
.\run.ps1 cleanup dev        # ניקוי
.\run.ps1 help               # עזרה
```

## 🎯 Helm Commands

```powershell
# Install
helm install myapp-dev .\helm\microservices-app -f values-dev.yaml -n dev --create-namespace

# Upgrade
helm upgrade myapp-dev .\helm\microservices-app -f values-dev.yaml -n dev

# Uninstall
helm uninstall myapp-dev -n dev

# Status
helm status myapp-dev -n dev
helm list -n dev
helm history myapp-dev -n dev

# Rollback
helm rollback myapp-dev -n dev

# Dry-run
helm install myapp-dev . -f values-dev.yaml -n dev --dry-run --debug

# Lint
helm lint .\helm\microservices-app -f values-dev.yaml
```

## 🏗️ Terraform Commands

```powershell
cd terraform

# Init
terraform init

# Plan
terraform plan -var-file="environments\dev.tfvars"

# Apply
terraform apply -var-file="environments\dev.tfvars"
terraform apply -var-file="environments\dev.tfvars" -auto-approve

# Destroy
terraform destroy -var-file="environments\dev.tfvars"

# Validate
terraform validate
terraform fmt -recursive
```

## ☸️ Kubectl Commands

### בסיס
```powershell
kubectl cluster-info
kubectl get nodes
kubectl config get-contexts
kubectl config use-context rancher-desktop
```

### Pods
```powershell
kubectl get pods -n dev
kubectl get pods -n dev -o wide
kubectl describe pod <pod-name> -n dev
kubectl logs <pod-name> -n dev
kubectl logs <pod-name> -n dev -f
kubectl logs <pod-name> -n dev --previous
kubectl logs -n dev -l app=backend -f
kubectl exec -it <pod-name> -n dev -- /bin/sh
kubectl delete pod <pod-name> -n dev
```

### Deployments
```powershell
kubectl get deployments -n dev
kubectl describe deployment <deployment-name> -n dev
kubectl scale deployment <deployment-name> -n dev --replicas=3
kubectl rollout status deployment/<deployment-name> -n dev
kubectl rollout history deployment/<deployment-name> -n dev
kubectl rollout undo deployment/<deployment-name> -n dev
```

### Services
```powershell
kubectl get svc -n dev
kubectl describe svc <service-name> -n dev
kubectl port-forward -n dev service/<service-name> 8080:80
```

### Ingress
```powershell
kubectl get ingress -n dev
kubectl describe ingress -n dev
```

### ConfigMaps & Secrets
```powershell
kubectl get configmap -n dev
kubectl get secrets -n dev
kubectl describe secret <secret-name> -n dev
kubectl get secret <secret-name> -n dev -o yaml
```

### Storage
```powershell
kubectl get pvc -n dev
kubectl get pv
kubectl describe pvc <pvc-name> -n dev
```

### HPA
```powershell
kubectl get hpa -n dev
kubectl describe hpa <hpa-name> -n dev
kubectl top pods -n dev
kubectl top nodes
```

### Events & Logs
```powershell
kubectl get events -n dev --sort-by='.lastTimestamp'
kubectl get events -n dev --field-selector type=Warning
```

### All Resources
```powershell
kubectl get all -n dev
kubectl delete all --all -n dev
```

### Namespaces
```powershell
kubectl get namespaces
kubectl create namespace dev
kubectl delete namespace dev
```

## 🔍 Debugging

```powershell
# Pod לא עולה
kubectl describe pod <pod-name> -n dev
kubectl logs <pod-name> -n dev
kubectl get events -n dev --sort-by='.lastTimestamp'

# בדיקת resources
kubectl top pods -n dev
kubectl top nodes

# Exec לתוך pod
kubectl exec -it <pod-name> -n dev -- sh

# Port forward
kubectl port-forward -n dev <pod-name> 8080:80

# Temporary debug pod
kubectl run debug --image=curlimages/curl -it --rm --restart=Never -n dev -- sh
```

## 🌐 Access URLs

```powershell
# לאחר הוספת hosts:
http://dev.myapp.local
http://staging.myapp.local
http://prod.myapp.local

# Port forward:
kubectl port-forward -n dev service/myapp-dev-frontend 8080:80
# http://localhost:8080

kubectl port-forward -n dev service/myapp-dev-backend 8000:8080
# http://localhost:8000

kubectl port-forward -n dev service/myapp-dev-postgresql 5432:5432
# localhost:5432
```

## 🔐 Secrets

```powershell
# הצג secret (base64 decoded)
kubectl get secret myapp-dev-secrets -n dev -o jsonpath='{.data.database-password}' | base64 -d

# יצירת secret ידנית
kubectl create secret generic my-secret `
  --from-literal=username=admin `
  --from-literal=password=secret123 `
  -n dev
```

## 📊 Monitoring

```powershell
# Watch pods
kubectl get pods -n dev -w

# Watch all
kubectl get all -n dev -w

# Continuous logs
kubectl logs -n dev -l app=backend -f --tail=100

# Resource usage
kubectl top pods -n dev
kubectl top nodes

# Events stream
kubectl get events -n dev -w
```

## 🔄 CI/CD

```powershell
# Push to deploy
git push origin develop      # → Deploy to dev
git push origin staging      # → Deploy to staging
git push origin main         # → Deploy to production

# Tag for production
git tag v1.0.0
git push origin v1.0.0       # → Deploy to production
```

## 🧹 Cleanup

```powershell
# סקריפט
.\scripts\cleanup.ps1 -Environment dev

# ידני
helm uninstall myapp-dev -n dev
kubectl delete namespace dev

# כל הסביבות
kubectl delete namespace dev staging production
kubectl delete namespace ingress-nginx
```

## 💡 טיפים מהירים

```powershell
# Alias מומלצים (הוסף ל-PowerShell profile)
Set-Alias -Name k -Value kubectl
function kgp { kubectl get pods -n $args }
function kgs { kubectl get svc -n $args }
function kl { kubectl logs -n $args[0] -l app=$args[1] -f }

# שימוש:
k get pods -n dev
kgp dev
kgs dev
kl dev backend
```

## 📝 Hosts File

```powershell
# Windows: C:\Windows\System32\drivers\etc\hosts
# הוסף (כמנהל):
127.0.0.1 dev.myapp.local
127.0.0.1 staging.myapp.local
127.0.0.1 prod.myapp.local

# פתח כמנהל:
Start-Process notepad "C:\Windows\System32\drivers\etc\hosts" -Verb RunAs
```

## 🎯 Common Workflows

### פריסה חדשה
```powershell
cd helm\microservices-app
helm install myapp-dev . -f values-dev.yaml -n dev --create-namespace
kubectl get all -n dev
```

### עדכון אפליקציה
```powershell
helm upgrade myapp-dev . -f values-dev.yaml -n dev
kubectl rollout status deployment/myapp-dev-backend -n dev
```

### בדיקת בעיות
```powershell
kubectl get pods -n dev
kubectl describe pod <failing-pod> -n dev
kubectl logs <failing-pod> -n dev
kubectl get events -n dev --sort-by='.lastTimestamp'
```

### חזרה לגרסה קודמת
```powershell
helm history myapp-dev -n dev
helm rollback myapp-dev 1 -n dev
```

## 📚 מסמכים

- [README.md](README.md) - התחלה
- [QUICKSTART.md](QUICKSTART.md) - 5 דקות
- [USAGE.md](USAGE.md) - שימוש מפורט
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - פתרון בעיות
- [ENVIRONMENTS.md](ENVIRONMENTS.md) - השוואת סביבות
- [ARCHITECTURE.md](ARCHITECTURE.md) - ארכיטקטורה

## 🆘 עזרה מהירה

```powershell
.\run.ps1 help
helm --help
kubectl --help
terraform --help
```

---

**טיפ**: שמור דף זה פתוח בזמן העבודה! 📌

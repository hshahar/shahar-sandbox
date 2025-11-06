# Detailed Usage Guide

## Initial Setup

### 1. Installing Prerequisites

#### Install Docker Desktop or Rancher Desktop:
```powershell
# Docker Desktop
winget install Docker.DockerDesktop

# or Rancher Desktop (recommended)
winget install suse.RancherDesktop
```

**Important**: After installation:
1. Open Docker Desktop / Rancher Desktop
2. Go to Settings
3. Enable Kubernetes
4. Wait until status shows "Running"

#### Install CLI Tools:
```powershell
# kubectl - Kubernetes CLI
winget install Kubernetes.kubectl

# Helm - Package Manager
winget install Helm.Helm

# Terraform - Infrastructure as Code
winget install Hashicorp.Terraform
```

### 2. Verify Installation

Check that all tools are installed correctly:
```powershell
kubectl version --client
helm version
terraform version
kubectl cluster-info
```

## Deployment with Automated Script

### Quick deployment for development environment:
```powershell
cd scripts
.\setup.ps1
# Choose option 1 (Development)
```

הסקריפט יבצע:
1. בדיקת דרישות מוקדמות
2. התקנת Ingress Controller
3. פריסת האפליקציה לסביבה הנבחרת
4. הצגת הוראות גישה

## פריסה ידנית עם Helm

### סביבת פיתוח (Development):
```powershell
# התקנה
cd helm\microservices-app
helm install myapp-dev . -f values-dev.yaml --namespace dev --create-namespace

# עדכון
helm upgrade myapp-dev . -f values-dev.yaml --namespace dev

# הסרה
helm uninstall myapp-dev --namespace dev
```

### סביבת בדיקות (Staging):
```powershell
helm install myapp-staging . -f values-staging.yaml --namespace staging --create-namespace
```

### סביבת ייצור (Production):
```powershell
helm install myapp-prod . -f values-prod.yaml --namespace production --create-namespace
```

## פריסה עם Terraform

### אתחול Terraform:
```powershell
cd terraform
terraform init
```

### תכנון השינויים:
```powershell
# Development
terraform plan -var-file="environments\dev.tfvars"

# Staging
terraform plan -var-file="environments\staging.tfvars"

# Production
terraform plan -var-file="environments\prod.tfvars"
```

### ביצוע הפריסה:
```powershell
# Development
terraform apply -var-file="environments\dev.tfvars"

# עם אישור אוטומטי
terraform apply -var-file="environments\dev.tfvars" -auto-approve
```

### הסרת התשתית:
```powershell
terraform destroy -var-file="environments\dev.tfvars"
```

## גישה לאפליקציה

### הוספת Hosts:
ערוך את הקובץ `C:\Windows\System32\drivers\etc\hosts` (נדרש הרשאות מנהל):
```
127.0.0.1 dev.myapp.local
127.0.0.1 staging.myapp.local
127.0.0.1 prod.myapp.local
```

#### פתיחת notepad כמנהל:
```powershell
Start-Process notepad "C:\Windows\System32\drivers\etc\hosts" -Verb RunAs
```

### גישה דרך הדפדפן:
- Development: http://dev.myapp.local
- Staging: http://staging.myapp.local
- Production: http://prod.myapp.local

### Port Forward (אלטרנטיבה):
```powershell
# Frontend
kubectl port-forward -n dev service/myapp-dev-frontend 8080:80
# גש ל: http://localhost:8080

# Backend
kubectl port-forward -n dev service/myapp-dev-backend 8000:8080
# גש ל: http://localhost:8000

# PostgreSQL
kubectl port-forward -n dev service/myapp-dev-postgresql 5432:5432
# התחבר ל: localhost:5432
```

## פקודות שימושיות

### בדיקת סטטוס:
```powershell
# סקריפט מוכן
.\scripts\status.ps1 -Environment dev

# או ידנית
kubectl get all -n dev
kubectl get pods -n dev
kubectl get svc -n dev
kubectl get ingress -n dev
kubectl get pvc -n dev
kubectl get secrets -n dev
```

### צפייה בלוגים:
```powershell
# סקריפט מוכן
.\scripts\view-logs.ps1 -Environment dev -Component backend -Follow

# או ידנית
kubectl logs -n dev -l app=frontend -f
kubectl logs -n dev -l app=backend -f
kubectl logs -n dev -l app=postgresql -f

# לוגים של פוד ספציפי
kubectl logs -n dev <pod-name> -f
```

### פקודות Debugging:
```powershell
# תיאור פוד (כולל events)
kubectl describe pod -n dev <pod-name>

# תיאור deployment
kubectl describe deployment -n dev myapp-dev-backend

# אירועים אחרונים
kubectl get events -n dev --sort-by='.lastTimestamp'

# כניסה לפוד
kubectl exec -it -n dev <pod-name> -- /bin/sh

# סטטוס rollout
kubectl rollout status deployment/myapp-dev-backend -n dev

# היסטוריית rollout
kubectl rollout history deployment/myapp-dev-backend -n dev
```

### עבודה עם Secrets:
```powershell
# צפייה בסיסמאות (base64 decoded)
kubectl get secret myapp-dev-secrets -n dev -o jsonpath='{.data.database-password}' | base64 -d

# עריכת secret
kubectl edit secret myapp-dev-secrets -n dev
```

### HPA (Auto Scaling):
```powershell
# סטטוס HPA
kubectl get hpa -n staging

# תיאור מפורט
kubectl describe hpa myapp-staging-backend-hpa -n staging

# בדיקת שימוש ב-CPU/Memory
kubectl top pods -n staging
kubectl top nodes
```

### PVC (Storage):
```powershell
# רשימת PVCs
kubectl get pvc -n dev

# רשימת PVs
kubectl get pv

# תיאור PVC
kubectl describe pvc postgresql-data-myapp-dev-postgresql-0 -n dev
```

## עדכון האפליקציה

### עם Helm:
```powershell
# עדכון ערכים
helm upgrade myapp-dev ./helm/microservices-app -f values-dev.yaml -n dev

# עדכון עם override של משתנים
helm upgrade myapp-dev ./helm/microservices-app -f values-dev.yaml `
  --set backend.replicas=3 `
  --set backend.image.tag=v2.0.0 `
  -n dev
```

### Rollback:
```powershell
# צפייה בהיסטוריה
helm history myapp-dev -n dev

# חזרה לגרסה קודמת
helm rollback myapp-dev -n dev

# חזרה לגרסה ספציפית
helm rollback myapp-dev 3 -n dev
```

## בדיקות (Testing)

### בדיקת connectivity:
```powershell
# הרצת pod זמני לבדיקות
kubectl run curl-test --image=curlimages/curl:latest --rm -it --restart=Never -n dev -- sh

# בתוך הפוד:
curl http://myapp-dev-frontend
curl http://myapp-dev-backend:8080/health
```

### בדיקת Database:
```powershell
# התחברות ל-PostgreSQL
kubectl exec -it -n dev myapp-dev-postgresql-0 -- psql -U devuser -d myapp_dev

# בתוך psql:
\l          # רשימת databases
\dt         # רשימת טבלאות
\q          # יציאה
```

### Load Testing:
```powershell
# התקנת hey (load testing tool)
go install github.com/rakyll/hey@latest

# או ע"י הורדה מ-GitHub releases

# בדיקת עומס
hey -z 30s -c 50 http://dev.myapp.local/api/health
```

## CI/CD עם GitHub Actions

### הגדרת Secrets ב-GitHub:

1. עבור ל-Repository Settings → Secrets and variables → Actions
2. צור secrets חדשים:

```powershell
# קבל את ה-kubeconfig שלך
kubectl config view --raw --minify > kubeconfig-dev.yaml

# העתק את התוכן והוסף כ-secret בשם: KUBE_CONFIG_DEV
```

חזור על התהליך עבור:
- `KUBE_CONFIG_STAGING`
- `KUBE_CONFIG_PROD`

### הרצת Pipeline:

Pipeline רץ אוטומטית על:
- Push ל-`develop` → Deploy to Development
- Push ל-`staging` → Deploy to Staging  
- Push ל-`main` או Tag `v*` → Deploy to Production

```powershell
# יצירת tag לפריסה לייצור
git tag v1.0.0
git push origin v1.0.0
```

## ניקוי (Cleanup)

### סקריפט אוטומטי:
```powershell
.\scripts\cleanup.ps1 -Environment dev
# או
.\scripts\cleanup.ps1 -Environment all
```

### ניקוי ידני:
```powershell
# מחיקת release
helm uninstall myapp-dev -n dev

# מחיקת namespace (מוחק הכל!)
kubectl delete namespace dev

# מחיקת ingress controller
kubectl delete namespace ingress-nginx
```

### ניקוי Terraform:
```powershell
cd terraform
terraform destroy -var-file="environments\dev.tfvars"
```

## טיפים ושיטות עבודה מומלצות

### 1. סביבת פיתוח מקומית:
```powershell
# שימוש ב-port-forward במקום ingress
kubectl port-forward -n dev service/myapp-dev-backend 8000:8080

# שימוש בפרופילים של kubectl
kubectl config set-context dev --namespace=dev
kubectl config use-context dev
```

### 2. עבודה עם ערכים מותאמים אישית:
```yaml
# צור קובץ values-local.yaml
environment: local
frontend:
  replicas: 1
backend:
  replicas: 1
  autoscaling:
    enabled: false
postgresql:
  enabled: false  # השתמש ב-DB חיצוני
```

```powershell
helm install myapp-local . -f values-local.yaml -n local --create-namespace
```

### 3. Dry-run לפני פריסה:
```powershell
# Helm dry-run
helm install myapp-dev . -f values-dev.yaml -n dev --dry-run --debug

# Terraform plan
terraform plan -var-file="environments\dev.tfvars"

# Kubectl dry-run
kubectl apply -f deployment.yaml --dry-run=client
```

### 4. ייצוא תצורה:
```powershell
# ייצוא helm values
helm get values myapp-dev -n dev > current-values.yaml

# ייצוא manifest
helm get manifest myapp-dev -n dev > manifest.yaml

# ייצוא משאבים
kubectl get deployment myapp-dev-backend -n dev -o yaml > backup-deployment.yaml
```

## פתרון בעיות נפוצות

### הפודים לא עולים:
```powershell
# בדוק אירועים
kubectl describe pod <pod-name> -n dev
kubectl get events -n dev --sort-by='.lastTimestamp'

# בדוק לוגים
kubectl logs <pod-name> -n dev --previous  # לוגים מריצה קודמת
```

### בעיות אחסון:
```powershell
# בדוק PVC
kubectl get pvc -n dev
kubectl describe pvc <pvc-name> -n dev

# בדוק Storage Class
kubectl get storageclass
```

### Ingress לא עובד:
```powershell
# בדוק ingress controller
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# בדוק ingress rules
kubectl describe ingress -n dev
```

## משאבים נוספים

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Terraform Kubernetes Provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)
- [Rancher Desktop](https://docs.rancherdesktop.io/)

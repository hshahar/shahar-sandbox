# Terraform Configuration for Kubernetes Microservices

Infrastructure as Code (IaC) להקמת וניהול אפליקציית microservices ב-Kubernetes.

## מבנה

```
terraform/
├── main.tf              # Main configuration
├── variables.tf         # Variable definitions
├── outputs.tf           # Output definitions
└── environments/
    ├── dev.tfvars       # Development variables
    ├── staging.tfvars   # Staging variables
    └── prod.tfvars      # Production variables
```

## תכונות

- 🎯 התחברות לקלאסטר Kubernetes מקומי
- 📦 התקנת Ingress NGINX Controller
- 🚀 פריסת אפליקציה עם Helm
- 🌍 תמיכה במספר סביבות
- 🔧 ניהול משתנים מרכזי

## אתחול

```bash
cd terraform
terraform init
```

זה יוריד את ה-providers הנדרשים:
- `hashicorp/kubernetes` - ניהול משאבי Kubernetes
- `hashicorp/helm` - פריסת Helm Charts

## שימוש

### Development

```bash
# תכנון
terraform plan -var-file="environments/dev.tfvars"

# ביצוע
terraform apply -var-file="environments/dev.tfvars"

# עם אישור אוטומטי
terraform apply -var-file="environments/dev.tfvars" -auto-approve
```

### Staging

```bash
terraform apply -var-file="environments/staging.tfvars"
```

### Production

```bash
terraform apply -var-file="environments/prod.tfvars"
```

## הסרת תשתית

```bash
terraform destroy -var-file="environments/dev.tfvars"
```

## משתנים

### משתנים חובה:

| משתנה | תיאור | דוגמה |
|-------|-------|-------|
| `namespace` | Kubernetes namespace | `dev` |
| `environment` | שם הסביבה | `dev`, `staging`, `prod` |
| `ingress_host` | Hostname עבור Ingress | `dev.myapp.local` |

### משתנים אופציונליים:

| משתנה | ברירת מחדל | תיאור |
|-------|------------|-------|
| `kubeconfig_path` | `~/.kube/config` | נתיב לקובץ kubeconfig |
| `kube_context` | `rancher-desktop` | Context של Kubernetes |
| `install_ingress` | `true` | התקנת Ingress Controller |
| `frontend_replicas` | `1` | מספר replicas של Frontend |
| `backend_replicas` | `1` | מספר replicas של Backend |
| `enable_autoscaling` | `false` | הפעלת HPA |
| `enable_database` | `true` | הפעלת PostgreSQL |
| `database_storage_size` | `1Gi` | גודל אחסון לDB |

## קבצי סביבות

### dev.tfvars

```hcl
namespace             = "dev"
environment           = "dev"
ingress_host          = "dev.myapp.local"
frontend_replicas     = 1
backend_replicas      = 1
enable_autoscaling    = false
database_storage_size = "1Gi"
```

### staging.tfvars

```hcl
namespace             = "staging"
environment           = "staging"
ingress_host          = "staging.myapp.local"
frontend_replicas     = 2
backend_replicas      = 2
enable_autoscaling    = true
database_storage_size = "5Gi"
```

### prod.tfvars

```hcl
namespace             = "production"
environment           = "prod"
ingress_host          = "prod.myapp.local"
frontend_replicas     = 3
backend_replicas      = 3
enable_autoscaling    = true
database_storage_size = "20Gi"
```

## Outputs

לאחר ה-apply, Terraform מציג:

- `namespace` - ה-namespace שנוצר
- `environment` - שם הסביבה
- `release_name` - שם ה-Helm release
- `ingress_host` - ה-hostname של האפליקציה
- `application_url` - URL מלא לאפליקציה
- `kubectl_commands` - פקודות שימושיות

### דוגמה:

```
Outputs:

application_url = "http://dev.myapp.local"
environment = "dev"
ingress_host = "dev.myapp.local"
kubectl_commands = <<EOT
  # View all resources
  kubectl get all -n dev
  
  # View pods
  kubectl get pods -n dev
  ...
EOT
namespace = "dev"
release_name = "myapp-dev"
```

## State Management

Terraform שומר את ה-state ב:
- `terraform.tfstate` - State נוכחי
- `terraform.tfstate.backup` - Backup של state קודם

**⚠️ חשוב**: 
- אל תמחק את קבצי ה-state
- ב-production, השתמש ב-remote state (S3, Azure Storage, etc.)

### Remote State with S3

לעבודת צוות ו-production, מומלץ להשתמש ב-S3 backend:

**יתרונות:**
- 🔒 State locking עם DynamoDB (מונע שינויים במקביל)
- 📦 Versioning אוטומטי (אפשרות לשחזור)
- 🔐 Encryption at rest
- 👥 שיתוף פעולה בין חברי צוות
- ☁️ Backup אוטומטי

**Setup מהיר:**
```powershell
# הרץ את סקריפט ההתקנה
.\scripts\setup-s3-backend.ps1 -BucketName "sha-k8s-terraform-state" -Region "us-east-1"

# העתק את קובץ ההגדרות
Copy-Item backend-s3.tf.example backend-s3.tf

# ערוך את backend-s3.tf עם הערכים שלך

# העבר את ה-state ל-S3
terraform init -migrate-state
```

**תיעוד מלא:** ראה [docs/TERRAFORM_S3_BACKEND.md](../docs/TERRAFORM_S3_BACKEND.md)

**קבצים רלוונטיים:**
- `backend-s3.tf.example` - תבנית הגדרות backend
- `scripts/setup-s3-backend.ps1` - סקריפט התקנה אוטומטי
- `docs/TERRAFORM_S3_BACKEND.md` - מדריך מלא

## דוגמאות מתקדמות

### פריסה עם overrides:

```bash
terraform apply \
  -var-file="environments/dev.tfvars" \
  -var="frontend_replicas=2" \
  -var="enable_autoscaling=true"
```

### פריסה לכמה סביבות:

```bash
# Dev
terraform apply -var-file="environments/dev.tfvars"

# Staging (במקביל - workspace נפרד)
terraform workspace new staging
terraform apply -var-file="environments/staging.tfvars"
```

### יצירת plan לבדיקה:

```bash
terraform plan -var-file="environments/prod.tfvars" -out=prod.tfplan
terraform show prod.tfplan
terraform apply prod.tfplan
```

## כלים שימושיים

### פורמט קוד:
```bash
terraform fmt -recursive
```

### ולידציה:
```bash
terraform validate
```

### הצגת providers:
```bash
terraform providers
```

### הצגת state:
```bash
terraform show
terraform state list
```

### Import משאבים קיימים:
```bash
terraform import kubernetes_namespace.app_namespace dev
```

## פתרון בעיות

### State Lock:
```bash
# אם ה-state נעול, כפה unlock
terraform force-unlock <lock-id>
```

### Refresh State:
```bash
terraform refresh -var-file="environments/dev.tfvars"
```

### בדיקת drift:
```bash
terraform plan -var-file="environments/dev.tfvars" -detailed-exitcode
```

## Best Practices

✅ השתמש ב-`tfvars` files לכל סביבה
✅ הגדר resource limits בצורה נכונה
✅ אל תשמור secrets בקוד (השתמש ב-Vault)
✅ השתמש ב-remote state בייצור
✅ בצע `terraform plan` לפני `apply`
✅ הוסף `.terraform` ו-`*.tfstate` ל-`.gitignore`
✅ הגדר backend configuration בייצור

## Integration עם CI/CD

```yaml
# GitHub Actions example
- name: Terraform Apply
  run: |
    cd terraform
    terraform init
    terraform apply -var-file="environments/${{ matrix.environment }}.tfvars" -auto-approve
```

## Requirements

- Terraform >= 1.0
- Kubernetes cluster (running)
- kubectl configured
- Helm 3.x

## License

MIT

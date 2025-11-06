# Microservices App Helm Chart

Helm Chart למערכת microservices עם Frontend, Backend API, ו-PostgreSQL Database.

## תכונות

- 🌐 Frontend web server (Nginx)
- 🔧 Backend API service
- 💾 PostgreSQL database עם Persistent Storage
- 📈 Horizontal Pod Autoscaling (אופציונלי)
- 🔐 Secrets management
- 🌍 Ingress configuration
- ⚙️ Configurable per environment

## מבנה

```
microservices-app/
├── Chart.yaml                 # Chart metadata
├── values.yaml                # Default values
├── values-dev.yaml            # Development values
├── values-staging.yaml        # Staging values
├── values-prod.yaml           # Production values
└── templates/
    ├── _helpers.tpl           # Template helpers
    ├── frontend-deployment.yaml
    ├── frontend-service.yaml
    ├── frontend-configmap.yaml
    ├── backend-deployment.yaml
    ├── backend-service.yaml
    ├── backend-hpa.yaml       # Auto scaling
    ├── postgresql-statefulset.yaml
    ├── postgresql-service.yaml
    ├── ingress.yaml
    ├── secrets.yaml
    └── NOTES.txt              # Post-install notes
```

## התקנה

### Development:
```bash
helm install myapp-dev . -f values-dev.yaml --namespace dev --create-namespace
```

### Staging:
```bash
helm install myapp-staging . -f values-staging.yaml --namespace staging --create-namespace
```

### Production:
```bash
helm install myapp-prod . -f values-prod.yaml --namespace production --create-namespace
```

## עדכון

```bash
helm upgrade myapp-dev . -f values-dev.yaml -n dev
```

## הסרה

```bash
helm uninstall myapp-dev -n dev
```

## תצורה

### רכיבים ראשיים:

#### Frontend
```yaml
frontend:
  enabled: true
  replicas: 1
  image:
    repository: nginx
    tag: "1.25-alpine"
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
```

#### Backend
```yaml
backend:
  enabled: true
  replicas: 1
  autoscaling:
    enabled: false
    minReplicas: 2
    maxReplicas: 10
```

#### PostgreSQL
```yaml
postgresql:
  enabled: true
  persistence:
    size: 1Gi
```

## Conditions

ניתן להפעיל/לכבות רכיבים:

```yaml
# כיבוי PostgreSQL
postgresql:
  enabled: false

# כיבוי Frontend
frontend:
  enabled: false

# הפעלת Auto Scaling
backend:
  autoscaling:
    enabled: true
```

## משתנים לכל סביבה

הקובץ `values-{env}.yaml` מכיל תצורה ספציפית לכל סביבה:

| משתנה | Dev | Staging | Production |
|-------|-----|---------|------------|
| replicas | 1 | 2 | 3 |
| autoscaling | false | true | true |
| storage | 1Gi | 5Gi | 20Gi |

## Secrets

**⚠️ חשוב**: שנה את הסיסמאות בייצור!

```yaml
secrets:
  database:
    username: "dbuser"
    password: "CHANGE-IN-PRODUCTION"
  backend:
    apiKey: "CHANGE-IN-PRODUCTION"
```

## בדיקה לפני התקנה

```bash
# Dry run
helm install myapp-dev . -f values-dev.yaml -n dev --dry-run --debug

# Lint
helm lint . -f values-dev.yaml

# Template rendering
helm template myapp-dev . -f values-dev.yaml
```

## דוגמאות שימוש

### התקנה עם override של ערכים:
```bash
helm install myapp-dev . -f values-dev.yaml \
  --set backend.replicas=3 \
  --set postgresql.persistence.size=5Gi \
  -n dev --create-namespace
```

### עדכון עם שינוי image tag:
```bash
helm upgrade myapp-dev . -f values-dev.yaml \
  --set backend.image.tag=v2.0.0 \
  -n dev
```

### Rollback לגרסה קודמת:
```bash
helm rollback myapp-dev 1 -n dev
```

## פתרון בעיות

```bash
# בדיקת סטטוס
helm status myapp-dev -n dev

# היסטוריה
helm history myapp-dev -n dev

# הצגת values נוכחיים
helm get values myapp-dev -n dev

# הצגת manifest מלא
helm get manifest myapp-dev -n dev
```

## License

MIT

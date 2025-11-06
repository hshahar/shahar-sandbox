# Contributing Guide

תודה על העניין בפרויקט! 🎉

## איך לתרום?

### 1. Fork & Clone

```bash
git clone https://github.com/yourusername/microservices-k8s.git
cd microservices-k8s
```

### 2. צור Branch חדש

```bash
git checkout -b feature/amazing-feature
```

### 3. בצע שינויים

- ודא שהקוד עובר validation
- הרץ tests מקומיים
- עדכן documentation אם צריך

### 4. Commit

```bash
git add .
git commit -m "Add amazing feature"
```

### 5. Push & Pull Request

```bash
git push origin feature/amazing-feature
```

צור Pull Request ב-GitHub.

## קווים מנחים

### קוד

- השתמש ב-YAML formatting עקבי (2 spaces)
- הוסף comments להסברים
- בצע validation לפני commit:
  ```bash
  helm lint ./helm/microservices-app
  terraform validate
  ```

### Commits

השתמש ב-conventional commits:
- `feat:` - תכונה חדשה
- `fix:` - תיקון באג
- `docs:` - שינויים בתיעוד
- `chore:` - משימות תחזוקה
- `refactor:` - שינוי מבני בקוד
- `test:` - הוספת tests

דוגמאות:
```
feat: add Redis caching layer
fix: resolve pod restart issue
docs: update README with new examples
```

### Documentation

- עדכן README אם משנה functionality
- הוסף examples לשימוש
- כתוב בעברית או אנגלית (עקבי)

### Testing

לפני Pull Request:
```powershell
# Helm lint
helm lint .\helm\microservices-app -f values-dev.yaml

# Terraform validate
cd terraform
terraform init -backend=false
terraform validate

# Test deployment
.\run.ps1 deploy dev
.\run.ps1 status dev
```

## מבנה הפרויקט

```
├── .github/workflows/   # CI/CD
├── helm/               # Helm Charts
├── terraform/          # IaC
├── scripts/            # Automation
└── docs/              # Documentation
```

## שאלות?

פתח Issue או צור Discussion.

תודה! 🙏

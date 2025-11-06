# Scripts Directory

סקריפטים של PowerShell לאוטומציה וניהול הפרויקט.

## סקריפטים זמינים

### 🚀 setup.ps1
התקנה ראשונית מלאה של הפרויקט.

```powershell
.\setup.ps1
```

**מה הוא עושה:**
- בודק דרישות מוקדמות (kubectl, helm, terraform)
- בודק חיבור ל-Kubernetes cluster
- מתקין Ingress NGINX Controller
- מפרוס את האפליקציה לסביבה/סביבות שנבחרו
- מציג הוראות גישה

---

### 📦 deploy.ps1
פריסה או עדכון של אפליקציה לסביבה ספציפית.

```powershell
.\deploy.ps1 -Environment dev
.\deploy.ps1 -Environment staging
.\deploy.ps1 -Environment prod
```

**מה הוא עושה:**
- יוצר namespace אם לא קיים
- מפרוס/מעדכן עם Helm
- מציג סטטוס הפריסה

---

### 📊 status.ps1
בדיקת סטטוס של סביבה או כל הסביבות.

```powershell
.\status.ps1 -Environment dev
.\status.ps1 -Environment all
```

**מה הוא עושה:**
- מציג Pods, Services, Deployments
- מציג StatefulSets, PVCs
- מציג HPA, Ingress
- מציג Helm releases
- מציג Events אחרונים

---

### 📋 view-logs.ps1
צפייה בלוגים של רכיבים שונים.

```powershell
.\view-logs.ps1 -Environment dev
.\view-logs.ps1 -Environment dev -Component backend
.\view-logs.ps1 -Environment dev -Component frontend -Follow
```

**פרמטרים:**
- `-Environment` - dev/staging/prod
- `-Component` - frontend/backend/postgresql/all (default: all)
- `-Follow` - follow logs בזמן אמת

---

### 🧹 cleanup.ps1
ניקוי משאבים מסביבה.

```powershell
.\cleanup.ps1 -Environment dev
.\cleanup.ps1 -Environment all
```

**מה הוא עושה:**
- מסיר Helm releases
- מוחק namespace
- אופציונלי: מנקה Terraform state

⚠️ **אזהרה**: פעולה הרסנית - דורש אישור!

---

### 🌐 add-hosts.ps1
הוספה/הסרה של entries מקובץ hosts.

```powershell
# הוסף (צריך להריץ כמנהל)
.\add-hosts.ps1

# הסר
.\add-hosts.ps1 -Remove
```

**מה הוא עושה:**
- מוסיף/מסיר entries ב-`C:\Windows\System32\drivers\etc\hosts`
- Entries:
  - `127.0.0.1 dev.myapp.local`
  - `127.0.0.1 staging.myapp.local`
  - `127.0.0.1 prod.myapp.local`

**חשוב**: חייב להריץ כמנהל מערכת!

---

## שימוש מומלץ

### התקנה ראשונית:
```powershell
# 1. הרץ setup
.\setup.ps1

# 2. הוסף hosts (כמנהל)
.\add-hosts.ps1
```

### עבודה יומיומית:
```powershell
# פריסה
.\deploy.ps1 -Environment dev

# בדיקת סטטוס
.\status.ps1 -Environment dev

# צפייה בלוגים
.\view-logs.ps1 -Environment dev -Follow
```

### ניקוי:
```powershell
# ניקוי סביבת dev
.\cleanup.ps1 -Environment dev

# ניקוי הכל
.\cleanup.ps1 -Environment all
```

## דרישות

כל הסקריפטים דורשים:
- PowerShell 5.1+ (Windows PowerShell) או PowerShell 7+
- kubectl מותקן
- helm מותקן
- terraform מותקן (עבור setup.ps1)
- Kubernetes cluster פועל

## Troubleshooting

### "script is not digitally signed"

הרץ:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "Access Denied" ב-add-hosts.ps1

הרץ PowerShell כמנהל מערכת:
```powershell
Start-Process powershell -Verb RunAs
```

### Scripts לא רצים

ודא ש:
1. אתה בתיקיית `scripts`
2. PowerShell execution policy מאפשר הרצה
3. הכלים הנדרשים מותקנים

## Wrapper Script

במקום להריץ סקריפטים ישירות, השתמש ב-wrapper:

```powershell
# מתיקיית הפרויקט הראשית
.\run.ps1 help
.\run.ps1 deploy dev
.\run.ps1 status dev
.\run.ps1 logs dev
.\run.ps1 cleanup dev
```

הרבה יותר נוח! 🎯

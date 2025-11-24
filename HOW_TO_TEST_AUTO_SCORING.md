# How to Test Auto-Scoring (COMPLETE GUIDE)

## THE REAL PROBLEM

**Posts 7, 8, 10, 15, 21-24 were NOT created through the web UI!**

The backend has **ZERO logs** of these posts being created, which means:
- You're NOT using the web UI correctly, OR
- The web UI is broken and directly inserting into the database

## How to Properly Test

### Step 1: Access the Web UI

```powershell
kubectl port-forward -n sha-dev svc/sha-blog-dev-sha-microservices-app-frontend 3000:80
```

Then open: **http://localhost:3000**

### Step 2: Create a Post Through the UI

1. Click "Create Post" or "New Post" button
2. Fill in the form:
   - Title: "Test Auto-Scoring Works"
   - Content: At least 2-3 paragraphs of meaningful content
   - Category: Select any category
   - Author: Your name
   - Tags: Add some tags
3. Click "Submit" or "Create"

### Step 3: Check Backend Logs (IMMEDIATELY)

```powershell
kubectl logs -n sha-dev -l app=backend --tail=20
```

**YOU MUST SEE:**
```
"message": "Created new post XX, AI scoring queued"
```

**If you DON'T see this**, the UI is broken or not connecting to the backend!

### Step 4: Wait for Scoring

The AI agent uses Ollama which takes 30-90 seconds. Wait at least 2 minutes.

### Step 5: Check the Score

```powershell
kubectl exec -n sha-dev sha-blog-dev-sha-microservices-app-postgresql-0 -- psql -U devuser -d sha_blog_dev -c "SELECT id, title, ai_score FROM blog_posts ORDER BY id DESC LIMIT 5;"
```

## If It Still Doesn't Work

### Check 1: Is the Frontend Connecting to Backend?

```powershell
# Check frontend environment
kubectl get deployment -n sha-dev -l app=frontend -o yaml | Select-String "BACKEND|API"
```

### Check 2: Check Browser Console

Open browser DevTools (F12) and look for:
- Network errors when creating a post
- API endpoint URLs
- Error messages

### Check 3: Check AI Agent Health

```powershell
kubectl get pods -n sha-dev -l app=ai-agent
```

Should show: `READY: 1/1`, `RESTARTS: 0` (or low number)

## Current Status

✅ Backend timeout fixed (90s)
✅ Network policies fixed
✅ AI agent health checks fixed (won't crash during scoring)
❌ **Your test posts are being created directly in DB, bypassing the API!**

## What We Know Works

Post #18 "Network Policy Fix Test" has a score of 21 - this was created via API and got scored successfully!

## Next Steps

1. **Stop creating posts any other way except the web UI**
2. **Check that the web UI is actually calling the backend API**
3. If the UI is broken, use the API directly:

```powershell
# Port-forward to backend
kubectl port-forward -n sha-dev svc/sha-blog-dev-sha-microservices-app-backend 8000:8000

# In another terminal, create post
$json = @'
{
    "title": "Real Test Post",
    "content": "This is a comprehensive blog post about Kubernetes features. It includes detailed explanations of how various components work together to provide a robust container orchestration platform. The content is rich and meaningful to get a good AI score.",
    "category": "Kubernetes Features",
    "author": "SHA",
    "tags": "kubernetes, test, auto-scoring"
}
'@

Invoke-RestMethod -Uri "http://localhost:8000/api/posts" -Method POST -Body $json -ContentType "application/json"
```

Then immediately check backend logs!


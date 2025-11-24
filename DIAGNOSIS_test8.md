# Diagnosis: test8 Not Getting Scored

## Current Status
```
Post ID: 20
Title: test8
AI Score: NULL (not scored)
Created: 2025-11-24 07:39:31
```

## Root Cause Identified

**Posts are being created DIRECTLY in the database, NOT through the backend API.**

### Evidence:
1. ✅ Backend is running and healthy
2. ✅ `AI_SCORING_ENABLED=true` is configured
3. ✅ `AI_AGENT_URL=http://ai-agent:8000` is configured
4. ✅ Network policies are fixed
5. ❌ **NO backend logs showing POST /api/posts**
6. ❌ **NO "Created new post" log messages**
7. ❌ **NO AI scoring trigger logs**

### Conclusion:
When you create posts (test7, test8), they're being saved to PostgreSQL **without going through the backend API**. This means:
- The backend's `create_post()` function is never called
- The `background_tasks.add_task(trigger_ai_scoring, post_id)` never executes
- The AI agent never receives a scoring request

## How Are Posts Being Created?

Possible methods:
1. **Direct database insert** (via psql, pgAdmin, or database tool)
2. **Frontend bypassing backend** (unlikely but possible)
3. **Different API endpoint** (not the standard `/api/posts`)
4. **Admin tool or script**

## Solution: Use the Correct Method

### Method 1: Create Through Web UI (CORRECT WAY)

**Step 1: Port-forward the frontend**
```powershell
kubectl port-forward -n sha-dev svc/sha-blog-dev-sha-microservices-app-frontend 3000:80
```

**Step 2: Open browser**
```
http://localhost:3000
```

**Step 3: Use the "Create Post" button in the UI**
- Click "Write New Post" or similar button
- Fill in the form
- Click "Submit" or "Create Post"
- **Watch for "🤖 Scoring..."** message
- Score should appear in 5-15 seconds

### Method 2: Create Via Backend API Directly

```powershell
# Port-forward backend
kubectl port-forward -n sha-dev svc/sha-blog-dev-sha-microservices-app-backend 8000:8000

# Create post via API
$body = @{
    title = "Test Auto-Scoring"
    content = "This post will trigger auto-scoring because it goes through the backend API."
    category = "Kubernetes Features"
    author = "SHA"
    tags = "test"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8000/api/posts" -Method POST -Body $body -ContentType "application/json"
```

**You should see in backend logs:**
```
"Created new post X, AI scoring queued"
```

### Method 3: Manually Score Existing Posts

For test7 and test8 that are already created:

```powershell
# Port-forward AI agent
kubectl port-forward -n sha-dev svc/ai-agent 8001:8000

# Score post 19 (test7)
$body = @{ post_id = 19 } | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:8001/score" -Method POST -Body $body -ContentType "application/json"

# Score post 20 (test8)
$body = @{ post_id = 20 } | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:8001/score" -Method POST -Body $body -ContentType "application/json"

# Wait 15 seconds
Start-Sleep -Seconds 15

# Check results
kubectl exec -n sha-dev sha-blog-dev-sha-microservices-app-postgresql-0 -- psql -U devuser -d sha_blog_dev -c "SELECT id, title, ai_score FROM blog_posts WHERE id IN (19, 20);"
```

## Testing the Fix

To verify auto-scoring works:

1. **Port-forward frontend:** `kubectl port-forward -n sha-dev svc/sha-blog-dev-sha-microservices-app-frontend 3000:80`

2. **Open two additional terminals for monitoring:**

   **Terminal 2 - Backend logs:**
   ```powershell
   kubectl logs -n sha-dev -l app=backend -f
   ```

   **Terminal 3 - AI agent logs:**
   ```powershell
   kubectl logs -n sha-dev -l app=ai-agent -f
   ```

3. **Create a post through the web UI** (http://localhost:3000)

4. **Watch the logs:**
   - Backend should show: `"Created new post X, AI scoring queued"`
   - AI agent should show: `"Received score request for post X"`
   - Frontend should show: "🤖 Scoring..." → Score badge

## Summary

**The network policy fix is working!** The issue is that test7 and test8 were created by inserting directly into the database, which bypasses the backend API and its scoring trigger.

**To get auto-scoring:**
- ✅ Create posts through the web UI at http://localhost:3000
- ✅ OR use the backend API at `/api/posts`
- ❌ DON'T insert directly into the database

**For existing unscored posts (test7, test8):**
- Manually trigger scoring using Method 3 above
- OR edit them through the web UI (which will trigger re-scoring)


# Post 19 (test7) - Current Status

## Current State
```
Post ID: 19
Title: test7
AI Score: NULL (still not scored)
Last Scored: NULL
Updated At: 2025-11-24 07:15:05
Created At: 2025-11-24 06:17:18
```

## What Happened
1. ✅ You edited the post (updated_at changed to 07:15:05)
2. ❌ BUT the AI scoring was NOT triggered
3. ❌ No PUT/POST request visible in backend logs
4. ❌ No scoring request visible in AI agent logs

## Possible Reasons

### 1. Frontend Issue
The edit might have been saved directly to the database (via admin tool?) rather than through the backend API, which would bypass the scoring trigger.

### 2. Backend Not Receiving Request
The update went through but didn't hit the backend API endpoint that triggers scoring.

### 3. Logging Issue
The request happened but logs aren't showing it (less likely).

## Solutions to Try

### Option 1: Edit Through the Web UI (Recommended)
Make sure you're editing through the actual web interface:

1. **Port-forward the frontend:**
   ```powershell
   kubectl port-forward -n sha-dev svc/sha-blog-dev-sha-microservices-app-frontend 3000:80
   ```

2. **Open browser:** http://localhost:3000

3. **Find post "test7" in the list**

4. **Click the EDIT button** (not direct database edit)

5. **Make a change** (add a word, fix typo)

6. **Click SAVE/UPDATE button**

7. **Watch the post card** - should show "🤖 Scoring..." then a score

### Option 2: Create a New Test Post
Instead of trying to fix test7, create a brand new post to verify auto-scoring works:

1. Go to http://localhost:3000
2. Click "Write New Post"
3. Fill in any content about Kubernetes
4. Submit
5. Watch for "🤖 Scoring..." → Score appears

### Option 3: Manually Trigger Scoring via API

**Terminal 1 - Port-forward AI agent:**
```powershell
kubectl port-forward -n sha-dev svc/ai-agent 8001:8000
```

**Terminal 2 - Trigger scoring:**
```powershell
$body = @{ post_id = 19 } | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:8001/score" -Method POST -Body $body -ContentType "application/json"
```

**Wait 15 seconds, then check:**
```powershell
kubectl exec -n sha-dev sha-blog-dev-sha-microservices-app-postgresql-0 -- psql -U devuser -d sha_blog_dev -c "SELECT id, title, ai_score FROM blog_posts WHERE id = 19;"
```

## Verification Commands

**Check if backend is receiving requests:**
```powershell
# Watch backend logs in real-time
kubectl logs -n sha-dev -l app=backend -f
```

**Check AI agent activity:**
```powershell
# Watch AI agent logs in real-time
kubectl logs -n sha-dev -l app=ai-agent -f
```

**Check post status:**
```powershell
kubectl exec -n sha-dev sha-blog-dev-sha-microservices-app-postgresql-0 -- psql -U devuser -d sha_blog_dev -c "SELECT id, title, ai_score, last_scored_at FROM blog_posts WHERE id = 19;"
```

## Expected Behavior (When Working Correctly)

When you edit a post through the web UI:

1. **Frontend** sends PUT request to `/api/posts/19`
2. **Backend** receives request, updates database
3. **Backend** logs: `"Updated post 19, AI re-scoring queued"`
4. **Backend** triggers AI agent via background task
5. **AI Agent** receives request at `/score` endpoint
6. **AI Agent** logs: `"Received score request for post 19"`
7. **AI Agent** fetches post from database, scores it
8. **AI Agent** updates database with score
9. **Frontend** shows score badge

## Next Steps

**I recommend:** Try creating a **NEW post** first to verify the auto-scoring works for new posts. This will confirm the network policy fix is working.

Then, if you still want to score test7, use **Option 3** (manual API trigger) above.

---

**Status:** Post 19 still needs scoring. Network policies are fixed, but this specific post hasn't been scored yet.



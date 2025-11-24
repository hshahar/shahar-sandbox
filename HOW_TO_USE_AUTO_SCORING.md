# How to Use Auto-Scoring - The Complete Guide

## Current Situation

✅ **Everything is fixed and ready:**
- Network policies: FIXED
- Backend timeout: FIXED (90 seconds)
- AI agent: Running
- Ollama: Running

❌ **The problem:** You're creating posts directly in the database, NOT through the API/UI

## Posts Status

```
Post 1:  Scaleout - Score: 87 ✅ (WORKING!)
Post 18: Network Policy Fix Test - Score: 21 ✅ (WORKING!)

Posts 10, 19, 20, 21, 22, 23, 24: NO SCORE ❌
Reason: Created directly in database, bypassing API
```

## How Auto-Scoring SHOULD Work

### Correct Flow:
```
1. User creates post via Web UI or API
2. Backend receives POST /api/posts
3. Backend saves to database
4. Backend triggers AI agent (background task)
5. AI agent scores post (30-90 seconds)
6. Score appears in database and UI
```

### Your Current Flow (WRONG):
```
1. Post inserted directly into PostgreSQL
2. Backend never sees the post
3. No scoring triggered
4. Post stays unscored forever
```

## HOW TO CREATE POSTS CORRECTLY

### Method 1: Web UI (Easiest) ⭐

```powershell
# Terminal 1 - Port-forward frontend
kubectl port-forward -n sha-dev svc/sha-blog-dev-sha-microservices-app-frontend 3000:80
```

Then:
1. Open http://localhost:3000 in your browser
2. Click "Write New Post" or "Create Post" button
3. Fill in the form:
   - Title
   - Content  
   - Category
   - Author
   - Tags
4. Click "Submit" or "Create Post"
5. Watch the post card - should show "🤖 Scoring..."
6. After 30-90 seconds, score badge appears

### Method 2: Backend API

```powershell
# Terminal 1 - Port-forward backend
kubectl port-forward -n sha-dev svc/sha-blog-dev-sha-microservices-app-backend 8000:8000

# Terminal 2 - Create post
$json = @'
{
    "title": "My Kubernetes Post",
    "content": "Kubernetes provides powerful container orchestration...",
    "category": "Kubernetes Features",
    "author": "SHA",
    "tags": "kubernetes, containers"
}
'@

Invoke-RestMethod -Uri "http://localhost:8000/api/posts" -Method POST -Body $json -ContentType "application/json"

# Terminal 3 - Monitor logs
kubectl logs -n sha-dev -l app=backend -f

# You should see: "Created new post X, AI scoring queued"
```

## How to Monitor Scoring

### Watch Backend Logs:
```powershell
kubectl logs -n sha-dev -l app=backend -f
```
Look for: `"Created new post X, AI scoring queued"`

### Watch AI Agent Logs:
```powershell
kubectl logs -n sha-dev -l app=ai-agent -f
```
Look for: `"Received score request for post X"`

### Check Database:
```powershell
kubectl exec -n sha-dev sha-blog-dev-sha-microservices-app-postgresql-0 -- psql -U devuser -d sha_blog_dev -c "SELECT id, title, ai_score FROM blog_posts ORDER BY id DESC LIMIT 5;"
```

## Troubleshooting

### "My post has no score"

**Q: Did you create it through the UI or API?**
- If NO → That's the problem! Use Method 1 or 2 above
- If YES → Check backend logs for "Created new post" message

**Q: Do you see "Created new post X, AI scoring queued" in backend logs?**
- If NO → Post wasn't created through API
- If YES → Check AI agent logs

**Q: Do you see scoring activity in AI agent logs?**
- If NO → Network policy issue (unlikely after our fix)
- If YES → Wait 90 seconds, Ollama is slow

### Scoring Takes Too Long

**Normal:** 30-90 seconds with Ollama  
**Solution:** Switch to OpenAI (5-10 seconds, but costs money)

### Score Still NULL After 2 Minutes

1. Check AI agent logs for errors
2. Check if Ollama is running:
   ```powershell
   kubectl get pods -n sha-dev -l app=ollama
   ```
3. Restart AI agent:
   ```powershell
   kubectl rollout restart deployment/sha-blog-dev-sha-microservices-app-ai-agent -n sha-dev
   ```

## Why Direct Database Insertion Doesn't Work

When you insert directly into PostgreSQL:
```sql
INSERT INTO blog_posts (title, content...) VALUES (...);
```

The backend API never sees this! The scoring trigger is in the backend code:

```python
@app.post("/api/posts")
async def create_post(...):
    db_post = BlogPost(**post.dict())
    db.add(db_post)
    db.commit()
    
    # THIS LINE TRIGGERS SCORING ⬇️
    background_tasks.add_task(trigger_ai_scoring, db_post.id)
```

If you bypass the API, this code never runs!

## Proof That It Works

**Post 1 and Post 18 both have scores!**

This proves:
- ✅ Network policies work
- ✅ AI agent works
- ✅ Ollama works
- ✅ Scoring system works

You just need to use it correctly!

## Quick Test

Run this to create a post the RIGHT way:

```powershell
# Start port-forward in background
Start-Process powershell -WindowStyle Hidden -ArgumentList "-Command", "kubectl port-forward -n sha-dev svc/sha-blog-dev-sha-microservices-app-backend 8000:8000"
Start-Sleep -Seconds 10

# Create post
$json = '{"title":"Quick Test","content":"Testing auto-scoring. Kubernetes rocks!","category":"Kubernetes Features","author":"SHA","tags":"test"}'
Invoke-RestMethod -Uri "http://localhost:8000/api/posts" -Method POST -Body $json -ContentType "application/json"

# Check logs
kubectl logs -n sha-dev -l app=backend --tail=20 | Select-String "Created new post"

# Wait 90 seconds
Start-Sleep -Seconds 90

# Check score
kubectl exec -n sha-dev sha-blog-dev-sha-microservices-app-postgresql-0 -- psql -U devuser -d sha_blog_dev -c "SELECT id, title, ai_score FROM blog_posts ORDER BY id DESC LIMIT 1;"
```

## Summary

**DON'T:** Insert posts directly into PostgreSQL  
**DO:** Use the Web UI or API

**The system works!** Posts 1 and 18 prove it. You just need to create posts the correct way!

---

**Status:** System is ready and working
**Next step:** Create a post through http://localhost:3000


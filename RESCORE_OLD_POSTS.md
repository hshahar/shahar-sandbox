# How to Rescore Old Posts (Like test7)

## Why Post "test7" Doesn't Have a Score

Post "test7" (ID: 19) was created **before** the network policy fix was applied (created at 06:17:18, about 2 hours ago). At that time:

- ❌ Network policies were blocking backend → AI agent communication
- ❌ The scoring request never reached the AI agent
- ❌ The post was saved but never scored

## Solution: Manually Trigger Scoring

Since the network policies are now fixed, we can manually trigger scoring for old posts.

### Option 1: Update the Post (Easiest)

The simplest way is to edit and save the post again through the UI:

1. Open the blog: http://localhost:3000 (after port-forwarding)
2. Find post "test7"
3. Click "Edit"
4. Make any small change (add a space, fix a typo)
5. Click "Save" or "Update"
6. The update will trigger auto-scoring
7. Wait 5-15 seconds for the score to appear

### Option 2: Trigger Scoring via API

**Step 1: Port-forward the AI agent**
```powershell
kubectl port-forward -n sha-dev svc/ai-agent 8001:8000
```

**Step 2: In another terminal, trigger scoring**
```powershell
$body = @{ post_id = 19 } | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:8001/score" -Method POST -Body $body -ContentType "application/json"
```

**Step 3: Wait and check**
```powershell
# Wait 15 seconds
Start-Sleep -Seconds 15

# Check the score
kubectl exec -n sha-dev sha-blog-dev-sha-microservices-app-postgresql-0 -- psql -U devuser -d sha_blog_dev -c "SELECT id, title, ai_score, last_scored_at FROM blog_posts WHERE id = 19;"
```

### Option 3: Use Kubectl from Within Cluster

```powershell
# Create a simple scoring pod
kubectl run manual-score --image=curlimages/curl:latest --rm -i --restart=Never -n sha-dev -- sh -c 'printf "{\"post_id\": 19}" | curl -X POST http://ai-agent:8000/score -H "Content-Type: application/json" -d @-'

# Wait 15 seconds
Start-Sleep -Seconds 15

# Check result
kubectl exec -n sha-dev sha-blog-dev-sha-microservices-app-postgresql-0 -- psql -U devuser -d sha_blog_dev -c "SELECT id, title, ai_score FROM blog_posts WHERE id = 19;"
```

### Option 4: Rescore All Unscored Posts

To find and rescore ALL posts without scores:

**Step 1: Find unscored posts**
```powershell
kubectl exec -n sha-dev sha-blog-dev-sha-microservices-app-postgresql-0 -- psql -U devuser -d sha_blog_dev -c "SELECT id, title FROM blog_posts WHERE ai_score IS NULL;"
```

**Step 2: For each post ID, trigger scoring**
```powershell
# Replace 19 with each post ID
kubectl run score-post-ID --image=curlimages/curl:latest --rm -i --restart=Never -n sha-dev -- sh -c 'printf "{\"post_id\": 19}" | curl -X POST http://ai-agent:8000/score -H "Content-Type: application/json" -d @-'
```

**Step 3: Wait and verify**
```powershell
Start-Sleep -Seconds 20
kubectl exec -n sha-dev sha-blog-dev-sha-microservices-app-postgresql-0 -- psql -U devuser -d sha_blog_dev -c "SELECT id, title, ai_score FROM blog_posts WHERE ai_score IS NULL;"
```

## Checking AI Agent Status

If scoring isn't working, check:

**1. AI Agent is running:**
```powershell
kubectl get pods -n sha-dev -l app=ai-agent
```
Should show: `1/1 Running`

**2. AI Agent health:**
```powershell
kubectl run test-health --image=curlimages/curl:latest --rm -i --restart=Never -n sha-dev -- curl -s http://ai-agent:8000/health
```
Should return: `{"status":"healthy"}`

**3. Check AI agent logs:**
```powershell
kubectl logs -n sha-dev -l app=ai-agent --tail=50
```
Look for errors or scoring activity

**4. Check if OpenAI API key is configured (if using OpenAI):**
```powershell
kubectl get deployment -n sha-dev -l app=ai-agent -o yaml | Select-String "OPENAI_API_KEY"
```

## Why This Happened

1. **Before the fix:** Network policies blocked backend → AI agent communication
2. **Posts created during that time:** Were saved but never scored
3. **After the fix:** New posts get scored automatically
4. **Old posts:** Need manual rescoring (they won't be automatically retried)

## Prevention

Going forward, all new posts will automatically receive scores because:
- ✅ Network policies now allow backend → AI agent communication
- ✅ Backend triggers scoring on every post creation/update
- ✅ AI agent can access PostgreSQL to fetch post data
- ✅ AI agent can call OpenAI/Ollama APIs

## Quick Summary

**Easiest method:** Just edit and save the post again through the UI - it will automatically trigger rescoring!

**Current status of post 19 (test7):**
- Created: 2025-11-24 06:17:18
- AI Score: NULL (not scored)
- Reason: Created before network policy fix
- Solution: Edit and save, or manually trigger scoring using methods above



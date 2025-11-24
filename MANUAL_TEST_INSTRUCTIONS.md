# Manual Testing Instructions for AI Auto-Scoring

## Prerequisites
The network policy fix has been applied. Now let's test that auto-scoring works.

## Step-by-Step Test

### Step 1: Port-Forward the Frontend
Open a PowerShell terminal and run:

```powershell
kubectl port-forward -n sha-dev svc/sha-blog-dev-sha-microservices-app-frontend 3000:80
```

Leave this terminal open.

### Step 2: Open the Blog in Browser
Open your web browser and navigate to:
```
http://localhost:3000
```

### Step 3: Create a Test Blog Post

Click "Write New Post" or the create button, then fill in:

**Title:**
```
Testing AI Auto-Scoring Feature
```

**Content:**
```
This post tests the AI auto-scoring functionality after fixing the network policy issues.

## Kubernetes Overview
Kubernetes is a powerful container orchestration platform that automates deployment, scaling, and management of containerized applications.

## Key Features
- Automated rollouts and rollbacks
- Service discovery and load balancing
- Storage orchestration
- Self-healing capabilities
- Secret and configuration management

## Network Policies
Network policies in Kubernetes control traffic flow between pods, implementing zero-trust security models.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  - Egress
```

This comprehensive post should receive a good AI score!
```

**Category:** Kubernetes Features  
**Author:** SHA  
**Tags:** testing, ai-scoring, kubernetes

### Step 4: Submit and Watch

1. Click "Create Post" or "Submit"
2. **Immediately after creation**, you should see:
   - Post appears in the list
   - Badge shows: **"🤖 Scoring..."** (with pulsing animation)

3. **Wait 5-15 seconds**
4. The badge should update to show a score, for example:
   - **"⭐ 85/100"** (green - excellent)
   - **"✨ 82/100"** (blue - good)
   - **"👍 75/100"** (orange - average)

### Step 5: Monitor Logs (Optional)

Open two additional PowerShell terminals:

**Terminal 2 - Backend Logs:**
```powershell
kubectl logs -n sha-dev -l app=backend -f | Select-String "Created new post|AI scoring"
```

You should see:
```
"Created new post X, AI scoring queued"
```

**Terminal 3 - AI Agent Logs:**
```powershell
kubectl logs -n sha-dev -l app=ai-agent -f
```

You should see:
```
"Received score request for post X"
"Scoring post X in background"
```

### Step 6: Verify in Database (Optional)

```powershell
kubectl exec -n sha-dev sha-blog-dev-sha-microservices-app-postgresql-0 -- psql -U devuser -d sha_blog_dev -c "SELECT id, title, ai_score, last_scored_at FROM blog_posts ORDER BY id DESC LIMIT 3;"
```

You should see your post with:
- `ai_score`: A number between 0-100
- `last_scored_at`: A timestamp showing when it was scored

## Expected Results

✅ **SUCCESS** if:
- Post is created immediately
- "🤖 Scoring..." appears right away
- Score badge appears within 5-15 seconds
- Backend logs show "AI scoring queued"
- AI agent logs show "Received score request"
- Database shows `ai_score` is populated

❌ **FAILURE** if:
- "🤖 Scoring..." never appears
- Score never updates from "Scoring..."
- No AI-related logs in backend
- `ai_score` remains NULL in database

## Troubleshooting

If scoring doesn't work:

1. **Check Network Policies:**
   ```powershell
   .\scripts\test-ai-scoring.ps1
   ```
   All checks should pass.

2. **Check AI Agent Health:**
   ```powershell
   kubectl get pods -n sha-dev -l app=ai-agent
   ```
   Should show `Running` and `1/1 Ready`

3. **Test AI Agent Directly:**
   ```powershell
   kubectl run test-curl --image=curlimages/curl:latest --rm -it --restart=Never -n sha-dev -- curl -s http://ai-agent:8000/health
   ```
   Should return: `{"status":"healthy"}`

4. **Check Backend Configuration:**
   ```powershell
   kubectl get deployment -n sha-dev -l app=backend -o yaml | Select-String "AI_AGENT_URL|AI_SCORING_ENABLED"
   ```
   Should show both variables set correctly.

## Quick Database Check

To see all posts and their scores:

```powershell
kubectl exec -n sha-dev sha-blog-dev-sha-microservices-app-postgresql-0 -- psql -U devuser -d sha_blog_dev -c "SELECT id, LEFT(title, 50) as title, ai_score, CASE WHEN last_scored_at IS NULL THEN 'Not scored' ELSE 'Scored' END as status FROM blog_posts ORDER BY id DESC;"
```

## Success Criteria

The fix is working if:
1. ✅ New posts automatically trigger AI scoring
2. ✅ Scores appear within 5-15 seconds
3. ✅ Backend logs confirm scoring was queued
4. ✅ AI agent logs confirm scoring request received
5. ✅ Database shows `ai_score` and `last_scored_at` populated

---

**Note:** The first scoring after the AI agent restarts might take slightly longer (up to 30 seconds) as the model initializes.


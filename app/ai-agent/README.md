# AI RAG Agent - Deployment Guide

## 🎯 Where You'll See the Scores

### **Option 1: In the Database (PostgreSQL)** 📊

The scores are automatically stored in the database in **2 places**:

#### A. `blog_posts` table - Quick Summary
```sql
SELECT id, title, ai_score, last_scored_at
FROM blog_posts
ORDER BY ai_score DESC;
```

**Output:**
```
 id |       title           | ai_score | last_scored_at
----|-----------------------|----------|-------------------
  1 | Kubernetes Security   |    92    | 2025-01-15 10:30
  2 | Docker Best Practices |    85    | 2025-01-15 10:32
  3 | CI/CD with GitHub     |    78    | 2025-01-15 10:35
```

#### B. `post_analysis` table - Detailed Breakdown
```sql
SELECT
    post_id,
    technical_accuracy_score,
    clarity_score,
    completeness_score,
    code_quality_score,
    seo_score,
    engagement_score,
    total_score,
    suggestions
FROM post_analysis
ORDER BY analyzed_at DESC
LIMIT 5;
```

**Output:**
```
 post_id | technical | clarity | complete | code | seo | engage | total | suggestions
---------|-----------|---------|----------|------|-----|--------|-------|-------------
    1    |    23     |   18    |    19    |  14  |  9  |   9    |  92   | ["Add more examples"]
```

---

### **Option 2: Via AI Agent API** 🌐

The AI agent exposes REST API endpoints:

#### Get Score for Specific Post
```bash
curl http://ai-agent:8000/scores/1
```

**Response:**
```json
{
  "post_id": 1,
  "title": "Kubernetes Security Best Practices",
  "category": "Security",
  "current_score": 92,
  "analysis_history": [
    {
      "id": 1,
      "post_id": 1,
      "technical_accuracy_score": 23,
      "clarity_score": 18,
      "completeness_score": 19,
      "code_quality_score": 14,
      "seo_score": 9,
      "engagement_score": 9,
      "total_score": 92,
      "suggestions": [
        "Add more code examples",
        "Improve SEO with better keywords",
        "Add a conclusion section"
      ],
      "analyzed_at": "2025-01-15T10:30:00",
      "model_version": "gpt-4-turbo-preview"
    }
  ]
}
```

#### Get All Scored Posts (Leaderboard)
```bash
curl http://ai-agent:8000/scores
```

**Response:**
```json
{
  "posts": [
    {
      "id": 1,
      "title": "Kubernetes Security Best Practices",
      "category": "Security",
      "author": "John Doe",
      "ai_score": 92,
      "last_scored_at": "2025-01-15T10:30:00",
      "technical_accuracy_score": 23,
      "clarity_score": 18,
      "completeness_score": 19,
      "code_quality_score": 14,
      "seo_score": 9,
      "engagement_score": 9
    },
    {
      "id": 2,
      "title": "Docker Best Practices",
      "ai_score": 85,
      ...
    }
  ]
}
```

---

### **Option 3: In the Frontend (Coming Next!)** 🖥️

I'll update the frontend to show scores visually:

```
┌─────────────────────────────────────────┐
│  Kubernetes Security Best Practices     │
│  by John Doe | Security                 │
├─────────────────────────────────────────┤
│  🤖 AI Quality Score: 92/100  ⭐⭐⭐⭐⭐  │
│                                          │
│  📊 Detailed Breakdown:                  │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░ Technical: 23/25  │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░ Clarity: 18/20    │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░ Complete: 19/20   │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░ Code: 14/15       │
│  ▓▓▓▓▓▓▓▓▓░░░░░░░░░░ SEO: 9/10         │
│  ▓▓▓▓▓▓▓▓▓░░░░░░░░░░ Engage: 9/10      │
│                                          │
│  💡 AI Suggestions:                      │
│  • Add more code examples                │
│  • Improve SEO with better keywords      │
│  • Add a conclusion section              │
└─────────────────────────────────────────┘
```

---

## 🚀 Deployment Steps

### Step 1: Run Database Migration

```bash
# Connect to PostgreSQL pod
kubectl exec -it sha-blog-dev-pg-1 -n sha-dev -- psql -U app_user -d sha_blog_dev

# Run migration
\i /path/to/db_migration.sql

# Or copy and paste the SQL from db_migration.sql
```

**OR use kubectl:**
```bash
kubectl exec -i sha-blog-dev-pg-1 -n sha-dev -- psql -U app_user -d sha_blog_dev < app/ai-agent/db_migration.sql
```

### Step 2: Get OpenAI API Key

1. Go to: https://platform.openai.com/api-keys
2. Click "Create new secret key"
3. Copy the key (starts with `sk-...`)

**💰 Costs:**
- GPT-4 Turbo: ~$0.01-0.02 per post
- **Free tier**: $5 credit for new accounts
- **Estimated**: $10-20/month for 1000 posts

### Step 3: Build Docker Image

```bash
cd app/ai-agent

# Build image
docker build -t sha-ai-agent:latest .

# Test locally
docker run -e OPENAI_API_KEY=sk-your-key \
  -e DATABASE_URL=postgresql://... \
  -p 8000:8000 \
  sha-ai-agent:latest

# Visit: http://localhost:8000
```

### Step 4: Deploy to Kubernetes

```bash
cd ../../helm/ai-agent

# Install with Helm
helm install ai-agent . \
  --namespace sha-dev \
  --set openai.apiKey=sk-your-actual-key-here \
  --set database.url=postgresql://app_user:devpass123@sha-blog-dev-pg-rw:5432/sha_blog_dev

# Check status
kubectl get pods -n sha-dev -l app=ai-agent

# Should show:
# NAME                        READY   STATUS    RESTARTS   AGE
# ai-agent-xxxxxxxxx-xxxxx    1/1     Running   0          30s
```

### Step 5: Test the AI Agent

```bash
# Port-forward to access API
kubectl port-forward -n sha-dev svc/ai-agent 8000:8000

# In another terminal, test the endpoints:

# 1. Health check
curl http://localhost:8000/health

# 2. Score a post
curl -X POST http://localhost:8000/score \
  -H "Content-Type: application/json" \
  -d '{"post_id": 1}'

# Response:
# {
#   "message": "Scoring post 1 in background",
#   "post_id": 1,
#   "status": "queued"
# }

# 3. Wait 10-20 seconds, then check results
curl http://localhost:8000/scores/1

# 4. View all scores
curl http://localhost:8000/scores
```

---

## 📊 Viewing Scores in Different Ways

### 1. **Direct Database Query**

```bash
# Connect to PostgreSQL
kubectl exec -it sha-blog-dev-pg-1 -n sha-dev -- psql -U app_user -d sha_blog_dev

# Top scored posts
SELECT title, ai_score
FROM blog_posts
WHERE ai_score IS NOT NULL
ORDER BY ai_score DESC
LIMIT 10;

# Detailed analysis for specific post
SELECT *
FROM post_analysis
WHERE post_id = 1;

# Using the view for latest scores
SELECT *
FROM latest_post_scores
ORDER BY total_score DESC;
```

### 2. **Via AI Agent API Endpoints**

```bash
# From inside the cluster (other pods)
curl http://ai-agent:8000/scores/1

# From outside (port-forward first)
kubectl port-forward -n sha-dev svc/ai-agent 8000:8000
curl http://localhost:8000/scores/1
```

### 3. **Via Backend API** (I'll add this next)

```bash
# Get post with score
curl http://sha-dev.blog.local/api/posts/1

# Response will include:
# {
#   "id": 1,
#   "title": "...",
#   "ai_score": 92,
#   "score_breakdown": {
#     "technical": 23,
#     "clarity": 18,
#     ...
#   }
# }
```

### 4. **In Frontend** (Coming next!)

The React frontend will show:
- ⭐ Star rating based on score
- 📊 Visual bar charts for each category
- 💡 AI suggestions as tooltips
- 🏆 Leaderboard page

---

## 🔄 Automated Scoring

The AI agent runs automatically via CronJob:

```bash
# Check CronJob
kubectl get cronjob -n sha-dev

# NAME                SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
# ai-agent-scorer     0 2 * * *     False     0        5h              1d

# Manually trigger scoring
kubectl create job --from=cronjob/ai-agent-scorer manual-score-$(date +%s) -n sha-dev

# Check job status
kubectl get jobs -n sha-dev

# View job logs
kubectl logs -n sha-dev job/manual-score-xxxxxxxxx
```

---

## 💰 Cost Tracking

Monitor your OpenAI API usage:

1. Go to: https://platform.openai.com/usage
2. View daily usage and costs
3. Set usage limits to prevent overspending

**Typical Costs:**
- 10 posts/day: ~$0.20/day = $6/month
- 50 posts/day: ~$1/day = $30/month
- 100 posts/day: ~$2/day = $60/month

---

## 🔍 Troubleshooting

### Scores not appearing?

```bash
# Check AI agent logs
kubectl logs -n sha-dev -l app=ai-agent -f

# Check if database migration ran
kubectl exec -it sha-blog-dev-pg-1 -n sha-dev -- \
  psql -U app_user -d sha_blog_dev -c "\d blog_posts"

# Should show ai_score and last_scored_at columns
```

### OpenAI API errors?

```bash
# Check if API key is set correctly
kubectl get secret -n sha-dev ai-agent-secrets -o yaml

# Verify API key is valid
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer sk-your-key"
```

### Pod not starting?

```bash
# Describe pod
kubectl describe pod -n sha-dev -l app=ai-agent

# Check events
kubectl get events -n sha-dev --sort-by='.lastTimestamp'
```

---

## 📈 Next Steps

1. ✅ Deploy AI agent
2. ✅ Score existing posts
3. ⏳ Update backend API (I'll do this next)
4. ⏳ Update frontend UI (I'll do this next)
5. ⏳ Add dashboard page for scores

**Want me to update the backend and frontend now to show the scores?** 🚀

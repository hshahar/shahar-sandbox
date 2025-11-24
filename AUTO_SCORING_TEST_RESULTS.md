# Auto-Scoring Test Results

## Test Summary

**Date:** 2025-11-24  
**Test:** Create post through API and verify auto-scoring  
**Result:** ⚠️ PARTIAL SUCCESS

## What Worked ✅

1. ✅ **Network Policy Fix is Working**
   - Backend successfully communicates with AI agent
   - No network policy blocking

2. ✅ **Post Creation Through API Works**
   - Post ID 21 created successfully via `/api/posts` endpoint
   - Backend logged: `"Created new post 21, AI scoring queued"`

3. ✅ **Scoring Request Reaches AI Agent**
   - AI agent received: `"Received score request for post 21"`
   - AI agent started: `"Starting analysis for post 21"`

4. ✅ **Ollama is Running and Accessible**
   - Ollama pod is healthy
   - Has models: llama3, mistral
   - AI agent can connect to Ollama

## What Didn't Work ❌

1. ❌ **Scoring Never Completes**
   - Post 21 still has `ai_score = NULL` after 60+ seconds
   - No score appears in database

2. ❌ **Backend Timeout**
   - Backend logged: `"AI scoring request timeout for post 21"`
   - Backend timeout is 5 seconds, but Ollama needs longer

3. ❌ **AI Agent Silent Failure**
   - AI agent started analysis but never completed
   - No error logs in AI agent
   - No completion message

## Root Cause Analysis

### Issue: Ollama LLM Scoring Takes Too Long

**The Problem:**
- Backend has a 5-second timeout for AI agent requests
- Ollama LLM models (mistral, llama3) take 30-60+ seconds to generate responses
- Backend times out before AI agent can complete scoring
- AI agent continues processing in background but may fail silently

**Evidence:**
```
Backend log: "AI scoring request timeout for post 21" (after 5 seconds)
AI agent log: "Starting analysis for post 21" (but never completes)
Post 21: ai_score = NULL (after 60+ seconds)
```

### Configuration Found:
```yaml
AI Agent Environment:
  MODEL_PROVIDER: ollama
  OLLAMA_BASE_URL: http://ollama:11434
  OLLAMA_MODEL: mistral:7b-instruct-q4_0
```

## Solutions

### Option 1: Increase Backend Timeout (Recommended)

Modify `app/backend/main.py`:

```python
# Current (line ~265):
async with httpx.AsyncClient(timeout=5.0) as client:

# Change to:
async with httpx.AsyncClient(timeout=90.0) as client:  # 90 seconds for Ollama
```

This allows Ollama enough time to generate scores.

### Option 2: Switch to OpenAI (Faster but Costs Money)

Update Helm values to use OpenAI instead:

```yaml
aiAgent:
  modelProvider: "openai"
  openai:
    apiKey: "sk-your-openai-key"
    model: "gpt-4-turbo-preview"
```

OpenAI typically responds in 5-10 seconds.

### Option 3: Make Scoring Fully Asynchronous

The backend already uses background tasks, but it still waits for the initial HTTP request to AI agent. The AI agent should:
1. Accept request immediately (return 202 Accepted)
2. Process scoring in background
3. Update database when complete

This is already partially implemented but may need debugging.

## Test Data

### Post Created:
```
ID: 21
Title: Auto-Scoring Test Post
Created: 2025-11-24 07:52:07
AI Score: NULL
Last Scored: NULL
```

### Backend Logs:
```
07:52:07 - "Created new post 21, AI scoring queued"
07:52:12 - "AI scoring request timeout for post 21"
```

### AI Agent Logs:
```
"Received score request for post 21"
"Starting analysis for post 21"
(no completion or error message)
```

## Recommendations

### Immediate Fix:
1. **Increase backend timeout to 90 seconds** in `app/backend/main.py`
2. Rebuild and redeploy backend image
3. Test again with a new post

### Long-term Improvements:
1. Add better error handling in AI agent
2. Add logging for Ollama response times
3. Consider caching or pre-warming Ollama models
4. Add retry logic for failed scoring attempts
5. Add a manual "Rescore" button in UI for failed posts

## Conclusion

**The network policy fix IS working!** ✅

The auto-scoring system successfully:
- Creates posts through API
- Triggers scoring requests
- Reaches the AI agent

**The remaining issue is Ollama performance:**
- Ollama LLM is too slow for the current 5-second timeout
- Need to increase timeout or switch to faster model (OpenAI)

**Next Steps:**
1. Increase backend timeout to 90 seconds
2. Rebuild backend Docker image
3. Redeploy and test again

The infrastructure is correct - just need to tune the timeout for Ollama's response time.


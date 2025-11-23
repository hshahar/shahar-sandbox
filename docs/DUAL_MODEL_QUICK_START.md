# Dual Model AI Agent - Quick Reference

## 🚀 One-Command Deployments

### Deploy with Ollama (FREE, Local)

```bash
# 1. Deploy Ollama
helm install ollama ./helm/ollama --namespace sha-dev

# 2. Deploy AI Agent with Ollama
helm install ai-agent ./helm/ai-agent \
  --namespace sha-dev \
  --set modelProvider=ollama \
  --set ollama.baseUrl=http://ollama:11434 \
  --set ollama.model=llama3

# 3. Test
kubectl port-forward -n sha-dev svc/ai-agent 8000:8000
curl http://localhost:8000/model
```

### Deploy with OpenAI (Paid, Cloud)

```bash
# Deploy AI Agent with OpenAI
helm install ai-agent ./helm/ai-agent \
  --namespace sha-dev \
  --set modelProvider=openai \
  --set openai.apiKey=sk-your-key \
  --set openai.model=gpt-4-turbo-preview

# Test
kubectl port-forward -n sha-dev svc/ai-agent 8000:8000
curl http://localhost:8000/model
```

---

## 🔄 Switch Models

```bash
# Ollama → OpenAI
helm upgrade ai-agent ./helm/ai-agent -n sha-dev \
  --reuse-values \
  --set modelProvider=openai \
  --set openai.apiKey=sk-key

# OpenAI → Ollama
helm upgrade ai-agent ./helm/ai-agent -n sha-dev \
  --reuse-values \
  --set modelProvider=ollama

# Restart
kubectl rollout restart deployment/ai-agent -n sha-dev
```

---

## 📊 Quick Comparison

| | Ollama | OpenAI |
|---|---|---|
| **Cost** | $0 | ~$10-30/mo |
| **Setup** | 10 min | 2 min |
| **Speed** | 10-15s | 5-8s |
| **Quality** | 85-90% | 95%+ |
| **Privacy** | 100% | Cloud |

---

## 🔍 Verify Setup

```bash
# Check model info
curl http://localhost:8000/model

# Score a post
curl -X POST http://localhost:8000/score \
  -H "Content-Type: application/json" \
  -d '{"post_id": 1}'

# View results
curl http://localhost:8000/scores/1
```

---

## 📝 Files Created

- [app/ai-agent/main_dual_model.py](../app/ai-agent/main_dual_model.py) - Dual model agent code
- [app/ai-agent/requirements_dual_model.txt](../app/ai-agent/requirements_dual_model.txt) - Dependencies
- [helm/ollama/](../helm/ollama/) - Ollama Helm chart
- [docs/DUAL_MODEL_AI_AGENT.md](DUAL_MODEL_AI_AGENT.md) - Full documentation

---

## 💡 Recommendations

**Development:** Use Ollama (free)
**Production:** Use OpenAI (better quality)
**High Volume:** Use Ollama (save costs)

---

**Full docs:** [DUAL_MODEL_AI_AGENT.md](DUAL_MODEL_AI_AGENT.md)

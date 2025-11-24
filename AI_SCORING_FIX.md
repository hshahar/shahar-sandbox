# AI Scoring Issue - Fixed

## Problem
Auto-scoring was not being created after blog posts were created.

## Root Cause
The issue was caused by **Network Policies** blocking communication between the backend and the AI agent.

### Details:
1. The backend network policy allowed egress to:
   - DNS (port 53)
   - PostgreSQL (port 5432)
   - External HTTPS/HTTP (ports 443/80)
   
2. **But it did NOT allow egress to the AI agent on port 8000**

3. Additionally, there was **no network policy for the AI agent** to allow:
   - Ingress from the backend
   - Egress to PostgreSQL (to fetch blog posts)
   - Egress to external APIs (for OpenAI/Ollama)

## Solution Applied

### 1. Created AI Agent Network Policy
Created a new network policy for the AI agent that allows:
- **Ingress**: From backend pods on port 8000
- **Egress**: 
  - To DNS (port 53)
  - To PostgreSQL (port 5432) 
  - To external APIs (ports 443/80) for OpenAI/Ollama

### 2. Updated Backend Network Policy
Added egress rule to allow backend to communicate with AI agent on port 8000.

### 3. Updated Helm Template
Updated `helm/microservices-app/templates/networkpolicy.yaml` to include:
- AI agent egress rule in backend network policy
- Complete AI agent network policy section

## Commands Used to Fix

```bash
# 1. Created AI agent network policy
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: sha-blog-dev-sha-microservices-app-ai-agent
  namespace: sha-dev
spec:
  podSelector:
    matchLabels:
      app: ai-agent
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 8000
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
  - to:
    - podSelector:
        matchLabels:
          app: postgresql
    ports:
    - protocol: TCP
      port: 5432
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 80
EOF

# 2. Patched backend network policy
kubectl patch networkpolicy -n sha-dev sha-blog-dev-sha-microservices-app-backend --type=json -p='[{"op": "add", "path": "/spec/egress/-", "value": {"to": [{"podSelector": {"matchLabels": {"app": "ai-agent"}}}], "ports": [{"protocol": "TCP", "port": 8000}]}}]'
```

## Verification

```bash
# Check network policies
kubectl get networkpolicy -n sha-dev

# Should show:
# - sha-blog-dev-sha-microservices-app-ai-agent (NEW)
# - sha-blog-dev-sha-microservices-app-backend (UPDATED)

# Test AI agent health
kubectl run test-curl --image=curlimages/curl:latest --rm -it --restart=Never -n sha-dev -- curl -s http://ai-agent:8000/health

# Should return: {"status":"healthy"}
```

## Testing Auto-Scoring

To test that auto-scoring now works:

1. Access the blog frontend
2. Create a new blog post
3. Watch the backend logs for AI scoring activity:
   ```bash
   kubectl logs -n sha-dev -l app=backend -f | Select-String "AI|scoring"
   ```
4. Watch the AI agent logs for scoring requests:
   ```bash
   kubectl logs -n sha-dev -l app=ai-agent -f
   ```
5. The post should show "🤖 Scoring..." initially, then display a score badge within 5-15 seconds

## Files Modified

1. `helm/microservices-app/templates/networkpolicy.yaml`
   - Added AI agent egress rule to backend network policy (line ~153)
   - Added complete AI agent network policy section (line ~195)

## Next Steps

When deploying to other environments (staging, production), ensure:
1. The updated Helm chart is used
2. Network policies are enabled (`networkPolicy.enabled: true`)
3. AI agent is enabled (`aiAgent.enabled: true`)

## Related Configuration

The backend is configured with:
- `AI_AGENT_URL`: `http://ai-agent:8000`
- `AI_SCORING_ENABLED`: `true`

These are set in `helm/microservices-app/templates/backend-deployment.yaml` when `backend.aiAgent.enabled: true`.


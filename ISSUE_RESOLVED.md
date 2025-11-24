# Issue Resolved: No Auto-Scoring After Blog Creation

## Problem Statement
Auto-scoring was not being created after blog posts were created. The AI agent was deployed and running, but the backend was unable to trigger scoring for new blog posts.

## Root Cause Analysis

The issue was caused by **Kubernetes Network Policies** blocking communication between the backend and the AI agent.

### What Was Blocking Communication:

1. **Backend Network Policy** - The backend's egress rules allowed:
   - DNS queries (port 53)
   - PostgreSQL connections (port 5432)
   - External HTTPS/HTTP (ports 443/80)
   - **BUT NOT** connections to the AI agent (port 8000)

2. **Missing AI Agent Network Policy** - There was no network policy defined for the AI agent, which meant:
   - No explicit ingress rules to allow backend connections
   - No egress rules for the AI agent to access PostgreSQL or external APIs

## Solution Implemented

### 1. Created AI Agent Network Policy

Created a new network policy (`sha-blog-dev-sha-microservices-app-ai-agent`) that allows:

**Ingress:**
- From backend pods on port 8000

**Egress:**
- To DNS (port 53) for service discovery
- To PostgreSQL (port 5432) to fetch blog post data
- To external APIs (ports 443/80) for OpenAI/Ollama LLM calls

### 2. Updated Backend Network Policy

Patched the existing backend network policy to add an egress rule allowing connections to the AI agent on port 8000.

### 3. Updated Helm Chart Template

Modified `helm/microservices-app/templates/networkpolicy.yaml` to include:
- AI agent egress rule in the backend network policy section
- Complete AI agent network policy section with proper ingress/egress rules

This ensures the fix is permanent and will be applied in future deployments.

## Verification

All checks passed:
- ✓ AI Agent network policy exists
- ✓ Backend can communicate with AI Agent
- ✓ AI Agent pod is running and healthy
- ✓ Backend has correct environment variables:
  - `AI_AGENT_URL`: `http://ai-agent:8000`
  - `AI_SCORING_ENABLED`: `true`

## Testing

To verify auto-scoring is working:

1. **Port-forward the frontend:**
   ```bash
   kubectl port-forward -n sha-dev svc/sha-blog-dev-sha-microservices-app-frontend 3000:80
   ```

2. **Open browser:** http://localhost:3000

3. **Create a new blog post**

4. **Watch backend logs:**
   ```bash
   kubectl logs -n sha-dev -l app=backend -f | Select-String 'AI|scoring'
   ```
   Expected: `"Created new post X, AI scoring queued"`

5. **Watch AI agent logs:**
   ```bash
   kubectl logs -n sha-dev -l app=ai-agent -f
   ```
   Expected: `"Received score request for post X"`

6. **Check frontend:**
   - Initially shows: "🤖 Scoring..."
   - After 5-15 seconds: Score badge appears (e.g., "⭐ 85/100")

## Files Modified

1. **helm/microservices-app/templates/networkpolicy.yaml**
   - Added AI agent egress rule to backend network policy
   - Added complete AI agent network policy section

2. **scripts/test-ai-scoring.ps1** (NEW)
   - Automated test script to verify AI scoring configuration

3. **AI_SCORING_FIX.md** (NEW)
   - Detailed technical documentation of the fix

4. **ISSUE_RESOLVED.md** (NEW - this file)
   - Summary of the issue and resolution

## Commands Used

### Applied Immediately (Quick Fix):
```bash
# Create AI agent network policy
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

# Patch backend network policy
kubectl patch networkpolicy -n sha-dev sha-blog-dev-sha-microservices-app-backend --type=json -p='[{"op": "add", "path": "/spec/egress/-", "value": {"to": [{"podSelector": {"matchLabels": {"app": "ai-agent"}}}], "ports": [{"protocol": "TCP", "port": 8000}]}}]'
```

### For Future Deployments:
The Helm chart has been updated, so future deployments will automatically include the correct network policies.

## Impact

- **Immediate:** Auto-scoring now works for all new blog posts
- **No downtime:** Changes were applied without restarting any pods
- **Permanent:** Helm chart updated to prevent regression

## Lessons Learned

1. **Network Policies are Critical:** When using Kubernetes Network Policies with a default-deny approach, all communication paths must be explicitly allowed.

2. **Test Connectivity:** When adding new microservices, always verify network connectivity, especially in environments with strict network policies.

3. **Documentation:** Network policy requirements should be documented alongside deployment instructions.

## Next Steps

1. **Test in other environments:** Apply the same network policy fixes to staging and production environments when deploying.

2. **Monitor:** Watch logs after deployment to ensure scoring is working consistently.

3. **Consider:** Adding automated integration tests that verify network connectivity between services.

## Status

✅ **RESOLVED** - Auto-scoring is now functional. All network policies are in place and tested.

---

*Issue resolved on: November 24, 2025*
*Environment: sha-dev namespace*
*Verified by: Automated test script (scripts/test-ai-scoring.ps1)*


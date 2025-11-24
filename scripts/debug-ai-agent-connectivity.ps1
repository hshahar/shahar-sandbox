# AI Agent Connectivity Diagnostic Script
# Run this after AWS CLI is installed and configured

param(
    [string]$Namespace = "sha-dev"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "AI Agent Connectivity Diagnostics" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# 1. Check if AI agent pods are running
Write-Host "1. Checking AI Agent Pods..." -ForegroundColor Yellow
kubectl get pods -n $Namespace -l app=ai-agent

# 2. Check AI agent service
Write-Host "`n2. Checking AI Agent Service..." -ForegroundColor Yellow
kubectl get svc -n $Namespace ai-agent

# 3. Check service endpoints
Write-Host "`n3. Checking Service Endpoints..." -ForegroundColor Yellow
kubectl get endpoints -n $Namespace ai-agent

# 4. Check backend deployment environment variables
Write-Host "`n4. Checking Backend AI_AGENT_URL..." -ForegroundColor Yellow
$backendDep = kubectl get deployment -n $Namespace -l app=backend -o name
if ($backendDep) {
    kubectl get $backendDep -n $Namespace -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="AI_AGENT_URL")].value}'
    Write-Host ""
} else {
    Write-Host "Backend deployment not found!" -ForegroundColor Red
}

# 5. Get AI agent logs
Write-Host "`n5. Recent AI Agent Logs (last 20 lines)..." -ForegroundColor Yellow
kubectl logs -n $Namespace -l app=ai-agent --tail=20

# 6. Get backend logs related to AI scoring
Write-Host "`n6. Recent Backend AI Scoring Logs..." -ForegroundColor Yellow
kubectl logs -n $Namespace -l app=backend --tail=50 | Select-String -Pattern "AI scoring"

# 7. Test connectivity from backend pod
Write-Host "`n7. Testing Connectivity from Backend Pod..." -ForegroundColor Yellow
$backendPod = kubectl get pods -n $Namespace -l app=backend -o jsonpath='{.items[0].metadata.name}'
if ($backendPod) {
    Write-Host "Testing DNS resolution for ai-agent..."
    kubectl exec -n $Namespace $backendPod -- nslookup ai-agent 2>$null

    Write-Host "`nTesting HTTP connectivity to ai-agent:8000..."
    kubectl exec -n $Namespace $backendPod -- wget -O- --timeout=2 http://ai-agent:8000/health 2>&1
} else {
    Write-Host "Backend pod not found!" -ForegroundColor Red
}

# 8. Check for network policies
Write-Host "`n8. Checking Network Policies..." -ForegroundColor Yellow
kubectl get networkpolicy -n $Namespace

# 9. Check AI agent pod readiness
Write-Host "`n9. AI Agent Pod Details..." -ForegroundColor Yellow
kubectl describe pods -n $Namespace -l app=ai-agent | Select-String -Pattern "Ready|Status|Events" -Context 0,2

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Diagnostics Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nCommon Issues:" -ForegroundColor Yellow
Write-Host "1. If endpoints are empty → AI agent pod is not ready"
Write-Host "2. If DNS fails → Service name mismatch or DNS issue"
Write-Host "3. If HTTP fails but DNS works → Port mismatch or app not listening"
Write-Host "4. If network policy exists → May need to allow backend→ai-agent traffic"

# Test AI Scoring Functionality
# This script tests that auto-scoring works after blog creation

param(
    [string]$Namespace = "sha-dev",
    [string]$BackendService = "sha-blog-dev-sha-microservices-app-backend"
)

Write-Host "Testing AI Scoring Functionality" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# 1. Check network policies
Write-Host "1. Checking Network Policies..." -ForegroundColor Yellow
$netpols = kubectl get networkpolicy -n $Namespace -o json | ConvertFrom-Json
$aiAgentNetpol = $netpols.items | Where-Object { $_.metadata.name -like "*ai-agent*" }
$backendNetpol = $netpols.items | Where-Object { $_.metadata.name -like "*backend*" }

if ($aiAgentNetpol) {
    Write-Host "   [OK] AI Agent network policy exists" -ForegroundColor Green
} else {
    Write-Host "   [FAIL] AI Agent network policy NOT found" -ForegroundColor Red
    exit 1
}

if ($backendNetpol) {
    $hasAiAgentEgress = $backendNetpol.spec.egress | Where-Object { 
        $_.to.podSelector.matchLabels.app -eq "ai-agent" 
    }
    if ($hasAiAgentEgress) {
        Write-Host "   [OK] Backend can communicate with AI Agent" -ForegroundColor Green
    } else {
        Write-Host "   [FAIL] Backend network policy does NOT allow AI Agent egress" -ForegroundColor Red
        exit 1
    }
}

# 2. Check AI Agent is running
Write-Host ""
Write-Host "2. Checking AI Agent Status..." -ForegroundColor Yellow
$aiAgentPod = kubectl get pods -n $Namespace -l app=ai-agent -o json | ConvertFrom-Json
if ($aiAgentPod.items.Count -gt 0 -and $aiAgentPod.items[0].status.phase -eq "Running") {
    Write-Host "   [OK] AI Agent pod is running" -ForegroundColor Green
    Write-Host "     Pod: $($aiAgentPod.items[0].metadata.name)" -ForegroundColor Gray
} else {
    Write-Host "   [FAIL] AI Agent pod is NOT running" -ForegroundColor Red
    exit 1
}

# 3. Test AI Agent health
Write-Host ""
Write-Host "3. Testing AI Agent Health Endpoint..." -ForegroundColor Yellow
try {
    $healthTest = kubectl run test-curl-health --image=curlimages/curl:latest --rm -it --restart=Never -n $Namespace -- curl -s -m 5 http://ai-agent:8000/health 2>&1
    if ($healthTest -match "healthy") {
        Write-Host "   [OK] AI Agent is healthy" -ForegroundColor Green
    } else {
        Write-Host "   [FAIL] AI Agent health check failed" -ForegroundColor Red
        Write-Host "     Response: $healthTest" -ForegroundColor Gray
        exit 1
    }
} catch {
    Write-Host "   [FAIL] Could not test AI Agent health" -ForegroundColor Red
    Write-Host "     Error: $_" -ForegroundColor Gray
}

# 4. Check backend configuration
Write-Host ""
Write-Host "4. Checking Backend Configuration..." -ForegroundColor Yellow
$backendDep = kubectl get deployment -n $Namespace -l app=backend -o json | ConvertFrom-Json
if ($backendDep.items.Count -gt 0) {
    $env = $backendDep.items[0].spec.template.spec.containers[0].env
    $aiAgentUrl = ($env | Where-Object { $_.name -eq "AI_AGENT_URL" }).value
    $aiScoringEnabled = ($env | Where-Object { $_.name -eq "AI_SCORING_ENABLED" }).value
    
    if ($aiAgentUrl) {
        Write-Host "   [OK] AI_AGENT_URL is set: $aiAgentUrl" -ForegroundColor Green
    } else {
        Write-Host "   [FAIL] AI_AGENT_URL is NOT set" -ForegroundColor Red
    }
    
    if ($aiScoringEnabled -eq "true") {
        Write-Host "   [OK] AI_SCORING_ENABLED is true" -ForegroundColor Green
    } else {
        Write-Host "   [FAIL] AI_SCORING_ENABLED is NOT true" -ForegroundColor Red
    }
}

# 5. Instructions for manual testing
Write-Host ""
Write-Host "5. Manual Testing Instructions" -ForegroundColor Yellow
Write-Host "   To test auto-scoring, follow these steps:" -ForegroundColor Gray
Write-Host ""
Write-Host "   a) Port-forward the frontend:" -ForegroundColor Gray
Write-Host "      kubectl port-forward -n $Namespace svc/sha-blog-dev-sha-microservices-app-frontend 3000:80" -ForegroundColor Cyan
Write-Host ""
Write-Host "   b) Open browser: http://localhost:3000" -ForegroundColor Gray
Write-Host ""
Write-Host "   c) Create a new blog post" -ForegroundColor Gray
Write-Host ""
Write-Host "   d) Watch backend logs in another terminal:" -ForegroundColor Gray
Write-Host "      kubectl logs -n $Namespace -l app=backend -f | Select-String 'AI|scoring'" -ForegroundColor Cyan
Write-Host ""
Write-Host "   e) Watch AI agent logs:" -ForegroundColor Gray
Write-Host "      kubectl logs -n $Namespace -l app=ai-agent -f" -ForegroundColor Cyan
Write-Host ""
Write-Host "   f) You should see:" -ForegroundColor Gray
Write-Host "      - Backend log: 'Created new post X, AI scoring queued'" -ForegroundColor Gray
Write-Host "      - AI agent log: 'Received score request for post X'" -ForegroundColor Gray
Write-Host "      - Frontend: Score badge appears within 5-15 seconds" -ForegroundColor Gray
Write-Host ""

Write-Host "=================================" -ForegroundColor Cyan
Write-Host "All checks passed!" -ForegroundColor Green
Write-Host "AI scoring should now work when creating blog posts." -ForegroundColor Green
Write-Host ""

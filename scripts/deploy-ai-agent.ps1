# Deploy AI Agent - Fix Automatic Scoring
# This script enables and deploys the AI agent for automatic post scoring

param(
    [string]$Namespace = "sha-dev",
    [string]$OpenAIKey = "",
    [switch]$UseOllama = $false
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "AI Agent Deployment Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if kubectl is working
Write-Host "1. Checking Kubernetes connection..." -ForegroundColor Yellow
try {
    kubectl cluster-info 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   Connected to Kubernetes cluster" -ForegroundColor Green
    } else {
        Write-Host "   Cannot connect to Kubernetes" -ForegroundColor Red
        Write-Host "   Run: aws eks update-kubeconfig --region us-west-2 --name sha-blog-eks" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "   Cannot connect to Kubernetes" -ForegroundColor Red
    Write-Host "   Run: aws eks update-kubeconfig --region us-west-2 --name sha-blog-eks" -ForegroundColor Yellow
    exit 1
}

# Determine model provider
$modelProvider = ""
$extraArgs = ""

if ($UseOllama) {
    Write-Host ""
    Write-Host "2. Using Ollama (FREE local model)..." -ForegroundColor Yellow
    Write-Host "   First, deploy Ollama:" -ForegroundColor Cyan
    Write-Host "   helm install ollama ./helm/ollama --namespace $Namespace" -ForegroundColor White

    $modelProvider = "ollama"
    $extraArgs = "--set aiAgent.modelProvider=ollama"
} else {
    Write-Host ""
    Write-Host "2. Using OpenAI (Premium)..." -ForegroundColor Yellow

    if ($OpenAIKey -eq "") {
        Write-Host "   No OpenAI API key provided!" -ForegroundColor Red
        $OpenAIKey = Read-Host "   Enter your OpenAI API key (starts with sk-)"

        if ($OpenAIKey -eq "") {
            Write-Host "   API key required for OpenAI model" -ForegroundColor Red
            Write-Host "   Run with -UseOllama to use free local model instead" -ForegroundColor Yellow
            exit 1
        }
    }

    $modelProvider = "openai"
    $extraArgs = "--set aiAgent.modelProvider=openai --set aiAgent.openai.apiKey=$OpenAIKey"
}

# Deploy or upgrade the application with AI agent enabled
Write-Host ""
Write-Host "3. Deploying application with AI Agent enabled..." -ForegroundColor Yellow

$helmCommand = "helm upgrade --install sha-blog ./helm/microservices-app --namespace $Namespace --create-namespace --values ./helm/microservices-app/values-dev.yaml --set aiAgent.enabled=true --set backend.aiAgent.enabled=true $extraArgs"

Write-Host "   Running deployment..." -ForegroundColor Gray

Invoke-Expression $helmCommand

if ($LASTEXITCODE -eq 0) {
    Write-Host "   Deployment successful!" -ForegroundColor Green
} else {
    Write-Host "   Deployment failed!" -ForegroundColor Red
    exit 1
}

# Wait for pods to be ready
Write-Host ""
Write-Host "4. Waiting for AI agent pod to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=ai-agent -n $Namespace --timeout=300s 2>&1 | Out-Null

Write-Host ""
Write-Host "5. Checking deployment status..." -ForegroundColor Yellow
Write-Host "   AI Agent Pods:" -ForegroundColor Cyan
kubectl get pods -n $Namespace -l app=ai-agent

Write-Host ""
Write-Host "   Backend Pods:" -ForegroundColor Cyan
kubectl get pods -n $Namespace -l app=backend

Write-Host ""
Write-Host "   AI Agent Service:" -ForegroundColor Cyan
kubectl get svc -n $Namespace ai-agent

# Test connectivity
Write-Host ""
Write-Host "6. Testing AI agent connectivity..." -ForegroundColor Yellow
$backendPod = kubectl get pods -n $Namespace -l app=backend -o jsonpath='{.items[0].metadata.name}' 2>$null

if ($backendPod) {
    Write-Host "   Testing from backend pod: $backendPod" -ForegroundColor Gray
    kubectl exec -n $Namespace $backendPod -- wget -O- --timeout=2 http://ai-agent:8000/health 2>&1 | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "   Backend can reach AI agent!" -ForegroundColor Green
    } else {
        Write-Host "   Backend cannot reach AI agent" -ForegroundColor Red
        Write-Host "   Check network policies and pod readiness" -ForegroundColor Yellow
    }
} else {
    Write-Host "   Backend pod not found yet, skipping connectivity test" -ForegroundColor Yellow
}

# View AI agent logs
Write-Host ""
Write-Host "7. Recent AI Agent logs:" -ForegroundColor Yellow
kubectl logs -n $Namespace -l app=ai-agent --tail=10 2>$null

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Create a blog post to test automatic scoring" -ForegroundColor White
Write-Host "2. Check backend logs: kubectl logs -n $Namespace -l app=backend -f | Select-String 'AI scoring'" -ForegroundColor White
Write-Host "3. Check AI agent logs: kubectl logs -n $Namespace -l app=ai-agent -f" -ForegroundColor White
Write-Host "4. Access your blog and create a post - score badge appears within 5-15 seconds" -ForegroundColor White

Write-Host ""
if ($modelProvider -eq "openai") {
    Write-Host "Using OpenAI costs approximately 0.01-0.02 dollars per post scored" -ForegroundColor Cyan
} else {
    Write-Host "Using Ollama (FREE) - scores take 10-15 seconds" -ForegroundColor Cyan
}

# Deploy Real-Time AI Scoring
# Quick deployment script for the AI scoring system

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("ollama", "openai")]
    [string]$ModelProvider = "ollama",

    [Parameter(Mandatory=$false)]
    [string]$OpenAIKey = "",

    [Parameter(Mandatory=$false)]
    [string]$Namespace = "sha-dev",

    [Parameter(Mandatory=$false)]
    [switch]$SkipMigration
)

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     Real-Time AI Scoring Deployment                       ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Step 1: Database Migration
if (-not $SkipMigration) {
    Write-Host "📊 Step 1: Applying database migration..." -ForegroundColor Yellow

    $postgresqlPod = kubectl get pods -n $Namespace -l app=postgresql -o jsonpath='{.items[0].metadata.name}' 2>$null

    if ($postgresqlPod) {
        Write-Host "   Found PostgreSQL pod: $postgresqlPod" -ForegroundColor Green

        kubectl exec -i -n $Namespace $postgresqlPod -- `
            psql -U app_user -d sha_blog_dev < app/ai-agent/db_migration.sql

        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✅ Database migration applied successfully" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  Migration may have already been applied (this is OK)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ⚠️  PostgreSQL pod not found, skipping migration" -ForegroundColor Yellow
        Write-Host "      Run migration manually after deployment" -ForegroundColor Yellow
    }
    Write-Host ""
}

# Step 2: Deploy Ollama (if needed)
if ($ModelProvider -eq "ollama") {
    Write-Host "🤖 Step 2: Deploying Ollama (local LLM)..." -ForegroundColor Yellow

    # Check if Ollama is already deployed
    $ollamaDeployment = kubectl get deployment -n $Namespace ollama 2>$null

    if ($ollamaDeployment) {
        Write-Host "   ℹ️  Ollama already deployed, skipping..." -ForegroundColor Blue
    } else {
        Write-Host "   Installing Ollama with Llama3 model..." -ForegroundColor Cyan

        helm install ollama ./helm/ollama `
            --namespace $Namespace `
            --set models="{llama3,mistral}" `
            --wait --timeout 15m

        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✅ Ollama deployed successfully" -ForegroundColor Green
        } else {
            Write-Host "   ❌ Failed to deploy Ollama" -ForegroundColor Red
            exit 1
        }
    }
    Write-Host ""
} else {
    Write-Host "🌐 Step 2: Using OpenAI (cloud LLM)..." -ForegroundColor Yellow

    if ([string]::IsNullOrEmpty($OpenAIKey)) {
        Write-Host "   ❌ Error: OpenAI API key required for OpenAI provider" -ForegroundColor Red
        Write-Host "      Usage: .\deploy-ai-scoring.ps1 -ModelProvider openai -OpenAIKey sk-your-key" -ForegroundColor Yellow
        exit 1
    }

    Write-Host "   ✅ OpenAI key provided" -ForegroundColor Green
    Write-Host ""
}

# Step 3: Deploy Application
Write-Host "🚀 Step 3: Deploying application with AI agent..." -ForegroundColor Yellow

$helmArgs = @(
    "upgrade", "--install", "sha-blog",
    "./helm/microservices-app",
    "--namespace", $Namespace,
    "--values", "helm/microservices-app/values-dev.yaml",
    "--set", "aiAgent.enabled=true",
    "--set", "backend.aiAgent.enabled=true",
    "--set", "aiAgent.modelProvider=$ModelProvider"
)

if ($ModelProvider -eq "ollama") {
    $helmArgs += "--set", "aiAgent.ollama.baseUrl=http://ollama:11434"
    $helmArgs += "--set", "aiAgent.ollama.model=llama3"
} else {
    $helmArgs += "--set", "aiAgent.openai.apiKey=$OpenAIKey"
    $helmArgs += "--set", "aiAgent.openai.model=gpt-4-turbo-preview"
}

Write-Host "   Executing: helm $($helmArgs -join ' ')" -ForegroundColor Cyan
helm @helmArgs

if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✅ Application deployed successfully" -ForegroundColor Green
} else {
    Write-Host "   ❌ Failed to deploy application" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Step 4: Verify Deployment
Write-Host "🔍 Step 4: Verifying deployment..." -ForegroundColor Yellow

Write-Host "   Waiting for pods to be ready..." -ForegroundColor Cyan
Start-Sleep -Seconds 5

$pods = kubectl get pods -n $Namespace -o json | ConvertFrom-Json

Write-Host ""
Write-Host "   Pod Status:" -ForegroundColor Cyan
foreach ($pod in $pods.items) {
    $name = $pod.metadata.name
    $status = $pod.status.phase
    $ready = ($pod.status.containerStatuses | Where-Object { $_.ready -eq $true }).Count
    $total = $pod.status.containerStatuses.Count

    if ($status -eq "Running" -and $ready -eq $total) {
        Write-Host "   ✅ $name - Running ($ready/$total)" -ForegroundColor Green
    } elseif ($status -eq "Pending") {
        Write-Host "   ⏳ $name - Pending..." -ForegroundColor Yellow
    } else {
        Write-Host "   ⚠️  $name - $status ($ready/$total)" -ForegroundColor Yellow
    }
}
Write-Host ""

# Step 5: Display Access Information
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║     ✅ Deployment Complete!                                ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

Write-Host "📋 Next Steps:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Port-forward the frontend:" -ForegroundColor White
Write-Host "   kubectl port-forward -n $Namespace svc/sha-blog-frontend 3000:80" -ForegroundColor Yellow
Write-Host ""
Write-Host "2. Open in browser:" -ForegroundColor White
Write-Host "   http://localhost:3000" -ForegroundColor Yellow
Write-Host ""
Write-Host "3. Create a test post and watch for:" -ForegroundColor White
Write-Host "   - '🤖 Scoring...' status" -ForegroundColor Yellow
Write-Host "   - Score badge appears in 5-15 seconds" -ForegroundColor Yellow
Write-Host ""

Write-Host "📊 Monitoring:" -ForegroundColor Cyan
Write-Host ""
Write-Host "View AI agent logs:" -ForegroundColor White
Write-Host "   kubectl logs -n $Namespace -l app=ai-agent -f" -ForegroundColor Yellow
Write-Host ""
Write-Host "View backend logs:" -ForegroundColor White
Write-Host "   kubectl logs -n $Namespace -l app=backend -f | grep `"AI scoring`"" -ForegroundColor Yellow
Write-Host ""

Write-Host "🎯 Model Configuration:" -ForegroundColor Cyan
if ($ModelProvider -eq "ollama") {
    Write-Host "   Provider: Ollama (FREE, local)" -ForegroundColor Green
    Write-Host "   Model: Llama3" -ForegroundColor Green
    Write-Host "   Cost: $0/month" -ForegroundColor Green
} else {
    Write-Host "   Provider: OpenAI (cloud)" -ForegroundColor Blue
    Write-Host "   Model: GPT-4 Turbo" -ForegroundColor Blue
    Write-Host "   Cost: ~$10-30/month (1000 posts)" -ForegroundColor Blue
}
Write-Host ""

Write-Host "📚 Documentation:" -ForegroundColor Cyan
Write-Host "   Full Guide: docs/REALTIME_AI_SCORING.md" -ForegroundColor Yellow
Write-Host "   Summary: REALTIME_AI_IMPLEMENTATION_SUMMARY.md" -ForegroundColor Yellow
Write-Host ""

Write-Host "Happy scoring! 🚀" -ForegroundColor Magenta

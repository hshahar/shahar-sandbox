# Test Auto-Scoring by Creating a Post Through the API

Write-Host "=== Testing Auto-Scoring ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Port-forward backend
Write-Host "Step 1: Setting up port-forward..." -ForegroundColor Yellow
$job = Start-Job -ScriptBlock { kubectl port-forward -n sha-dev svc/sha-blog-dev-sha-microservices-app-backend 8000:8000 }
Start-Sleep -Seconds 8

# Step 2: Test connectivity
Write-Host "Step 2: Testing backend connectivity..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "http://localhost:8000/health" -TimeoutSec 5
    Write-Host "  Backend is healthy!" -ForegroundColor Green
} catch {
    Write-Host "  Backend not responding. Make sure port-forward is running." -ForegroundColor Red
    Get-Job | Stop-Job
    Get-Job | Remove-Job
    exit 1
}

# Step 3: Create post
Write-Host ""
Write-Host "Step 3: Creating test post..." -ForegroundColor Yellow

$postJson = @'
{
    "title": "Auto-Scoring Test Post",
    "content": "This post tests the auto-scoring system after network policy fixes. Kubernetes provides powerful container orchestration with features like automated deployment, scaling, and management of containerized applications.",
    "category": "Kubernetes Features",
    "author": "SHA",
    "tags": "testing, ai-scoring, kubernetes"
}
'@

try {
    $response = Invoke-RestMethod -Uri "http://localhost:8000/api/posts" -Method POST -Body $postJson -ContentType "application/json" -TimeoutSec 10
    
    Write-Host ""
    Write-Host "SUCCESS! Post created:" -ForegroundColor Green
    Write-Host "  Post ID: $($response.id)" -ForegroundColor Cyan
    Write-Host "  Title: $($response.title)" -ForegroundColor Cyan
    Write-Host "  Initial Score: $($response.ai_score)" -ForegroundColor Yellow
    
    $postId = $response.id
    
    # Step 4: Monitor logs
    Write-Host ""
    Write-Host "Step 4: Checking backend logs for scoring trigger..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    $backendLogs = kubectl logs -n sha-dev -l app=backend --tail=20 | Select-String "Created new post|AI scoring"
    if ($backendLogs) {
        Write-Host "  Backend logs:" -ForegroundColor Green
        $backendLogs | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
    } else {
        Write-Host "  No scoring trigger found in logs" -ForegroundColor Yellow
    }
    
    # Step 5: Wait for scoring
    Write-Host ""
    Write-Host "Step 5: Waiting 15 seconds for AI scoring..." -ForegroundColor Yellow
    for ($i = 15; $i -gt 0; $i--) {
        Write-Host "  $i..." -NoNewline
        Start-Sleep -Seconds 1
    }
    Write-Host ""
    
    # Step 6: Check score
    Write-Host ""
    Write-Host "Step 6: Checking if post received a score..." -ForegroundColor Yellow
    $result = kubectl exec -n sha-dev sha-blog-dev-sha-microservices-app-postgresql-0 -- psql -U devuser -d sha_blog_dev -c "SELECT id, title, ai_score, last_scored_at FROM blog_posts WHERE id = $postId;"
    Write-Host $result
    
    # Step 7: Check AI agent logs
    Write-Host ""
    Write-Host "Step 7: Checking AI agent logs..." -ForegroundColor Yellow
    $aiLogs = kubectl logs -n sha-dev -l app=ai-agent --tail=30 | Select-String "score|post|$postId"
    if ($aiLogs) {
        Write-Host "  AI agent activity:" -ForegroundColor Green
        $aiLogs | Select-Object -Last 5 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
    } else {
        Write-Host "  No scoring activity found in AI agent logs" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host ""
    Write-Host "ERROR: $_" -ForegroundColor Red
}

# Cleanup
Write-Host ""
Write-Host "Cleaning up..." -ForegroundColor Gray
Get-Job | Stop-Job
Get-Job | Remove-Job

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Cyan


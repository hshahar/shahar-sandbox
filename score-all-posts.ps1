# Score All Unscored Posts Manually

Write-Host "=== Scoring All Unscored Posts ===" -ForegroundColor Cyan
Write-Host ""

# Get all unscored posts
Write-Host "Finding unscored posts..." -ForegroundColor Yellow
$query = "SELECT id FROM blog_posts WHERE ai_score IS NULL ORDER BY id;"
$result = kubectl exec -n sha-dev sha-blog-dev-sha-microservices-app-postgresql-0 -- psql -U devuser -d sha_blog_dev -t -c $query 2>&1

$postIds = @()
$result -split "`n" | ForEach-Object {
    if ($_ -match '^\s*(\d+)\s*$') {
        $postIds += $matches[1].Trim()
    }
}

if ($postIds.Count -eq 0) {
    Write-Host "No unscored posts found!" -ForegroundColor Green
    exit 0
}

Write-Host "Found $($postIds.Count) unscored posts: $($postIds -join ', ')" -ForegroundColor Cyan
Write-Host ""

# Port-forward AI agent
Write-Host "Setting up port-forward to AI agent..." -ForegroundColor Yellow
Start-Process powershell -WindowStyle Hidden -ArgumentList "-Command", "kubectl port-forward -n sha-dev svc/ai-agent 8001:8000"
Start-Sleep -Seconds 10

# Test connection
$connected = $false
for ($i = 0; $i -lt 5; $i++) {
    try {
        $health = Invoke-RestMethod -Uri "http://localhost:8001/health" -TimeoutSec 3 -ErrorAction Stop
        Write-Host "  AI agent connected!" -ForegroundColor Green
        $connected = $true
        break
    } catch {
        Write-Host "  Retry $($i+1)/5..." -ForegroundColor Gray
        Start-Sleep -Seconds 3
    }
}

if (-not $connected) {
    Write-Host "Could not connect to AI agent" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Score each post
$successCount = 0
$failCount = 0

foreach ($postId in $postIds) {
    Write-Host "Scoring post $postId..." -ForegroundColor Yellow
    
    try {
        $body = @{ post_id = [int]$postId } | ConvertTo-Json
        $response = Invoke-RestMethod -Uri "http://localhost:8001/score" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 10
        
        Write-Host "  Queued for scoring" -ForegroundColor Green
        $successCount++
        Start-Sleep -Seconds 2
    } catch {
        Write-Host "  Failed: $_" -ForegroundColor Red
        $failCount++
    }
}

Write-Host ""
Write-Host "Scoring queued:" -ForegroundColor Cyan
Write-Host "  Success: $successCount" -ForegroundColor Green
Write-Host "  Failed: $failCount" -ForegroundColor $(if($failCount -gt 0){"Red"}else{"Green"})

Write-Host ""
Write-Host "Waiting 120 seconds for Ollama to process all posts..." -ForegroundColor Yellow
for ($i = 120; $i -gt 0; $i -= 20) {
    Write-Host "  $i seconds remaining..." -ForegroundColor Gray
    Start-Sleep -Seconds 20
}

Write-Host ""
Write-Host "Final Results:" -ForegroundColor Cyan
kubectl exec -n sha-dev sha-blog-dev-sha-microservices-app-postgresql-0 -- psql -U devuser -d sha_blog_dev -c "SELECT id, title, ai_score, CASE WHEN ai_score IS NOT NULL THEN 'SCORED' ELSE 'Not scored' END as status FROM blog_posts ORDER BY id DESC;"

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Cyan
Write-Host "Note: Close the port-forward PowerShell window manually" -ForegroundColor Gray


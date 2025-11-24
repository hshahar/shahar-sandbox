# Final Auto-Scoring Test with Fixed Timeout

Write-Host "=== Final Auto-Scoring Test ===" -ForegroundColor Cyan
Write-Host ""

# Clean up any existing port-forwards
Get-Job | Stop-Job -ErrorAction SilentlyContinue
Get-Job | Remove-Job -ErrorAction SilentlyContinue

# Start port-forward
Write-Host "Starting port-forward..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward -n sha-dev svc/sha-blog-dev-sha-microservices-app-backend 8000:8000"
Start-Sleep -Seconds 15

# Test backend
Write-Host "Testing backend connectivity..." -ForegroundColor Yellow
$retries = 0
$connected = $false
while ($retries -lt 5 -and -not $connected) {
    try {
        $health = Invoke-RestMethod -Uri "http://localhost:8000/health" -TimeoutSec 5 -ErrorAction Stop
        Write-Host "  Backend is ready!" -ForegroundColor Green
        $connected = $true
    } catch {
        $retries++
        Write-Host "  Retry $retries/5..." -ForegroundColor Gray
        Start-Sleep -Seconds 3
    }
}

if (-not $connected) {
    Write-Host "Could not connect to backend" -ForegroundColor Red
    exit 1
}

# Create post
Write-Host ""
Write-Host "Creating test post..." -ForegroundColor Cyan

$json = @'
{
    "title": "Final Auto-Scoring Verification",
    "content": "This post verifies that auto-scoring works with the increased 90-second timeout for Ollama LLM. Kubernetes is a powerful container orchestration platform that provides automated deployment, scaling, and management of containerized applications.",
    "category": "Kubernetes Features",
    "author": "SHA",
    "tags": "testing, ollama, ai-scoring"
}
'@

try {
    $response = Invoke-RestMethod -Uri "http://localhost:8000/api/posts" -Method POST -Body $json -ContentType "application/json" -TimeoutSec 15
    
    Write-Host ""
    Write-Host "SUCCESS! Post created:" -ForegroundColor Green
    Write-Host "  Post ID: $($response.id)" -ForegroundColor Cyan
    Write-Host "  Title: $($response.title)" -ForegroundColor Cyan
    
    $postId = $response.id
    
    # Check backend logs
    Write-Host ""
    Write-Host "Backend logs:" -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    kubectl logs -n sha-dev -l app=backend --tail=15 | Select-String "Created new post|AI scoring" | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    
    # Wait for scoring (Ollama can take 30-90 seconds)
    Write-Host ""
    Write-Host "Waiting for Ollama to complete scoring (this takes 30-90 seconds)..." -ForegroundColor Yellow
    
    for ($i = 90; $i -gt 0; $i -= 15) {
        Write-Host "  Checking in $i seconds..." -ForegroundColor Gray
        Start-Sleep -Seconds 15
        
        # Check if score appeared
        $check = kubectl exec -n sha-dev sha-blog-dev-sha-microservices-app-postgresql-0 -- psql -U devuser -d sha_blog_dev -t -c "SELECT ai_score FROM blog_posts WHERE id = $postId;" 2>&1
        if ($check -match '\d+') {
            Write-Host "  Score detected!" -ForegroundColor Green
            break
        }
    }
    
    # Final check
    Write-Host ""
    Write-Host "Final Result:" -ForegroundColor Cyan
    kubectl exec -n sha-dev sha-blog-dev-sha-microservices-app-postgresql-0 -- psql -U devuser -d sha_blog_dev -c "SELECT id, title, ai_score, last_scored_at FROM blog_posts WHERE id = $postId;"
    
    # Check AI agent logs
    Write-Host ""
    Write-Host "AI Agent logs:" -ForegroundColor Yellow
    kubectl logs -n sha-dev -l app=ai-agent --tail=50 | Select-String "post $postId|score.*$postId|analysis.*$postId" | Select-Object -Last 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    
} catch {
    Write-Host ""
    Write-Host "ERROR: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Cyan
Write-Host "Note: Close the port-forward PowerShell window manually" -ForegroundColor Gray


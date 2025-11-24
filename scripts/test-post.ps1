Write-Host "=== Creating Test Blog Post ===" -ForegroundColor Cyan
$body = @{
    title = "Network Policy Fix Test"
    content = "Testing AI auto-scoring after fixing network policies. Kubernetes provides container orchestration."
    category = "Kubernetes Features"
    author = "SHA"
    tags = "test"
} | ConvertTo-Json

try {
    $post = Invoke-RestMethod -Uri "http://localhost:8000/api/posts" -Method POST -Body $body -ContentType "application/json"
    Write-Host "SUCCESS! Post ID: $($post.id)" -ForegroundColor Green
    
    Write-Host "`nWaiting 10 seconds for AI scoring..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    
    Write-Host "`nFetching post to check score..." -ForegroundColor Cyan
    $updated = Invoke-RestMethod -Uri "http://localhost:8000/api/posts/$($post.id)"
    Write-Host "AI Score: $($updated.ai_score)" -ForegroundColor $(if($updated.ai_score) {"Green"} else {"Yellow"})
    Write-Host "Last Scored: $($updated.last_scored_at)" -ForegroundColor Gray
} catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}

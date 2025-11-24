# Score Posts From Within the Cluster

Write-Host "=== Scoring Posts via Cluster-Internal Request ===" -ForegroundColor Cyan
Write-Host ""

# Get unscored posts
$query = "SELECT id, title FROM blog_posts WHERE ai_score IS NULL ORDER BY id;"
$result = kubectl exec -n sha-dev sha-blog-dev-sha-microservices-app-postgresql-0 -- psql -U devuser -d sha_blog_dev -t -c $query 2>&1

$postIds = @()
$result -split "`n" | ForEach-Object {
    if ($_ -match '^\s*(\d+)') {
        $postIds += $matches[1].Trim()
    }
}

Write-Host "Unscored posts: $($postIds -join ', ')" -ForegroundColor Yellow
Write-Host ""

foreach ($postId in $postIds) {
    Write-Host "Triggering scoring for post $postId..." -ForegroundColor Cyan
    
    # Use kubectl run to make request from inside cluster
    $cmd = "printf '{\"post_id\": $postId}' | curl -s -X POST http://ai-agent:8000/score -H 'Content-Type: application/json' -d @-"
    
    kubectl run score-p$postId --image=curlimages/curl:latest --rm -i --restart=Never -n sha-dev --command -- sh -c $cmd 2>&1 | Out-Null
    
    Write-Host "  Queued" -ForegroundColor Green
    Start-Sleep -Seconds 3
}

Write-Host ""
Write-Host "All posts queued for scoring!" -ForegroundColor Green
Write-Host "Ollama will process them in background (takes 30-90 seconds per post)" -ForegroundColor Yellow
Write-Host ""
Write-Host "Waiting 2 minutes for first scores..." -ForegroundColor Yellow
Start-Sleep -Seconds 120

Write-Host ""
Write-Host "Current Status:" -ForegroundColor Cyan
kubectl exec -n sha-dev sha-blog-dev-sha-microservices-app-postgresql-0 -- psql -U devuser -d sha_blog_dev -c "SELECT id, LEFT(title, 40) as title, ai_score FROM blog_posts ORDER BY id DESC LIMIT 10;"

Write-Host ""
Write-Host "Note: Scoring may still be in progress. Check again in a few minutes." -ForegroundColor Yellow


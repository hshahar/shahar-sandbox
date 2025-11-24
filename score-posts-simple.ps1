# Score All Unscored Posts - Simple Version

Write-Host "=== Scoring All Unscored Posts ===" -ForegroundColor Cyan

# Get unscored post IDs
$postIds = @(10, 19, 20, 21, 22, 23, 24)

Write-Host "Scoring $($postIds.Count) posts: $($postIds -join ', ')" -ForegroundColor Yellow
Write-Host ""

foreach ($id in $postIds) {
    Write-Host "Post $id..." -ForegroundColor Cyan
    
    kubectl run score-post-$id --image=curlimages/curl:latest --rm -i --restart=Never -n sha-dev -- sh -c "echo '{\"post_id\": $id}' | curl -X POST http://ai-agent:8000/score -H 'Content-Type: application/json' -d @-" 2>&1 | Out-Null
    
    Write-Host "  Queued" -ForegroundColor Green
    Start-Sleep -Seconds 2
}

Write-Host ""
Write-Host "All posts queued! Waiting 2 minutes..." -ForegroundColor Yellow
Start-Sleep -Seconds 120

Write-Host ""
kubectl exec -n sha-dev sha-blog-dev-sha-microservices-app-postgresql-0 -- psql -U devuser -d sha_blog_dev -c "SELECT id, LEFT(title, 35) as title, ai_score FROM blog_posts WHERE id IN (10,19,20,21,22,23,24) ORDER BY id;"

Write-Host ""
Write-Host "Done! If scores are still NULL, check AI agent logs:" -ForegroundColor Yellow
Write-Host "kubectl logs -n sha-dev -l app=ai-agent --tail=100" -ForegroundColor Gray


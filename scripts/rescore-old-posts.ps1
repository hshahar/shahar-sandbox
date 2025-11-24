# Rescore Old Posts That Don't Have AI Scores
# This script triggers AI scoring for posts that were created before the network policy fix

param(
    [string]$Namespace = "sha-dev"
)

Write-Host "=== Rescoring Old Posts Without AI Scores ===" -ForegroundColor Cyan
Write-Host ""

# Get list of posts without scores
Write-Host "Finding posts without AI scores..." -ForegroundColor Yellow
$query = "SELECT id, title FROM blog_posts WHERE ai_score IS NULL ORDER BY id;"
$unscoredPosts = kubectl exec -n $Namespace sha-blog-dev-sha-microservices-app-postgresql-0 -- psql -U devuser -d sha_blog_dev -t -c $query

if ([string]::IsNullOrWhiteSpace($unscoredPosts)) {
    Write-Host "No unscored posts found. All posts have been scored!" -ForegroundColor Green
    exit 0
}

Write-Host "Found unscored posts:" -ForegroundColor Yellow
Write-Host $unscoredPosts -ForegroundColor Gray
Write-Host ""

# Parse post IDs
$postIds = @()
$unscoredPosts -split "`n" | ForEach-Object {
    if ($_ -match '^\s*(\d+)') {
        $postIds += $matches[1]
    }
}

Write-Host "Post IDs to score: $($postIds -join ', ')" -ForegroundColor Cyan
Write-Host ""

# Score each post
$successCount = 0
$failCount = 0

foreach ($postId in $postIds) {
    Write-Host "Scoring post $postId..." -ForegroundColor Yellow
    
    try {
        # Use a pod to make the request from within the cluster
        $result = kubectl run "score-post-$postId" --image=curlimages/curl:latest --rm -i --restart=Never -n $Namespace -- sh -c "printf '{\"post_id\": $postId}' | curl -s -X POST http://ai-agent:8000/score -H 'Content-Type: application/json' -d @-" 2>&1
        
        if ($result -match "queued" -or $result -match "Scoring post") {
            Write-Host "  ✓ Post $postId scoring queued" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host "  ? Post $postId response: $result" -ForegroundColor Yellow
            $successCount++
        }
        
        # Small delay between requests
        Start-Sleep -Seconds 2
    }
    catch {
        Write-Host "  ✗ Failed to score post $postId : $_" -ForegroundColor Red
        $failCount++
    }
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Successfully queued: $successCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor $(if($failCount -gt 0){"Red"}else{"Green"})
Write-Host ""
Write-Host "Waiting 20 seconds for scoring to complete..." -ForegroundColor Yellow
Start-Sleep -Seconds 20

Write-Host ""
Write-Host "Checking results..." -ForegroundColor Cyan
$checkQuery = "SELECT id, LEFT(title, 40) as title, COALESCE(ai_score::text, 'Not scored') as score FROM blog_posts WHERE id IN ($($postIds -join ',')) ORDER BY id;"
kubectl exec -n $Namespace sha-blog-dev-sha-microservices-app-postgresql-0 -- psql -U devuser -d sha_blog_dev -c $checkQuery

Write-Host ""
Write-Host "Done! Check the scores above." -ForegroundColor Green
Write-Host "Note: If scores still show 'Not scored', check AI agent logs:" -ForegroundColor Yellow
Write-Host "  kubectl logs -n $Namespace -l app=ai-agent --tail=50" -ForegroundColor Gray



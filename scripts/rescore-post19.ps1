# Rescore post 19 (test7)

Write-Host "Rescoring post 19 (test7)..." -ForegroundColor Cyan

# Trigger scoring using kubectl run with printf to avoid shell escaping issues
kubectl run score-p19 --image=curlimages/curl:latest --rm -i --restart=Never -n sha-dev -- sh -c "printf '{\"post_id\": 19}' | curl -s -X POST http://ai-agent:8000/score -H 'Content-Type: application/json' -d @-"

Write-Host "`nWaiting 15 seconds for scoring..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

Write-Host "`nChecking result:" -ForegroundColor Cyan
kubectl exec -n sha-dev sha-blog-dev-sha-microservices-app-postgresql-0 -- psql -U devuser -d sha_blog_dev -c "SELECT id, title, ai_score, last_scored_at FROM blog_posts WHERE id = 19;"



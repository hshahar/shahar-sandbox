# PowerShell version of ArgoCD Apps installation script
# For Windows users

$NAMESPACE = "argocd"

Write-Host "Installing ArgoCD Applications (App-of-Apps pattern)..." -ForegroundColor Cyan
helm upgrade --install argocd-apps argo/argocd-apps `
  --namespace $NAMESPACE `
  -f 03-values-apps.yaml

Write-Host "`nWaiting for applications to be created..." -ForegroundColor Cyan
Start-Sleep -Seconds 5

Write-Host "`nChecking Applications and AppProjects..." -ForegroundColor Cyan
kubectl -n $NAMESPACE get app,appproject

Write-Host "`nArgoCD Apps installed successfully!" -ForegroundColor Green
Write-Host "The root app will automatically sync child applications from: argocd/applications/" -ForegroundColor Yellow

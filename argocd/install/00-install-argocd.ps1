# PowerShell version of ArgoCD installation script
# For Windows users

$NAMESPACE = "argocd"

Write-Host "Adding Argo Helm repository..." -ForegroundColor Cyan
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

Write-Host "`nInstalling Argo CD..." -ForegroundColor Cyan
helm upgrade --install argocd argo/argo-cd `
  --namespace $NAMESPACE `
  --create-namespace `
  -f 01-values-argocd.yaml

Write-Host "`nWaiting for Argo CD to be ready..." -ForegroundColor Cyan
kubectl -n $NAMESPACE rollout status deploy/argocd-server --timeout=600s

Write-Host "`nArgo CD installed successfully!" -ForegroundColor Green

Write-Host "`nGetting pods status..." -ForegroundColor Cyan
kubectl -n $NAMESPACE get pods -o wide

Write-Host "`nGetting initial admin password..." -ForegroundColor Cyan
$password = kubectl -n $NAMESPACE get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
$decodedPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($password))

Write-Host "`n=====================================" -ForegroundColor Yellow
Write-Host "Access Argo CD at: http://sha-argocd.blog.local" -ForegroundColor Green
Write-Host "Username: admin" -ForegroundColor Green
Write-Host "Password: $decodedPassword" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Yellow

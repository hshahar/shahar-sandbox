# Deploy SHA's K8s Blog Platform
Write-Host "🚀 Starting deployment of SHA's K8s Blog Platform..." -ForegroundColor Cyan
Write-Host "This will take 5-10 minutes. Please do not interrupt!" -ForegroundColor Yellow
Write-Host ""

Set-Location C:\Users\ILPETSHHA.old\dev\testshahar\terraform

$terraformPath = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Hashicorp.Terraform_Microsoft.Winget.Source_8wekyb3d8bbwe\terraform.exe"

& $terraformPath apply -var-file="environments/dev.tfvars" -auto-approve

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Deployment successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Add hosts entries (run as Administrator):" -ForegroundColor White
    Write-Host "   cd scripts" -ForegroundColor Gray
    Write-Host "   .\add-hosts.ps1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Access your applications:" -ForegroundColor White
    Write-Host "   Frontend:  http://sha-dev.blog.local" -ForegroundColor Yellow
    Write-Host "   ArgoCD:    http://sha-argocd-dev.local" -ForegroundColor Yellow
    Write-Host "   Grafana:   http://sha-grafana-dev.local (admin/admin)" -ForegroundColor Yellow
    Write-Host "   Vault:     http://sha-vault-dev.local" -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "❌ Deployment failed!" -ForegroundColor Red
    Write-Host "Check the error messages above." -ForegroundColor Yellow
}

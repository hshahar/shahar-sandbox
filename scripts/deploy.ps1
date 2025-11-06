# Deploy or update application
# Usage: .\deploy.ps1 -Environment dev

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment
)

# Map environment to namespace
$namespace = $Environment
if ($Environment -eq "prod") {
    $namespace = "production"
}

Write-Host "🚀 Deploying to $Environment environment..." -ForegroundColor Cyan
Write-Host ""

# Check if namespace exists
$nsExists = kubectl get namespace $namespace 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "📦 Creating namespace: $namespace" -ForegroundColor Yellow
    kubectl create namespace $namespace
}

# Get the release name
$releaseName = "sha-k8s-blog-$Environment"

# Check if release exists
$releaseExists = helm list -n $namespace -q | Select-String -Pattern "^$releaseName$"

Set-Location -Path "$PSScriptRoot\..\helm\microservices-app"

if ($releaseExists) {
    Write-Host "🔄 Upgrading existing release: $releaseName" -ForegroundColor Yellow
    helm upgrade $releaseName . `
        -f "values-$Environment.yaml" `
        -n $namespace `
        --wait `
        --timeout 5m
}
else {
    Write-Host "📦 Installing new release: $releaseName" -ForegroundColor Yellow
    helm install $releaseName . `
        -f "values-$Environment.yaml" `
        -n $namespace `
        --create-namespace `
        --wait `
        --timeout 5m
}

Set-Location -Path $PSScriptRoot

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Deployment successful!" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "📊 Deployment status:" -ForegroundColor Cyan
    kubectl get pods -n $namespace
    
    Write-Host ""
    Write-Host "🌐 Services:" -ForegroundColor Cyan
    kubectl get svc -n $namespace
    
    Write-Host ""
    Write-Host "🔗 Ingress:" -ForegroundColor Cyan
    kubectl get ingress -n $namespace
    
    Write-Host ""
    Write-Host "🔍 To view logs, run:" -ForegroundColor Yellow
    Write-Host "   .\scripts\view-logs.ps1 -Environment $Environment -Follow" -ForegroundColor Cyan
}
else {
    Write-Host ""
    Write-Host "❌ Deployment failed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "🔍 Check the logs:" -ForegroundColor Yellow
    Write-Host "   kubectl get events -n $namespace --sort-by='.lastTimestamp'" -ForegroundColor Cyan
    exit 1
}

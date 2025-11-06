# ArgoCD Sync Script
# Manually trigger ArgoCD sync for an application

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force,
    
    [Parameter(Mandatory=$false)]
    [switch]$Prune,
    
    [Parameter(Mandatory=$false)]
    [switch]$Wait
)

$ErrorActionPreference = "Stop"

$appName = "k8s-blog-$Environment"

Write-Host "Syncing ArgoCD Application: $appName" -ForegroundColor Cyan
Write-Host ""

# Check if argocd CLI is installed
try {
    $null = Get-Command argocd -ErrorAction Stop
} catch {
    Write-Host "⚠ ArgoCD CLI not found. Install from:" -ForegroundColor Yellow
    Write-Host "  https://github.com/argoproj/argo-cd/releases" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Using kubectl instead..." -ForegroundColor Yellow
    
    # Trigger sync via kubectl
    kubectl patch application $appName -n argocd --type json -p='[{"op": "replace", "path": "/operation", "value": {"sync": {"syncStrategy": {"hook": {}}}}}]'
    
    Write-Host "✓ Sync triggered via kubectl" -ForegroundColor Green
    exit 0
}

# Build sync command
$syncArgs = @("app", "sync", $appName)

if ($Force) {
    $syncArgs += "--force"
    Write-Host "Force sync enabled" -ForegroundColor Yellow
}

if ($Prune) {
    $syncArgs += "--prune"
    Write-Host "Prune enabled (will delete resources not in Git)" -ForegroundColor Yellow
}

# Execute sync
Write-Host "Triggering sync..." -ForegroundColor Gray
& argocd $syncArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Sync failed!" -ForegroundColor Red
    exit 1
}

# Wait for sync to complete
if ($Wait) {
    Write-Host ""
    Write-Host "Waiting for sync to complete..." -ForegroundColor Yellow
    & argocd app wait $appName --timeout 300
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Sync completed successfully!" -ForegroundColor Green
    } else {
        Write-Host "✗ Sync did not complete within timeout" -ForegroundColor Red
        exit 1
    }
}

# Show current status
Write-Host ""
Write-Host "Current Status:" -ForegroundColor Cyan
& argocd app get $appName

Write-Host ""
Write-Host "✓ Sync command executed" -ForegroundColor Green

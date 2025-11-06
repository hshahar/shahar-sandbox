# View logs from Kubernetes pods
# Usage: .\view-logs.ps1 -Environment dev -Component backend

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("frontend", "backend", "postgresql", "all")]
    [string]$Component = "all",
    
    [Parameter(Mandatory=$false)]
    [switch]$Follow
)

# Map environment to namespace
$namespace = $Environment
if ($Environment -eq "prod") {
    $namespace = "production"
}

Write-Host "📋 Viewing logs for $Component in $namespace namespace" -ForegroundColor Cyan
Write-Host ""

$followFlag = if ($Follow) { "-f" } else { "" }

if ($Component -eq "all") {
    Write-Host "=== Frontend Logs ===" -ForegroundColor Yellow
    kubectl logs -n $namespace -l app=frontend --tail=50 $followFlag
    
    Write-Host ""
    Write-Host "=== Backend Logs ===" -ForegroundColor Yellow
    kubectl logs -n $namespace -l app=backend --tail=50 $followFlag
    
    Write-Host ""
    Write-Host "=== PostgreSQL Logs ===" -ForegroundColor Yellow
    kubectl logs -n $namespace -l app=postgresql --tail=50 $followFlag
}
else {
    kubectl logs -n $namespace -l app=$Component --tail=100 $followFlag
}

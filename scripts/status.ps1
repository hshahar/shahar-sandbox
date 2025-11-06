# Check status of deployments
# Usage: .\status.ps1 -Environment dev

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "staging", "prod", "all")]
    [string]$Environment = "all"
)

function Show-EnvironmentStatus {
    param($namespace)
    
    Write-Host ""
    Write-Host "=" * 70 -ForegroundColor Cyan
    Write-Host "Environment: $namespace" -ForegroundColor Yellow
    Write-Host "=" * 70 -ForegroundColor Cyan
    
    # Check if namespace exists
    $nsExists = kubectl get namespace $namespace 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Namespace does not exist" -ForegroundColor Red
        return
    }
    
    # Pods
    Write-Host ""
    Write-Host "📦 Pods:" -ForegroundColor Cyan
    kubectl get pods -n $namespace -o wide
    
    # Services
    Write-Host ""
    Write-Host "🌐 Services:" -ForegroundColor Cyan
    kubectl get svc -n $namespace
    
    # Deployments
    Write-Host ""
    Write-Host "🚀 Deployments:" -ForegroundColor Cyan
    kubectl get deployments -n $namespace
    
    # StatefulSets
    Write-Host ""
    Write-Host "💾 StatefulSets:" -ForegroundColor Cyan
    kubectl get statefulsets -n $namespace
    
    # PVCs
    Write-Host ""
    Write-Host "💿 Persistent Volume Claims:" -ForegroundColor Cyan
    kubectl get pvc -n $namespace
    
    # HPA
    Write-Host ""
    Write-Host "📈 Horizontal Pod Autoscalers:" -ForegroundColor Cyan
    kubectl get hpa -n $namespace 2>$null
    
    # Ingress
    Write-Host ""
    Write-Host "🔗 Ingress:" -ForegroundColor Cyan
    kubectl get ingress -n $namespace
    
    # Secrets
    Write-Host ""
    Write-Host "🔐 Secrets:" -ForegroundColor Cyan
    kubectl get secrets -n $namespace
    
    # Helm releases
    Write-Host ""
    Write-Host "📊 Helm Releases:" -ForegroundColor Cyan
    helm list -n $namespace
    
    # Recent events
    Write-Host ""
    Write-Host "📋 Recent Events:" -ForegroundColor Cyan
    kubectl get events -n $namespace --sort-by='.lastTimestamp' | Select-Object -Last 10
}

Write-Host "🔍 Kubernetes Cluster Status" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan

if ($Environment -eq "all") {
    $namespaces = @("dev", "staging", "production")
    foreach ($ns in $namespaces) {
        Show-EnvironmentStatus -namespace $ns
    }
}
else {
    $namespace = $Environment
    if ($Environment -eq "prod") {
        $namespace = "production"
    }
    Show-EnvironmentStatus -namespace $namespace
}

Write-Host ""
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "✨ Status check complete!" -ForegroundColor Green
Write-Host "=" * 70 -ForegroundColor Cyan

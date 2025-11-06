# Clean up all resources
# Usage: .\cleanup.ps1 -Environment dev

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "staging", "prod", "all")]
    [string]$Environment = "all"
)

Write-Host "🧹 Kubernetes Cleanup Script" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan
Write-Host ""

$environments = @()
if ($Environment -eq "all") {
    $environments = @("dev", "staging", "production")
    Write-Host "⚠️  WARNING: This will delete ALL environments!" -ForegroundColor Red
}
else {
    $namespace = $Environment
    if ($Environment -eq "prod") {
        $namespace = "production"
    }
    $environments = @($namespace)
    Write-Host "This will delete the $Environment environment" -ForegroundColor Yellow
}

Write-Host ""
$confirm = Read-Host "Are you sure? (type 'yes' to confirm)"

if ($confirm -ne "yes") {
    Write-Host "❌ Cleanup cancelled" -ForegroundColor Yellow
    exit 0
}

Write-Host ""

foreach ($ns in $environments) {
    Write-Host "🗑️  Deleting namespace: $ns" -ForegroundColor Yellow
    
    # Delete Helm releases first
    $releases = helm list -n $ns -q 2>$null
    if ($releases) {
        foreach ($release in $releases) {
            Write-Host "   Uninstalling Helm release: $release" -ForegroundColor Cyan
            helm uninstall $release -n $ns
        }
    }
    
    # Delete namespace
    kubectl delete namespace $ns --ignore-not-found=true
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Namespace $ns deleted" -ForegroundColor Green
    }
    else {
        Write-Host "⚠️  Failed to delete namespace $ns" -ForegroundColor Red
    }
    
    Write-Host ""
}

# Optionally clean up Terraform state
Write-Host "🔧 Clean up Terraform state?" -ForegroundColor Yellow
$cleanTerraform = Read-Host "Remove Terraform state files? (yes/no)"

if ($cleanTerraform -eq "yes") {
    Set-Location -Path "$PSScriptRoot\..\terraform"
    
    if (Test-Path ".terraform") {
        Remove-Item -Recurse -Force ".terraform"
        Write-Host "✅ Removed .terraform directory" -ForegroundColor Green
    }
    
    if (Test-Path ".terraform.lock.hcl") {
        Remove-Item -Force ".terraform.lock.hcl"
        Write-Host "✅ Removed .terraform.lock.hcl" -ForegroundColor Green
    }
    
    if (Test-Path "terraform.tfstate") {
        Remove-Item -Force "terraform.tfstate"
        Write-Host "✅ Removed terraform.tfstate" -ForegroundColor Green
    }
    
    if (Test-Path "terraform.tfstate.backup") {
        Remove-Item -Force "terraform.tfstate.backup"
        Write-Host "✅ Removed terraform.tfstate.backup" -ForegroundColor Green
    }
    
    Set-Location -Path $PSScriptRoot
}

Write-Host ""
Write-Host "✨ Cleanup complete!" -ForegroundColor Green

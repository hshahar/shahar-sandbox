# ArgoCD Deployment Script for Kubernetes Blog Platform
# This script deploys infrastructure and sets up ArgoCD

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipInfrastructure,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipArgoCD
)

$ErrorActionPreference = "Stop"

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host " Kubernetes Blog Platform Deployment" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Deploy Infrastructure with Terraform
if (-not $SkipInfrastructure) {
    Write-Host "[1/5] Deploying infrastructure with Terraform..." -ForegroundColor Yellow
    
    Set-Location terraform
    
    Write-Host "  Initializing Terraform..." -ForegroundColor Gray
    terraform init
    
    Write-Host "  Planning deployment..." -ForegroundColor Gray
    terraform plan -var-file="environments/$Environment.tfvars" -out=tfplan
    
    $confirm = Read-Host "  Apply this plan? (yes/no)"
    if ($confirm -eq "yes") {
        Write-Host "  Applying Terraform configuration..." -ForegroundColor Gray
        terraform apply tfplan
        Remove-Item tfplan
        Write-Host "  ✓ Infrastructure deployed successfully!" -ForegroundColor Green
    } else {
        Write-Host "  Deployment cancelled." -ForegroundColor Red
        Set-Location ..
        exit 1
    }
    
    Set-Location ..
} else {
    Write-Host "[1/5] Skipping infrastructure deployment" -ForegroundColor Gray
}

# Step 2: Wait for ArgoCD to be ready
if (-not $SkipArgoCD) {
    Write-Host "[2/5] Waiting for ArgoCD to be ready..." -ForegroundColor Yellow
    
    Write-Host "  Checking ArgoCD pods..." -ForegroundColor Gray
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
    
    Write-Host "  ✓ ArgoCD is ready!" -ForegroundColor Green
} else {
    Write-Host "[2/5] Skipping ArgoCD wait" -ForegroundColor Gray
}

# Step 3: Get ArgoCD admin password
Write-Host "[3/5] Retrieving ArgoCD admin password..." -ForegroundColor Yellow

try {
    $passwordBase64 = kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}"
    $password = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($passwordBase64))
    
    Write-Host ""
    Write-Host "  ============================================" -ForegroundColor Green
    Write-Host "  ArgoCD Admin Credentials" -ForegroundColor Green
    Write-Host "  ============================================" -ForegroundColor Green
    Write-Host "  URL:      http://argocd-$Environment.local" -ForegroundColor White
    Write-Host "  Username: admin" -ForegroundColor White
    Write-Host "  Password: $password" -ForegroundColor White
    Write-Host "  ============================================" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "  ⚠ Could not retrieve ArgoCD password. Check manually:" -ForegroundColor Yellow
    Write-Host "  kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d" -ForegroundColor Gray
}

# Step 4: Update hosts file
Write-Host "[4/5] Updating hosts file..." -ForegroundColor Yellow

$hostsPath = "C:\Windows\System32\drivers\etc\hosts"
$hostsEntries = @(
    "127.0.0.1 argocd-$Environment.local",
    "127.0.0.1 $Environment.myapp.local"
)

try {
    $currentHosts = Get-Content $hostsPath -Raw
    $needsUpdate = $false
    
    foreach ($entry in $hostsEntries) {
        if ($currentHosts -notmatch [regex]::Escape($entry)) {
            $needsUpdate = $true
            break
        }
    }
    
    if ($needsUpdate) {
        Write-Host "  Adding entries to hosts file (requires admin)..." -ForegroundColor Gray
        foreach ($entry in $hostsEntries) {
            if ($currentHosts -notmatch [regex]::Escape($entry)) {
                Add-Content -Path $hostsPath -Value $entry
                Write-Host "    Added: $entry" -ForegroundColor Gray
            }
        }
        Write-Host "  ✓ Hosts file updated!" -ForegroundColor Green
    } else {
        Write-Host "  Hosts file already configured" -ForegroundColor Gray
    }
} catch {
    Write-Host "  ⚠ Could not update hosts file. Please add manually:" -ForegroundColor Yellow
    foreach ($entry in $hostsEntries) {
        Write-Host "    $entry" -ForegroundColor Gray
    }
}

# Step 5: Deploy applications via ArgoCD
Write-Host "[5/5] Deploying applications via ArgoCD..." -ForegroundColor Yellow

Write-Host "  Applying App-of-Apps..." -ForegroundColor Gray
kubectl apply -f argocd/app-of-apps.yaml

Write-Host "  Waiting for applications to sync..." -ForegroundColor Gray
Start-Sleep -Seconds 5

Write-Host "  Checking application status..." -ForegroundColor Gray
kubectl get applications -n argocd

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host " Deployment Complete!" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Open ArgoCD UI:     http://argocd-$Environment.local" -ForegroundColor White
Write-Host "2. Open Application:   http://$Environment.myapp.local" -ForegroundColor White
Write-Host "3. Monitor deployment: argocd app list" -ForegroundColor White
Write-Host "4. View logs:          kubectl logs -n $Environment -l app=backend -f" -ForegroundColor White
Write-Host ""

Write-Host "Useful Commands:" -ForegroundColor Yellow
Write-Host "  argocd app get k8s-blog-$Environment" -ForegroundColor Gray
Write-Host "  argocd app sync k8s-blog-$Environment" -ForegroundColor Gray
Write-Host "  argocd app history k8s-blog-$Environment" -ForegroundColor Gray
Write-Host "  kubectl get pods -n $Environment" -ForegroundColor Gray
Write-Host ""

# Optionally open browser
$openBrowser = Read-Host "Open ArgoCD in browser? (y/n)"
if ($openBrowser -eq "y") {
    Start-Process "http://argocd-$Environment.local"
}

Write-Host "✓ Setup complete!" -ForegroundColor Green

# Setup script for Kubernetes Microservices Infrastructure
# This script sets up the entire environment on Windows with Rancher Desktop

Write-Host "🚀 Kubernetes Microservices Infrastructure Setup" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "⚠️  Warning: Not running as Administrator. Some operations may fail." -ForegroundColor Yellow
    Write-Host ""
}

# Function to check if a command exists
function Test-Command {
    param($Command)
    try {
        if (Get-Command $Command -ErrorAction Stop) {
            return $true
        }
    }
    catch {
        return $false
    }
}

# Check prerequisites
Write-Host "📋 Checking prerequisites..." -ForegroundColor Yellow

$prerequisites = @{
    "kubectl" = "Kubernetes CLI"
    "helm" = "Helm package manager"
    "terraform" = "Terraform"
}

$missing = @()
foreach ($cmd in $prerequisites.Keys) {
    if (Test-Command $cmd) {
        Write-Host "✅ $($prerequisites[$cmd]) ($cmd) is installed" -ForegroundColor Green
    }
    else {
        Write-Host "❌ $($prerequisites[$cmd]) ($cmd) is NOT installed" -ForegroundColor Red
        $missing += $cmd
    }
}

if ($missing.Count -gt 0) {
    Write-Host ""
    Write-Host "❌ Missing prerequisites. Please install:" -ForegroundColor Red
    foreach ($cmd in $missing) {
        Write-Host "   - $cmd" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Install using winget:" -ForegroundColor Yellow
    Write-Host "   winget install Kubernetes.kubectl" -ForegroundColor Cyan
    Write-Host "   winget install Helm.Helm" -ForegroundColor Cyan
    Write-Host "   winget install Hashicorp.Terraform" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

Write-Host ""

# Check Kubernetes cluster
Write-Host "🔍 Checking Kubernetes cluster..." -ForegroundColor Yellow
try {
    $clusterInfo = kubectl cluster-info 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Kubernetes cluster is accessible" -ForegroundColor Green
        Write-Host "$clusterInfo" -ForegroundColor Gray
    }
    else {
        Write-Host "❌ Cannot connect to Kubernetes cluster" -ForegroundColor Red
        Write-Host "Please ensure Rancher Desktop or Docker Desktop is running with Kubernetes enabled" -ForegroundColor Yellow
        exit 1
    }
}
catch {
    Write-Host "❌ Error checking Kubernetes cluster: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Ask user which environment to deploy
Write-Host "📦 Which environment would you like to deploy?" -ForegroundColor Yellow
Write-Host "1. Development (dev)" -ForegroundColor Cyan
Write-Host "2. Staging" -ForegroundColor Cyan
Write-Host "3. Production" -ForegroundColor Cyan
Write-Host "4. All environments" -ForegroundColor Cyan
Write-Host ""
$choice = Read-Host "Enter your choice (1-4)"

$environments = @()
switch ($choice) {
    "1" { $environments = @("dev") }
    "2" { $environments = @("staging") }
    "3" { $environments = @("prod") }
    "4" { $environments = @("dev", "staging", "prod") }
    default {
        Write-Host "❌ Invalid choice" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# Install Ingress NGINX Controller
Write-Host "🌐 Installing Ingress NGINX Controller..." -ForegroundColor Yellow
$ingressInstalled = kubectl get namespace ingress-nginx 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Installing Ingress NGINX..." -ForegroundColor Cyan
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/cloud/deploy.yaml
    
    Write-Host "Waiting for Ingress Controller to be ready..." -ForegroundColor Cyan
    kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Ingress NGINX Controller installed successfully" -ForegroundColor Green
    }
    else {
        Write-Host "⚠️  Ingress Controller installation may have issues. Continuing anyway..." -ForegroundColor Yellow
    }
}
else {
    Write-Host "✅ Ingress NGINX Controller already installed" -ForegroundColor Green
}

Write-Host ""

# Deploy to each environment
foreach ($env in $environments) {
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host "🚀 Deploying to $env environment..." -ForegroundColor Yellow
    Write-Host "=" * 60 -ForegroundColor Cyan
    
    # Initialize Terraform
    Write-Host "📦 Initializing Terraform..." -ForegroundColor Cyan
    Set-Location -Path "$PSScriptRoot\..\terraform"
    terraform init
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Terraform initialization failed" -ForegroundColor Red
        continue
    }
    
    # Apply Terraform
    Write-Host "🔧 Applying Terraform configuration..." -ForegroundColor Cyan
    terraform apply -var-file="environments\$env.tfvars" -auto-approve
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Successfully deployed to $env environment" -ForegroundColor Green
    }
    else {
        Write-Host "❌ Deployment to $env environment failed" -ForegroundColor Red
        continue
    }
    
    Write-Host ""
}

Set-Location -Path $PSScriptRoot

Write-Host ""
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "✨ Setup Complete!" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host ""

# Add hosts file entries
Write-Host "📝 Next steps:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Add the following entries to your hosts file:" -ForegroundColor Cyan
Write-Host "   File location: C:\Windows\System32\drivers\etc\hosts" -ForegroundColor Gray
Write-Host ""
foreach ($env in $environments) {
    $host_name = switch ($env) {
        "dev" { "sha-dev.blog.local" }
        "staging" { "sha-staging.blog.local" }
        "prod" { "sha.blog.local" }
    }
    Write-Host "   127.0.0.1 $host_name" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "2. Access your applications:" -ForegroundColor Cyan
foreach ($env in $environments) {
    $namespace = switch ($env) {
        "dev" { "sha-dev" }
        "staging" { "sha-staging" }
        "prod" { "sha-production" }
    }
    $host_name = switch ($env) {
        "dev" { "sha-dev.blog.local" }
        "staging" { "sha-staging.blog.local" }
        "prod" { "sha.blog.local" }
    }
    Write-Host "   $env environment: http://$host_name" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "3. View resources:" -ForegroundColor Cyan
foreach ($env in $environments) {
    $namespace = $env
    if ($env -eq "prod") { $namespace = "production" }
    Write-Host "   kubectl get all -n $namespace" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "4. View logs:" -ForegroundColor Cyan
Write-Host "   .\scripts\view-logs.ps1 -Environment dev" -ForegroundColor Yellow
Write-Host ""
Write-Host "Happy deploying! 🎉" -ForegroundColor Green

# Quick Commands Wrapper for PowerShell
# Usage: .\run.ps1 <command>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Command,
    
    [Parameter(Mandatory=$false, Position=1)]
    [string]$Environment = "dev"
)

$ErrorActionPreference = "Stop"

Write-Host "🚀 Running: $Command" -ForegroundColor Cyan
Write-Host ""

switch ($Command) {
    "setup" {
        Write-Host "Setting up environment..." -ForegroundColor Yellow
        .\scripts\setup.ps1
    }
    
    "deploy" {
        Write-Host "Deploying to $Environment..." -ForegroundColor Yellow
        .\scripts\deploy.ps1 -Environment $Environment
    }
    
    "status" {
        Write-Host "Checking status..." -ForegroundColor Yellow
        .\scripts\status.ps1 -Environment $Environment
    }
    
    "logs" {
        Write-Host "Viewing logs..." -ForegroundColor Yellow
        .\scripts\view-logs.ps1 -Environment $Environment -Follow
    }
    
    "cleanup" {
        Write-Host "Cleaning up..." -ForegroundColor Yellow
        .\scripts\cleanup.ps1 -Environment $Environment
    }
    
    "pods" {
        $ns = if ($Environment -eq "prod") { "production" } else { $Environment }
        kubectl get pods -n $ns
    }
    
    "services" {
        $ns = if ($Environment -eq "prod") { "production" } else { $Environment }
        kubectl get svc -n $ns
    }
    
    "ingress" {
        $ns = if ($Environment -eq "prod") { "production" } else { $Environment }
        kubectl get ingress -n $ns
    }
    
    "describe" {
        $ns = if ($Environment -eq "prod") { "production" } else { $Environment }
        kubectl describe all -n $ns
    }
    
    "events" {
        $ns = if ($Environment -eq "prod") { "production" } else { $Environment }
        kubectl get events -n $ns --sort-by='.lastTimestamp'
    }
    
    "port-forward" {
        $ns = if ($Environment -eq "prod") { "production" } else { $Environment }
        Write-Host "Port forwarding frontend to localhost:8080..." -ForegroundColor Yellow
        kubectl port-forward -n $ns service/myapp-$Environment-frontend 8080:80
    }
    
    "helm-list" {
        $ns = if ($Environment -eq "prod") { "production" } else { $Environment }
        helm list -n $ns
    }
    
    "helm-history" {
        $ns = if ($Environment -eq "prod") { "production" } else { $Environment }
        helm history myapp-$Environment -n $ns
    }
    
    "test" {
        Write-Host "Running Helm lint..." -ForegroundColor Yellow
        helm lint .\helm\microservices-app
        helm lint .\helm\microservices-app --values .\helm\microservices-app\values-dev.yaml
        helm lint .\helm\microservices-app --values .\helm\microservices-app\values-staging.yaml
        helm lint .\helm\microservices-app --values .\helm\microservices-app\values-prod.yaml
        
        Write-Host ""
        Write-Host "Running Terraform validate..." -ForegroundColor Yellow
        Set-Location -Path .\terraform
        terraform init -backend=false
        terraform validate
        Set-Location -Path ..
    }
    
    "help" {
        Write-Host "Available commands:" -ForegroundColor Green
        Write-Host ""
        Write-Host "  setup              - Initial setup and deployment" -ForegroundColor Cyan
        Write-Host "  deploy <env>       - Deploy to environment (dev/staging/prod)" -ForegroundColor Cyan
        Write-Host "  status <env>       - Check deployment status" -ForegroundColor Cyan
        Write-Host "  logs <env>         - View logs (with follow)" -ForegroundColor Cyan
        Write-Host "  cleanup <env>      - Clean up environment" -ForegroundColor Cyan
        Write-Host "  pods <env>         - List pods" -ForegroundColor Cyan
        Write-Host "  services <env>     - List services" -ForegroundColor Cyan
        Write-Host "  ingress <env>      - List ingress" -ForegroundColor Cyan
        Write-Host "  describe <env>     - Describe all resources" -ForegroundColor Cyan
        Write-Host "  events <env>       - Show recent events" -ForegroundColor Cyan
        Write-Host "  port-forward <env> - Port forward frontend to localhost:8080" -ForegroundColor Cyan
        Write-Host "  helm-list <env>    - List Helm releases" -ForegroundColor Cyan
        Write-Host "  helm-history <env> - Show Helm release history" -ForegroundColor Cyan
        Write-Host "  test               - Run linting and validation" -ForegroundColor Cyan
        Write-Host "  help               - Show this help" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Examples:" -ForegroundColor Yellow
        Write-Host "  .\run.ps1 deploy dev" -ForegroundColor Gray
        Write-Host "  .\run.ps1 status staging" -ForegroundColor Gray
        Write-Host "  .\run.ps1 logs prod" -ForegroundColor Gray
        Write-Host "  .\run.ps1 port-forward dev" -ForegroundColor Gray
    }
    
    default {
        Write-Host "❌ Unknown command: $Command" -ForegroundColor Red
        Write-Host "Run '.\run.ps1 help' for available commands" -ForegroundColor Yellow
        exit 1
    }
}

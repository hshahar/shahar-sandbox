#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Fixes Karpenter IAM permissions, postgres-backup configuration, and ai-agent startup probe
.DESCRIPTION
    This script applies critical fixes to the EKS cluster:
    1. Updates Karpenter IAM policy to allow tagging existing EC2 instances
    2. Fixes postgres-backup cronjob secret key references
    3. Adds startup probe to ai-agent deployment
    4. Removes startup taints from Karpenter-provisioned nodes
.EXAMPLE
    .\fix-karpenter-and-pods.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Karpenter & Pod Configuration Fixes" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Update Karpenter IAM Policy
Write-Host "[1/5] Applying Karpenter IAM policy update..." -ForegroundColor Yellow
Write-Host "Adding AllowKarpenterInstanceTagging permission..." -ForegroundColor Gray

Push-Location "$PSScriptRoot\..\terraform"
try {
    $tfVars = @(
        "-var=install_karpenter=true",
        "-var=cluster_name=sha-blog-eks",
        "-var=cluster_endpoint=https://9DD61832FFA1FF9DEEA8D3F39EC825BF.yl4.us-west-2.eks.amazonaws.com",
        "-var=oidc_provider_arn=arn:aws:iam::179580348028:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/9DD61832FFA1FF9DEEA8D3F39EC825BF",
        "-var=oidc_provider=oidc.eks.us-west-2.amazonaws.com/id/9DD61832FFA1FF9DEEA8D3F39EC825BF",
        "-var=node_role_arn=arn:aws:iam::179580348028:role/sha-blog-eks-general-eks-node-group-20251123071753537600000003",
        "-var=region=us-west-2",
        "-var=namespace=sha-dev",
        "-var=environment=dev",
        "-var=ingress_host=sha-dev.blog.local",
        "-var=kube_context=arn:aws:eks:us-west-2:179580348028:cluster/sha-blog-eks",
        "-target=aws_iam_policy.karpenter_controller[0]",
        "-auto-approve"
    )
    
    & terraform apply @tfVars
    if ($LASTEXITCODE -ne 0) {
        throw "Terraform apply failed"
    }
    Write-Host "✓ IAM policy updated successfully" -ForegroundColor Green
} finally {
    Pop-Location
}
Write-Host ""

# Step 2: Restart Karpenter
Write-Host "[2/5] Restarting Karpenter to pick up new IAM permissions..." -ForegroundColor Yellow
kubectl rollout restart deployment karpenter -n karpenter
Start-Sleep -Seconds 30
Write-Host "✓ Karpenter restarted" -ForegroundColor Green
Write-Host ""

# Step 3: Remove startup taints from Karpenter nodes
Write-Host "[3/5] Removing startup taints from Karpenter nodes..." -ForegroundColor Yellow
$karpenterNodes = kubectl get nodes --no-headers | Select-String -Pattern "10-0-13-148|10-0-17-216"
if ($karpenterNodes) {
    foreach ($nodeLine in $karpenterNodes) {
        $nodeName = ($nodeLine -split '\s+')[0]
        Write-Host "Removing taint from $nodeName..." -ForegroundColor Gray
        kubectl taint node $nodeName karpenter.sh/unregistered:NoSchedule- 2>&1 | Out-Null
    }
    Write-Host "✓ Startup taints removed" -ForegroundColor Green
} else {
    Write-Host "⚠ No Karpenter nodes found with taints" -ForegroundColor Yellow
}
Write-Host ""

# Step 4: Fix postgres-backup cronjob
Write-Host "[4/5] Fixing postgres-backup cronjob secret keys..." -ForegroundColor Yellow
$cronjobExists = kubectl get cronjob -n sha-dev sha-blog-dev-sha-microservices-app-postgres-backup 2>&1
if ($LASTEXITCODE -eq 0) {
    $tempDir = "C:\temp"
    if (-not (Test-Path $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir | Out-Null
    }
    
    kubectl get cronjob -n sha-dev sha-blog-dev-sha-microservices-app-postgres-backup -o yaml > "$tempDir\cronjob-backup.yaml"
    (Get-Content "$tempDir\cronjob-backup.yaml") -replace 'db-username','database-username' -replace 'db-password','database-password' | Set-Content "$tempDir\cronjob-fixed.yaml"
    kubectl apply -f "$tempDir\cronjob-fixed.yaml" | Out-Null
    
    # Delete old job to trigger new one with correct config
    $oldJob = kubectl get job -n sha-dev -o name | Select-String -Pattern "postgres-backup"
    if ($oldJob) {
        kubectl delete $oldJob -n sha-dev 2>&1 | Out-Null
    }
    
    Write-Host "✓ Postgres-backup cronjob fixed" -ForegroundColor Green
} else {
    Write-Host "⚠ Postgres-backup cronjob not found, skipping" -ForegroundColor Yellow
}
Write-Host ""

# Step 5: Add startup probe to ai-agent
Write-Host "[5/5] Adding startup probe to ai-agent deployment..." -ForegroundColor Yellow
$aiAgentDeployment = kubectl get deployment -n sha-dev sha-blog-dev-sha-microservices-app-ai-agent 2>&1
if ($LASTEXITCODE -eq 0) {
    # Check if startup probe already exists
    $hasStartupProbe = kubectl get deployment -n sha-dev sha-blog-dev-sha-microservices-app-ai-agent -o yaml | Select-String -Pattern "startupProbe"
    
    if (-not $hasStartupProbe) {
        $tempDir = "C:\temp"
        kubectl get deployment -n sha-dev sha-blog-dev-sha-microservices-app-ai-agent -o yaml > "$tempDir\ai-agent-deploy.yaml"
        
        $content = Get-Content "$tempDir\ai-agent-deploy.yaml" -Raw
        $startupProbe = @"
        startupProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 30
          successThreshold: 1
"@
        $content = $content -replace '(        livenessProbe:)', "$startupProbe`n`$1"
        $content | Set-Content "$tempDir\ai-agent-deploy-fixed.yaml"
        kubectl apply -f "$tempDir\ai-agent-deploy-fixed.yaml" | Out-Null
        
        # Scale down old replicaset to force new pod with startup probe
        Start-Sleep -Seconds 10
        $oldRS = kubectl get rs -n sha-dev -o name | Select-String -Pattern "ai-agent-8985446c"
        if ($oldRS) {
            kubectl scale $oldRS -n sha-dev --replicas=0 2>&1 | Out-Null
        }
        
        Write-Host "✓ Startup probe added to ai-agent" -ForegroundColor Green
    } else {
        Write-Host "✓ Startup probe already exists on ai-agent" -ForegroundColor Green
    }
} else {
    Write-Host "⚠ AI-agent deployment not found, skipping" -ForegroundColor Yellow
}
Write-Host ""

# Final status check
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Final Status Check" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Karpenter Pods:" -ForegroundColor Yellow
kubectl get pods -n karpenter -o wide
Write-Host ""

Write-Host "Application Pods:" -ForegroundColor Yellow
kubectl get pods -n sha-dev -o wide
Write-Host ""

Write-Host "Karpenter Nodes:" -ForegroundColor Yellow
kubectl get nodes | Select-String -Pattern "karpenter|NAME|10-0-13|10-0-17"
Write-Host ""

Write-Host "========================================" -ForegroundColor Green
Write-Host "Fix script completed successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

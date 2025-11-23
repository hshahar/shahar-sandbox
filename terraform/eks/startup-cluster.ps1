# Startup EKS Cluster
# This script scales up nodes from 0 back to desired capacity

param(
    [string]$ClusterName = "sha-blog-eks",
    [string]$Region = "us-west-2",
    [string]$Profile = "default",
    [int]$DesiredNodes = 2
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "EKS Cluster Startup Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Cluster: $ClusterName" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host "Desired Nodes: $DesiredNodes" -ForegroundColor Yellow
Write-Host ""

Write-Host "Step 1: Scaling up node groups..." -ForegroundColor Green

# Get all node groups
$nodeGroups = aws eks list-nodegroups --cluster-name $ClusterName --region $Region --profile $Profile --query "nodegroups" --output text

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to list node groups. Check cluster name and AWS credentials." -ForegroundColor Red
    exit 1
}

$nodeGroupArray = $nodeGroups -split "\s+"

foreach ($nodeGroup in $nodeGroupArray) {
    if ($nodeGroup -ne "") {
        Write-Host "  Scaling up node group: $nodeGroup" -ForegroundColor Cyan

        aws eks update-nodegroup-config `
            --cluster-name $ClusterName `
            --nodegroup-name $nodeGroup `
            --region $Region `
            --profile $Profile `
            --scaling-config "minSize=1,maxSize=3,desiredSize=$DesiredNodes"

        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ Node group $nodeGroup scaled up successfully" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Failed to scale up $nodeGroup" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "Step 2: Waiting for nodes to become ready..." -ForegroundColor Green
Write-Host "  This may take 3-5 minutes..." -ForegroundColor Yellow

# Wait for nodes
$maxWaitTime = 300 # 5 minutes
$waitedTime = 0
$checkInterval = 10

while ($waitedTime -lt $maxWaitTime) {
    $readyNodes = kubectl get nodes --no-headers 2>$null | Where-Object { $_ -match "Ready" } | Measure-Object | Select-Object -ExpandProperty Count

    if ($readyNodes -ge $DesiredNodes) {
        Write-Host "  ✓ $readyNodes nodes are ready!" -ForegroundColor Green
        break
    }

    Write-Host "  ⏳ $readyNodes/$DesiredNodes nodes ready... waiting..." -ForegroundColor Yellow
    Start-Sleep -Seconds $checkInterval
    $waitedTime += $checkInterval
}

Write-Host ""
Write-Host "Step 3: Checking pod status..." -ForegroundColor Green

# Show pod status in all namespaces
kubectl get pods --all-namespaces

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Cluster Startup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Cluster is now running with $DesiredNodes nodes." -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Check application status:" -ForegroundColor White
Write-Host "     kubectl get pods -A" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Get load balancer URL:" -ForegroundColor White
Write-Host "     kubectl get ingress -A" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. When done, shutdown to save costs:" -ForegroundColor White
Write-Host "     .\shutdown-cluster.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "Monthly Cost While Running: ~`$140-160" -ForegroundColor Yellow
Write-Host ""

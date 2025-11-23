# Shutdown EKS Cluster to Save Costs
# This script scales down nodes to 0 while keeping the control plane running
# Saves approximately 70% of costs (~$60-80/month savings)

param(
    [string]$ClusterName = "sha-blog-eks",
    [string]$Region = "us-west-2",
    [string]$Profile = "default"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "EKS Cluster Shutdown Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Cluster: $ClusterName" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host ""

# Confirm shutdown
$confirmation = Read-Host "Are you sure you want to shutdown the cluster? (yes/no)"
if ($confirmation -ne "yes") {
    Write-Host "Shutdown cancelled." -ForegroundColor Red
    exit 0
}

Write-Host ""
Write-Host "Step 1: Scaling down node groups to 0..." -ForegroundColor Green

# Get all node groups
$nodeGroups = aws eks list-nodegroups --cluster-name $ClusterName --region $Region --profile $Profile --query "nodegroups" --output text

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to list node groups. Check cluster name and AWS credentials." -ForegroundColor Red
    exit 1
}

$nodeGroupArray = $nodeGroups -split "\s+"

foreach ($nodeGroup in $nodeGroupArray) {
    if ($nodeGroup -ne "") {
        Write-Host "  Scaling down node group: $nodeGroup" -ForegroundColor Cyan

        aws eks update-nodegroup-config `
            --cluster-name $ClusterName `
            --nodegroup-name $nodeGroup `
            --region $Region `
            --profile $Profile `
            --scaling-config "minSize=0,maxSize=0,desiredSize=0"

        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ Node group $nodeGroup scaled down successfully" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Failed to scale down $nodeGroup" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "Step 2: Waiting for nodes to terminate..." -ForegroundColor Green
Write-Host "  This may take 3-5 minutes..." -ForegroundColor Yellow

Start-Sleep -Seconds 30

# Check node count
$nodeCount = kubectl get nodes --no-headers 2>$null | Measure-Object | Select-Object -ExpandProperty Count

if ($nodeCount -eq 0) {
    Write-Host "  ✓ All nodes terminated successfully" -ForegroundColor Green
} else {
    Write-Host "  ⚠ $nodeCount nodes still running. They will terminate shortly." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Cluster Shutdown Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Cost Impact:" -ForegroundColor Yellow
Write-Host "  • EKS Control Plane: Still running (~`$72/month)" -ForegroundColor White
Write-Host "  • NAT Gateway: Still running (~`$33/month)" -ForegroundColor White
Write-Host "  • Worker Nodes: STOPPED (saves ~`$60-80/month)" -ForegroundColor Green
Write-Host "  • Load Balancers: May still exist (check AWS console)" -ForegroundColor White
Write-Host ""
Write-Host "Total Monthly Cost While Shutdown: ~`$105/month" -ForegroundColor Yellow
Write-Host "Total Monthly Cost When Running: ~`$140-160/month" -ForegroundColor Yellow
Write-Host ""
Write-Host "To startup the cluster again, run:" -ForegroundColor Cyan
Write-Host "  .\startup-cluster.ps1" -ForegroundColor White
Write-Host ""
Write-Host "To completely destroy the cluster and save all costs:" -ForegroundColor Cyan
Write-Host "  terraform destroy" -ForegroundColor White
Write-Host ""

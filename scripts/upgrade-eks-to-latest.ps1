# Upgrade EKS cluster to latest version
# This script upgrades EKS one minor version at a time (AWS requirement)

param(
    [string]$ClusterName = "sha-blog-eks",
    [string]$Region = "us-west-2",
    [string]$TargetVersion = "1.34",
    [string]$NodeGroupName = "sha-blog-eks-general",
    [string]$NodeRoleArn = "arn:aws:iam::179580348028:role/sha-blog-eks-general-eks-node-group-20251123071753537600000003",
    [string[]]$Subnets = @("subnet-0510615f8d1ff5858", "subnet-0d9a3876691a6fa35")
)

function Wait-ClusterActive {
    param($Cluster, $Region)
    
    Write-Host "⏳ Waiting for cluster to become ACTIVE..." -ForegroundColor Yellow
    
    do {
        $status = aws eks describe-cluster --name $Cluster --region $Region --query 'cluster.status' --output text
        $version = aws eks describe-cluster --name $Cluster --region $Region --query 'cluster.version' --output text
        Write-Host "$(Get-Date -Format 'HH:mm:ss') - Status: $status | Version: $version" -ForegroundColor Cyan
        
        if ($status -ne "ACTIVE") {
            Start-Sleep -Seconds 30
        }
    } while ($status -ne "ACTIVE")
    
    Write-Host "✅ Cluster is ACTIVE!" -ForegroundColor Green
    return $version
}

function Wait-NodeGroupActive {
    param($Cluster, $NodeGroup, $Region)
    
    Write-Host "⏳ Waiting for node group to become ACTIVE..." -ForegroundColor Yellow
    
    do {
        $status = aws eks describe-nodegroup --cluster-name $Cluster --nodegroup-name $NodeGroup --region $Region --query 'nodegroup.status' --output text 2>$null
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "$(Get-Date -Format 'HH:mm:ss') - Node group not found yet..." -ForegroundColor Gray
            Start-Sleep -Seconds 10
            continue
        }
        
        Write-Host "$(Get-Date -Format 'HH:mm:ss') - Node group status: $status" -ForegroundColor Cyan
        
        if ($status -ne "ACTIVE") {
            Start-Sleep -Seconds 30
        }
    } while ($status -ne "ACTIVE")
    
    Write-Host "✅ Node group is ACTIVE!" -ForegroundColor Green
}

function Upgrade-ClusterVersion {
    param($Cluster, $FromVersion, $ToVersion, $Region)
    
    Write-Host ""
    Write-Host "🚀 Upgrading cluster from $FromVersion to $ToVersion..." -ForegroundColor Cyan
    
    $result = aws eks update-cluster-version --name $Cluster --kubernetes-version $ToVersion --region $Region 2>&1 | ConvertFrom-Json
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Upgrade failed!" -ForegroundColor Red
        Write-Host $result -ForegroundColor Red
        return $false
    }
    
    Write-Host "✅ Upgrade initiated successfully" -ForegroundColor Green
    Write-Host "Update ID: $($result.update.id)" -ForegroundColor Gray
    
    return $true
}

# Main script
Write-Host "🔧 EKS Cluster Upgrade Script" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan
Write-Host "Cluster: $ClusterName" -ForegroundColor Yellow
Write-Host "Target Version: $TargetVersion" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host ""

# Step 1: Wait for current upgrade to complete (1.29 → 1.30)
Write-Host "📋 Step 1: Waiting for current upgrade to complete..." -ForegroundColor Yellow
$currentVersion = Wait-ClusterActive -Cluster $ClusterName -Region $Region
Write-Host "Current version: $currentVersion" -ForegroundColor Green
Write-Host ""

# Step 2: Create node group if it doesn't exist
Write-Host "📋 Step 2: Checking if node group exists..." -ForegroundColor Yellow
$nodeGroups = aws eks list-nodegroups --cluster-name $ClusterName --region $Region --query 'nodegroups' --output json | ConvertFrom-Json

if ($nodeGroups -notcontains $NodeGroupName) {
    Write-Host "Creating node group: $NodeGroupName" -ForegroundColor Cyan
    
    $createResult = aws eks create-nodegroup `
        --cluster-name $ClusterName `
        --nodegroup-name $NodeGroupName `
        --node-role $NodeRoleArn `
        --subnets $Subnets[0] $Subnets[1] `
        --instance-types t3.medium `
        --ami-type AL2_x86_64 `
        --scaling-config minSize=1,maxSize=3,desiredSize=2 `
        --capacity-type SPOT `
        --region $Region 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Node group creation initiated" -ForegroundColor Green
        Wait-NodeGroupActive -Cluster $ClusterName -NodeGroup $NodeGroupName -Region $Region
    } else {
        Write-Host "⚠️  Failed to create node group: $createResult" -ForegroundColor Yellow
    }
} else {
    Write-Host "✅ Node group already exists" -ForegroundColor Green
}
Write-Host ""

# Step 3: Continue upgrading through versions
Write-Host "📋 Step 3: Continuing upgrades to version $TargetVersion..." -ForegroundColor Yellow

$versionPath = @("1.30", "1.31", "1.32", "1.33", "1.34")
$targetIndex = $versionPath.IndexOf($TargetVersion)

if ($targetIndex -eq -1) {
    Write-Host "❌ Invalid target version: $TargetVersion" -ForegroundColor Red
    exit 1
}

foreach ($nextVersion in $versionPath) {
    # Get current version
    $currentVersion = Wait-ClusterActive -Cluster $ClusterName -Region $Region
    
    # Extract just the version number (e.g., "1.30" from "1.30")
    $currentMajorMinor = $currentVersion
    
    # Check if we've reached target
    if ($currentMajorMinor -eq $TargetVersion) {
        Write-Host ""
        Write-Host "🎉 Cluster is already at target version $TargetVersion!" -ForegroundColor Green
        break
    }
    
    # Check if this is the next version to upgrade to
    $currentIndex = $versionPath.IndexOf($currentMajorMinor)
    $nextIndex = $versionPath.IndexOf($nextVersion)
    
    if ($nextIndex -eq $currentIndex + 1) {
        # Upgrade to next version
        $success = Upgrade-ClusterVersion -Cluster $ClusterName -FromVersion $currentMajorMinor -ToVersion $nextVersion -Region $Region
        
        if (-not $success) {
            Write-Host "❌ Upgrade failed. Stopping." -ForegroundColor Red
            exit 1
        }
        
        # Wait for upgrade to complete
        $null = Wait-ClusterActive -Cluster $ClusterName -Region $Region
        
        # Check if we've reached target
        if ($nextVersion -eq $TargetVersion) {
            Write-Host ""
            Write-Host "🎉 Successfully upgraded to version $TargetVersion!" -ForegroundColor Green
            break
        }
    }
}

Write-Host ""
Write-Host "✅ Upgrade process complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📊 Final cluster status:" -ForegroundColor Cyan
aws eks describe-cluster --name $ClusterName --region $Region --query 'cluster.{Version:version,Status:status,Endpoint:endpoint}' --output json | ConvertFrom-Json | Format-List

Write-Host ""
Write-Host "🔍 Checking nodes..." -ForegroundColor Cyan
kubectl get nodes

Write-Host ""
Write-Host "💡 Next steps:" -ForegroundColor Yellow
Write-Host "1. Update node group to match cluster version" -ForegroundColor White
Write-Host "2. Update addon versions (VPC CNI, kube-proxy, CoreDNS)" -ForegroundColor White
Write-Host "3. Test your applications" -ForegroundColor White

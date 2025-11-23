# Grant EKS cluster access to the current IAM user
# This script updates the cluster to use API-based authentication and grants admin access

$ErrorActionPreference = "Stop"

$clusterName = "sha-blog-eks"
$region = "us-west-2"

Write-Host "Getting current IAM user..." -ForegroundColor Cyan
$userArn = aws sts get-caller-identity --query "Arn" --output text
Write-Host "Current user: $userArn" -ForegroundColor Green

Write-Host "`nAttempting to update cluster authentication mode to API_AND_CONFIG_MAP..." -ForegroundColor Cyan
try {
    aws eks update-cluster-config `
        --name $clusterName `
        --region $region `
        --access-config authenticationMode=API_AND_CONFIG_MAP
    
    Write-Host "✅ Cluster authentication mode update initiated" -ForegroundColor Green
    Write-Host "⏳ Waiting for update to complete (this may take 5-10 minutes)..." -ForegroundColor Yellow
    
    # Wait for update to complete
    $maxAttempts = 30
    $attempt = 0
    do {
        Start-Sleep -Seconds 20
        $attempt++
        $status = aws eks describe-update `
            --name $clusterName `
            --region $region `
            --query "update.status" `
            --output text 2>$null
        
        Write-Host "Attempt $attempt/$maxAttempts - Status: $status" -ForegroundColor Yellow
    } while ($status -eq "InProgress" -and $attempt -lt $maxAttempts)
    
    if ($status -eq "Successful") {
        Write-Host "✅ Authentication mode updated successfully" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Update status: $status" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️  Could not update authentication mode. It may already be configured." -ForegroundColor Yellow
    Write-Host "Error: $_" -ForegroundColor DarkGray
}

Write-Host "`nCreating access entry for user..." -ForegroundColor Cyan
try {
    aws eks create-access-entry `
        --cluster-name $clusterName `
        --region $region `
        --principal-arn $userArn
    
    Write-Host "✅ Access entry created" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Access entry may already exist" -ForegroundColor Yellow
}

Write-Host "`nAssociating admin policy..." -ForegroundColor Cyan
try {
    aws eks associate-access-policy `
        --cluster-name $clusterName `
        --region $region `
        --principal-arn $userArn `
        --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy `
        --access-scope type=cluster
    
    Write-Host "✅ Admin policy associated" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Could not associate policy: $_" -ForegroundColor Yellow
}

Write-Host "`nVerifying access..." -ForegroundColor Cyan
Write-Host "Running: kubectl get nodes" -ForegroundColor DarkGray
Start-Sleep -Seconds 5

kubectl get nodes

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ SUCCESS! You now have access to the EKS cluster" -ForegroundColor Green
} else {
    Write-Host "`n⚠️  Access verification failed. You may need to:" -ForegroundColor Yellow
    Write-Host "1. Wait a few minutes for changes to propagate" -ForegroundColor Yellow
    Write-Host "2. Run: aws eks update-kubeconfig --region $region --name $clusterName" -ForegroundColor Yellow
    Write-Host "3. Contact the cluster administrator to add your user to aws-auth ConfigMap" -ForegroundColor Yellow
}

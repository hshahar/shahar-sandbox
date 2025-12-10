# Karpenter Setup Script - Kubernetes 1.34 Compatible (v1.8.0)
# This script installs Karpenter and applies NodePool configurations

param(
    [string]$ClusterName = "sha-blog-eks",
    [string]$Region = "us-west-2",
    [string]$KarpenterVersion = "1.8.0"
)

Write-Host "Installing Karpenter v$KarpenterVersion for Kubernetes 1.34" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Verify AWS resources are tagged (already done)
Write-Host "Step 1: Verifying AWS resources..." -ForegroundColor Yellow
$subnets = aws eks describe-cluster --name $ClusterName --region $Region --query 'cluster.resourcesVpcConfig.subnetIds[]' --output json | ConvertFrom-Json
Write-Host "Subnets: $($subnets -join ', ')" -ForegroundColor Green
Write-Host ""

# Step 2: Get cluster information
Write-Host "Step 2: Getting cluster information..." -ForegroundColor Yellow
$clusterEndpoint = aws eks describe-cluster --name $ClusterName --region $Region --query 'cluster.endpoint' --output text
$oidcProvider = aws eks describe-cluster --name $ClusterName --region $Region --query 'cluster.identity.oidc.issuer' --output text | ForEach-Object { $_ -replace 'https://', '' }
$accountId = aws sts get-caller-identity --query 'Account' --output text
$nodeRoleArn = "arn:aws:iam::${accountId}:role/sha-blog-eks-general-eks-node-group-20251123071753537600000003"

Write-Host "Cluster Endpoint: $clusterEndpoint" -ForegroundColor Green
Write-Host "OIDC Provider: $oidcProvider" -ForegroundColor Green
Write-Host "Node Role ARN: $nodeRoleArn" -ForegroundColor Green
Write-Host ""

# Step 3: Apply Terraform to install Karpenter
Write-Host "Step 3: Installing Karpenter via Terraform..." -ForegroundColor Yellow
Push-Location "$PSScriptRoot\..\terraform"

terraform apply -auto-approve `
    -var="install_karpenter=true" `
    -var="cluster_name=$ClusterName" `
    -var="cluster_endpoint=$clusterEndpoint" `
    -var="oidc_provider_arn=arn:aws:iam::${accountId}:oidc-provider/${oidcProvider}" `
    -var="oidc_provider=$oidcProvider" `
    -var="node_role_arn=$nodeRoleArn" `
    -var="region=$Region" `
    -var="namespace=sha-dev" `
    -var="environment=dev" `
    -var="ingress_host=sha-dev.blog.local" `
    -var="kube_context=arn:aws:eks:${Region}:${accountId}:cluster/${ClusterName}"

Pop-Location

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to install Karpenter via Terraform" -ForegroundColor Red
    exit 1
}

Write-Host "Karpenter installed successfully!" -ForegroundColor Green
Write-Host ""

# Step 4: Apply Karpenter NodePool configuration
Write-Host "Step 4: Applying Karpenter NodePools..." -ForegroundColor Yellow

# Get node role name
$nodeRoleName = ($nodeRoleArn -split '/')[-1]

# Replace placeholders in nodepool.yaml
$nodepoolPath = "$PSScriptRoot\..\helm\karpenter-nodepool\nodepool.yaml"
$nodepoolContent = Get-Content $nodepoolPath -Raw
$nodepoolContent = $nodepoolContent -replace '\{\{ CLUSTER_NAME \}\}', $ClusterName
$nodepoolContent = $nodepoolContent -replace '\{\{ NODE_ROLE_NAME \}\}', $nodeRoleName

# Apply the configuration
$nodepoolContent | kubectl apply -f -

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to apply Karpenter NodePools" -ForegroundColor Red
    exit 1
}

Write-Host "Karpenter NodePools configured successfully!" -ForegroundColor Green
Write-Host ""

# Step 5: Verify Karpenter installation
Write-Host "Step 5: Verifying Karpenter installation..." -ForegroundColor Yellow
Write-Host ""
Write-Host "Karpenter pods:" -ForegroundColor Cyan
kubectl get pods -n karpenter
Write-Host ""
Write-Host "NodePools:" -ForegroundColor Cyan
kubectl get nodepool -A
Write-Host ""

Write-Host "============================================================" -ForegroundColor Green
Write-Host "Karpenter installation completed!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Monitor Karpenter logs: kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter" -ForegroundColor White
Write-Host "2. Watch node provisioning: kubectl get nodes -w" -ForegroundColor White
Write-Host "3. Check pending pods: kubectl get pods -A" -ForegroundColor White
Write-Host ""

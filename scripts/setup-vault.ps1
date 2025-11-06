# Vault Setup Script
# Initializes and configures HashiCorp Vault for the blog platform

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment = "dev"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " HashiCorp Vault Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check Vault installation
Write-Host "[1/6] Checking Vault installation..." -ForegroundColor Yellow

$vaultPod = kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>$null

if (-not $vaultPod) {
    Write-Host "  ✗ Vault not installed!" -ForegroundColor Red
    Write-Host "    Install with: terraform apply -var-file=environments/$Environment.tfvars" -ForegroundColor Yellow
    exit 1
}

Write-Host "  ✓ Vault pod found: $vaultPod" -ForegroundColor Green

# Wait for Vault to be ready
Write-Host "  Waiting for Vault to be ready..." -ForegroundColor Gray
kubectl wait --for=condition=ready pod -n vault -l app.kubernetes.io/name=vault --timeout=300s
Write-Host "  ✓ Vault is ready!" -ForegroundColor Green
Write-Host ""

# Step 2: Get Vault status
Write-Host "[2/6] Checking Vault status..." -ForegroundColor Yellow

if ($Environment -eq "dev") {
    Write-Host "  ℹ Dev mode detected - Vault runs unsealed" -ForegroundColor Gray
    Write-Host "  ✓ Dev mode: Auto-initialized and unsealed" -ForegroundColor Green
    $vaultToken = "root"
} else {
    # Check if Vault is initialized
    $initStatus = kubectl exec -n vault $vaultPod -- vault status -format=json 2>$null | ConvertFrom-Json
    
    if (-not $initStatus.initialized) {
        Write-Host "  ⚠ Vault not initialized. Initializing..." -ForegroundColor Yellow
        
        # Initialize Vault
        $initOutput = kubectl exec -n vault $vaultPod -- vault operator init -key-shares=1 -key-threshold=1 -format=json | ConvertFrom-Json
        
        $unsealKey = $initOutput.unseal_keys_b64[0]
        $vaultToken = $initOutput.root_token
        
        Write-Host ""
        Write-Host "  ============================================" -ForegroundColor Red
        Write-Host "  IMPORTANT: Save these credentials securely!" -ForegroundColor Red
        Write-Host "  ============================================" -ForegroundColor Red
        Write-Host "  Unseal Key: $unsealKey" -ForegroundColor White
        Write-Host "  Root Token: $vaultToken" -ForegroundColor White
        Write-Host "  ============================================" -ForegroundColor Red
        Write-Host ""
        
        # Unseal Vault
        Write-Host "  Unsealing Vault..." -ForegroundColor Gray
        kubectl exec -n vault $vaultPod -- vault operator unseal $unsealKey
        Write-Host "  ✓ Vault unsealed!" -ForegroundColor Green
    } else {
        Write-Host "  ✓ Vault already initialized" -ForegroundColor Green
        $vaultToken = Read-Host "  Enter Vault root token"
    }
}

Write-Host ""

# Step 3: Enable Kubernetes auth
Write-Host "[3/6] Configuring Kubernetes authentication..." -ForegroundColor Yellow

kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$vaultToken vault auth enable kubernetes 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ℹ Kubernetes auth already enabled" -ForegroundColor Gray
}

# Configure Kubernetes auth
$k8sHost = "https://kubernetes.default.svc:443"
kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$vaultToken vault write auth/kubernetes/config `
    kubernetes_host=$k8sHost `
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt `
    token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token

Write-Host "  ✓ Kubernetes auth configured" -ForegroundColor Green
Write-Host ""

# Step 4: Enable KV v2 secrets engine
Write-Host "[4/6] Enabling secrets engine..." -ForegroundColor Yellow

kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$vaultToken vault secrets enable -path=secret kv-v2 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ℹ KV v2 secrets engine already enabled" -ForegroundColor Gray
} else {
    Write-Host "  ✓ KV v2 secrets engine enabled at path 'secret/'" -ForegroundColor Green
}

Write-Host ""

# Step 5: Create policies
Write-Host "[5/6] Creating Vault policies..." -ForegroundColor Yellow

$policyContent = @"
path "secret/data/$Environment/*" {
  capabilities = ["read", "list"]
}

path "secret/metadata/$Environment/*" {
  capabilities = ["read", "list"]
}
"@

kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$vaultToken vault policy write "$Environment-readonly" - <<< $policyContent

Write-Host "  ✓ Policy '$Environment-readonly' created" -ForegroundColor Green
Write-Host ""

# Step 6: Create Kubernetes role
Write-Host "[6/6] Creating Kubernetes role..." -ForegroundColor Yellow

$namespace = switch ($Environment) {
    "dev" { "dev" }
    "staging" { "staging" }
    "prod" { "production" }
}

kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$vaultToken vault write "auth/kubernetes/role/$Environment-vault-role" `
    bound_service_account_names=default `
    bound_service_account_namespaces=$namespace `
    policies="$Environment-readonly" `
    ttl=24h

Write-Host "  ✓ Kubernetes role '$Environment-vault-role' created" -ForegroundColor Green
Write-Host ""

# Step 7: Create sample secrets
Write-Host "Creating sample secrets..." -ForegroundColor Yellow

# Database secrets
kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$vaultToken vault kv put "secret/$Environment/database" `
    username="bloguser" `
    password="change-me-in-production" `
    database="blogdb"

Write-Host "  ✓ Database secrets created" -ForegroundColor Green

# Backend API secrets
kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$vaultToken vault kv put "secret/$Environment/backend" `
    api_key="sample-api-key-12345" `
    jwt_secret="sample-jwt-secret-67890"

Write-Host "  ✓ Backend API secrets created" -ForegroundColor Green
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Vault Setup Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Vault Access Information:" -ForegroundColor Yellow
if ($Environment -eq "dev") {
    Write-Host "  URL:   http://vault-dev.local" -ForegroundColor White
    Write-Host "  Token: root" -ForegroundColor White
} else {
    Write-Host "  URL:   http://vault-$Environment.local" -ForegroundColor White
    Write-Host "  Token: $vaultToken" -ForegroundColor White
}

Write-Host ""
Write-Host "Secrets Created:" -ForegroundColor Yellow
Write-Host "  secret/$Environment/database" -ForegroundColor White
Write-Host "    - username" -ForegroundColor Gray
Write-Host "    - password" -ForegroundColor Gray
Write-Host "    - database" -ForegroundColor Gray
Write-Host "  secret/$Environment/backend" -ForegroundColor White
Write-Host "    - api_key" -ForegroundColor Gray
Write-Host "    - jwt_secret" -ForegroundColor Gray
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Access Vault UI:   http://vault-$Environment.local" -ForegroundColor White
Write-Host "2. Update secrets:    kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$vaultToken vault kv put secret/$Environment/database password=newsecret" -ForegroundColor White
Write-Host "3. View secrets:      kubectl exec -n vault $vaultPod -- env VAULT_TOKEN=$vaultToken vault kv get secret/$Environment/database" -ForegroundColor White
Write-Host "4. Add to hosts:      Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value '127.0.0.1 vault-$Environment.local'" -ForegroundColor White
Write-Host ""

Write-Host "✓ Vault is ready to use!" -ForegroundColor Green

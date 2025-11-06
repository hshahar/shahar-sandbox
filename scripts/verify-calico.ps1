# Calico Verification Script
# Tests that Calico is installed and NetworkPolicy is enforced

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "staging", "production")]
    [string]$Namespace = "dev"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Calico and NetworkPolicy Verification" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check if Calico is installed
Write-Host "[1/5] Checking Calico installation..." -ForegroundColor Yellow

$calicoNodes = kubectl get pods -n calico-system -l k8s-app=calico-node -o json 2>$null | ConvertFrom-Json

if ($calicoNodes.items.Count -gt 0) {
    Write-Host "  ✓ Calico is installed ($($calicoNodes.items.Count) nodes)" -ForegroundColor Green
    
    foreach ($pod in $calicoNodes.items) {
        $status = $pod.status.phase
        $name = $pod.metadata.name
        if ($status -eq "Running") {
            Write-Host "    ✓ $name : $status" -ForegroundColor Green
        } else {
            Write-Host "    ✗ $name : $status" -ForegroundColor Red
        }
    }
} else {
    Write-Host "  ✗ Calico not found! NetworkPolicy will not work." -ForegroundColor Red
    Write-Host "    Install Calico with: terraform apply -var-file=environments/dev.tfvars" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Step 2: Check Calico API server
Write-Host "[2/5] Checking Calico API server..." -ForegroundColor Yellow

$calicoApiServer = kubectl get pods -n calico-apiserver -o json 2>$null | ConvertFrom-Json

if ($calicoApiServer.items.Count -gt 0) {
    Write-Host "  ✓ Calico API server is running" -ForegroundColor Green
} else {
    Write-Host "  ℹ Calico API server not installed (optional)" -ForegroundColor Gray
}

Write-Host ""

# Step 3: Check NetworkPolicies
Write-Host "[3/5] Checking NetworkPolicies in $Namespace namespace..." -ForegroundColor Yellow

$netpols = kubectl get networkpolicy -n $Namespace -o json 2>$null | ConvertFrom-Json

if ($netpols.items.Count -gt 0) {
    Write-Host "  ✓ Found $($netpols.items.Count) NetworkPolicies:" -ForegroundColor Green
    foreach ($np in $netpols.items) {
        Write-Host "    - $($np.metadata.name)" -ForegroundColor White
    }
} else {
    Write-Host "  ⚠ No NetworkPolicies found in $Namespace" -ForegroundColor Yellow
    Write-Host "    Deploy application first: kubectl apply -f argocd/app-of-apps.yaml" -ForegroundColor Gray
}

Write-Host ""

# Step 4: Test NetworkPolicy enforcement
Write-Host "[4/5] Testing NetworkPolicy enforcement..." -ForegroundColor Yellow

$frontendPod = kubectl get pods -n $Namespace -l app=frontend -o jsonpath='{.items[0].metadata.name}' 2>$null
$backendSvc = "backend.$Namespace.svc.cluster.local"
$dbSvc = "postgresql.$Namespace.svc.cluster.local"

if ($frontendPod) {
    Write-Host "  Testing from frontend pod: $frontendPod" -ForegroundColor Gray
    Write-Host ""
    
    # Test 1: Frontend → Backend (should ALLOW)
    Write-Host "  Test 1: Frontend → Backend (should ALLOW)" -ForegroundColor Cyan
    $result = kubectl exec -n $Namespace $frontendPod -- timeout 3 nc -zv $backendSvc 8080 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✓ PASS: Frontend can reach Backend" -ForegroundColor Green
    } else {
        Write-Host "    ✗ FAIL: Frontend cannot reach Backend" -ForegroundColor Red
    }
    
    Write-Host ""
    
    # Test 2: Frontend → Database (should DENY)
    Write-Host "  Test 2: Frontend → Database (should DENY)" -ForegroundColor Cyan
    $result = kubectl exec -n $Namespace $frontendPod -- timeout 3 nc -zv $dbSvc 5432 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    ✓ PASS: Frontend blocked from Database (expected)" -ForegroundColor Green
    } else {
        Write-Host "    ⚠ FAIL: Frontend can reach Database (NetworkPolicy not working)" -ForegroundColor Red
    }
    
    Write-Host ""
} else {
    Write-Host "  ℹ No frontend pod found. Deploy application first." -ForegroundColor Gray
}

# Step 5: Calico diagnostics
Write-Host "[5/5] Calico diagnostics..." -ForegroundColor Yellow

Write-Host "  Checking Calico configuration..." -ForegroundColor Gray
$calicoConfig = kubectl get installation default -o yaml 2>$null

if ($calicoConfig) {
    Write-Host "  ✓ Calico installation found" -ForegroundColor Green
    
    # Check CNI type
    if ($calicoConfig -match "cni:") {
        Write-Host "    CNI Type: Calico" -ForegroundColor White
    }
    
    # Check IPAM
    if ($calicoConfig -match "ipPools:") {
        Write-Host "    IPAM: Configured" -ForegroundColor White
    }
} else {
    Write-Host "  ℹ Calico CRD not found (using manifest installation)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Verification Complete" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Additional Commands:" -ForegroundColor Yellow
Write-Host "  View Calico logs:        kubectl logs -n calico-system -l k8s-app=calico-node --tail=50" -ForegroundColor Gray
Write-Host "  List NetworkPolicies:    kubectl get networkpolicy -A" -ForegroundColor Gray
Write-Host "  Describe NetworkPolicy:  kubectl describe networkpolicy <name> -n $Namespace" -ForegroundColor Gray
Write-Host "  Calico status:           calicoctl node status" -ForegroundColor Gray
Write-Host ""

# Summary
if ($calicoNodes.items.Count -gt 0 -and $netpols.items.Count -gt 0) {
    Write-Host "✓ Calico is installed and NetworkPolicy is configured!" -ForegroundColor Green
} elseif ($calicoNodes.items.Count -gt 0) {
    Write-Host "⚠ Calico is installed but no NetworkPolicies found" -ForegroundColor Yellow
} else {
    Write-Host "✗ Calico is not installed" -ForegroundColor Red
}

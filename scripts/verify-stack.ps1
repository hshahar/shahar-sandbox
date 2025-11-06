# Verify Complete Stack
# This script verifies all components of the K8s Blog Platform

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment = "dev"
)

$ErrorActionPreference = "Continue"

Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Kubernetes Blog Platform - Full Stack Verification  " -ForegroundColor Cyan
Write-Host "  Environment: $Environment" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$allChecks = @()

function Test-Component {
    param(
        [string]$Name,
        [scriptblock]$Check
    )
    
    Write-Host "🔍 Checking: $Name" -ForegroundColor Yellow
    try {
        $result = & $Check
        if ($result) {
            Write-Host "   ✅ PASS" -ForegroundColor Green
            $script:allChecks += @{ Name = $Name; Status = "PASS" }
            return $true
        } else {
            Write-Host "   ❌ FAIL" -ForegroundColor Red
            $script:allChecks += @{ Name = $Name; Status = "FAIL" }
            return $false
        }
    } catch {
        Write-Host "   ❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $script:allChecks += @{ Name = $Name; Status = "ERROR" }
        return $false
    }
}

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "1️⃣  INFRASTRUCTURE COMPONENTS" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

Test-Component "Kubernetes Cluster" {
    $nodes = kubectl get nodes --no-headers 2>&1
    $nodes -match "Ready"
}

Test-Component "NGINX Ingress Controller" {
    $pods = kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --no-headers 2>&1
    $pods -match "Running"
}

Test-Component "Calico CNI" {
    $pods = kubectl get pods -n calico-system --no-headers 2>&1
    ($pods | Measure-Object).Count -gt 0 -and $pods -match "Running"
}

Test-Component "ArgoCD" {
    $pods = kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server --no-headers 2>&1
    $pods -match "Running"
}

Test-Component "Argo Rollouts" {
    $pods = kubectl get pods -n argo-rollouts --no-headers 2>&1
    $pods -match "Running"
}

Test-Component "Prometheus" {
    $pods = kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus --no-headers 2>&1
    $pods -match "Running"
}

Test-Component "Grafana" {
    $pods = kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana --no-headers 2>&1
    $pods -match "Running"
}

Test-Component "Vault" {
    $pods = kubectl get pods -n vault -l app.kubernetes.io/name=vault --no-headers 2>&1
    $pods -match "Running"
}

Test-Component "External Secrets Operator" {
    $pods = kubectl get pods -n external-secrets-system --no-headers 2>&1
    $pods -match "Running"
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "2️⃣  APPLICATION COMPONENTS ($Environment)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

$namespace = $Environment

Test-Component "Namespace $namespace" {
    $ns = kubectl get namespace $namespace --no-headers 2>&1
    $ns -match "Active"
}

Test-Component "Frontend Deployment" {
    $pods = kubectl get pods -n $namespace -l app=frontend --no-headers 2>&1
    $pods -match "Running"
}

Test-Component "Backend Deployment/Rollout" {
    if ($Environment -ne "dev") {
        # Check for Rollout in staging/prod
        $rollout = kubectl get rollout backend -n $namespace --no-headers 2>&1
        $rollout -match "Healthy"
    } else {
        # Check for Deployment in dev
        $pods = kubectl get pods -n $namespace -l app=backend --no-headers 2>&1
        $pods -match "Running"
    }
}

Test-Component "PostgreSQL StatefulSet" {
    $pods = kubectl get pods -n $namespace -l app=postgresql --no-headers 2>&1
    $pods -match "Running"
}

Test-Component "Services Created" {
    $services = kubectl get svc -n $namespace --no-headers 2>&1
    ($services | Measure-Object).Count -ge 3
}

Test-Component "Ingress Configured" {
    $ingress = kubectl get ingress -n $namespace --no-headers 2>&1
    ($ingress | Measure-Object).Count -gt 0
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "3️⃣  SECURITY FEATURES" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

Test-Component "NetworkPolicy Enforcement" {
    $policies = kubectl get networkpolicy -n $namespace --no-headers 2>&1
    ($policies | Measure-Object).Count -gt 0
}

Test-Component "Pod Security Admission" {
    $ns = kubectl get namespace $namespace -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>&1
    $ns -ne ""
}

Test-Component "Kyverno Policies" {
    $policies = kubectl get clusterpolicy --no-headers 2>&1
    ($policies | Measure-Object).Count -gt 0
}

if ($Environment -ne "dev") {
    Test-Component "Vault Integration" {
        $secrets = kubectl get externalsecret -n $namespace --no-headers 2>&1
        $secrets -match "SecretSynced"
    }
}

Test-Component "Secrets Exist" {
    $secrets = kubectl get secret database-secret -n $namespace --no-headers 2>&1
    $secrets -ne ""
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "4️⃣  MONITORING & OBSERVABILITY" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

Test-Component "ServiceMonitors Created" {
    $monitors = kubectl get servicemonitor -n $namespace --no-headers 2>&1
    ($monitors | Measure-Object).Count -gt 0
}

Test-Component "Grafana Dashboard ConfigMap" {
    $cm = kubectl get configmap grafana-dashboards -n $namespace --no-headers 2>&1
    $cm -ne ""
}

Test-Component "Prometheus Scraping" {
    # Check if Prometheus can reach the metrics endpoint
    $promPod = kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}' 2>&1
    if ($promPod) {
        $targets = kubectl exec -n monitoring $promPod -- wget -q -O- http://localhost:9090/api/v1/targets 2>&1
        $targets -match "up"
    } else {
        $false
    }
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "5️⃣  GITOPS & DEPLOYMENT" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

Test-Component "ArgoCD Application Synced" {
    $appName = "$Environment-microservices-app"
    $app = kubectl get application $appName -n argocd -o jsonpath='{.status.sync.status}' 2>&1
    $app -eq "Synced"
}

Test-Component "ArgoCD Application Healthy" {
    $appName = "$Environment-microservices-app"
    $health = kubectl get application $appName -n argocd -o jsonpath='{.status.health.status}' 2>&1
    $health -eq "Healthy"
}

if ($Environment -ne "dev") {
    Test-Component "Argo Rollouts Configured" {
        $rollout = kubectl get rollout backend -n $namespace --no-headers 2>&1
        $rollout -ne ""
    }
    
    Test-Component "Analysis Templates Exist" {
        $templates = kubectl get analysistemplate -n $namespace --no-headers 2>&1
        ($templates | Measure-Object).Count -gt 0
    }
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "6️⃣  CONNECTIVITY TESTS" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

Test-Component "Frontend Pod Ready" {
    $pod = kubectl get pods -n $namespace -l app=frontend -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>&1
    $pod -eq "True"
}

Test-Component "Backend Pod Ready" {
    $pod = kubectl get pods -n $namespace -l app=backend -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>&1
    $pod -eq "True"
}

Test-Component "Database Pod Ready" {
    $pod = kubectl get pods -n $namespace -l app=postgresql -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>&1
    $pod -eq "True"
}

Test-Component "Backend Health Endpoint" {
    $backendPod = kubectl get pods -n $namespace -l app=backend -o jsonpath='{.items[0].metadata.name}' 2>&1
    if ($backendPod) {
        $health = kubectl exec -n $namespace $backendPod -- wget -q -O- http://localhost:8000/health 2>&1
        $health -ne ""
    } else {
        $false
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  VERIFICATION SUMMARY" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$passCount = ($allChecks | Where-Object { $_.Status -eq "PASS" }).Count
$failCount = ($allChecks | Where-Object { $_.Status -eq "FAIL" }).Count
$errorCount = ($allChecks | Where-Object { $_.Status -eq "ERROR" }).Count
$totalCount = $allChecks.Count

Write-Host "Total Checks: $totalCount" -ForegroundColor White
Write-Host "✅ Passed: $passCount" -ForegroundColor Green
Write-Host "❌ Failed: $failCount" -ForegroundColor Red
Write-Host "⚠️  Errors: $errorCount" -ForegroundColor Yellow
Write-Host ""

$successRate = [math]::Round(($passCount / $totalCount) * 100, 2)
Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 90) { "Green" } elseif ($successRate -ge 70) { "Yellow" } else { "Red" })
Write-Host ""

if ($failCount -gt 0 -or $errorCount -gt 0) {
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Red
    Write-Host "  FAILED CHECKS" -ForegroundColor Red
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Red
    $allChecks | Where-Object { $_.Status -ne "PASS" } | ForEach-Object {
        Write-Host "  • $($_.Name): $($_.Status)" -ForegroundColor $(if ($_.Status -eq "FAIL") { "Red" } else { "Yellow" })
    }
    Write-Host ""
}

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  ACCESS INFORMATION" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

Write-Host "📊 Grafana Dashboard:" -ForegroundColor Green
Write-Host "   URL: http://grafana-$Environment.local" -ForegroundColor White
Write-Host "   Username: admin" -ForegroundColor White
Write-Host "   Password: admin" -ForegroundColor White
Write-Host ""

Write-Host "🔐 ArgoCD UI:" -ForegroundColor Green
Write-Host "   URL: http://argocd-$Environment.local" -ForegroundColor White
Write-Host "   Username: admin" -ForegroundColor White
$argoPass = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>$null | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
if ($argoPass) {
    Write-Host "   Password: $argoPass" -ForegroundColor White
}
Write-Host ""

Write-Host "🚀 Argo Rollouts Dashboard:" -ForegroundColor Green
Write-Host "   Port-forward: kubectl port-forward -n argo-rollouts svc/argo-rollouts-dashboard 3100:3100" -ForegroundColor White
Write-Host "   Then visit: http://localhost:3100" -ForegroundColor White
Write-Host ""

Write-Host "🗄️ Vault UI:" -ForegroundColor Green
Write-Host "   URL: http://vault-$Environment.local" -ForegroundColor White
Write-Host "   Token: root (dev mode)" -ForegroundColor White
Write-Host ""

Write-Host "🌐 Blog Application:" -ForegroundColor Green
$ingressHost = kubectl get ingress -n $namespace -o jsonpath='{.items[0].spec.rules[0].host}' 2>&1
if ($ingressHost) {
    Write-Host "   URL: http://$ingressHost" -ForegroundColor White
}
Write-Host ""

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  USEFUL COMMANDS" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "# Watch pods in $namespace namespace" -ForegroundColor Yellow
Write-Host "kubectl get pods -n $namespace --watch" -ForegroundColor White
Write-Host ""
Write-Host "# Check ArgoCD sync status" -ForegroundColor Yellow
Write-Host "kubectl get applications -n argocd" -ForegroundColor White
Write-Host ""
Write-Host "# View Argo Rollout status (staging/prod)" -ForegroundColor Yellow
Write-Host "kubectl argo rollouts get rollout backend -n $namespace --watch" -ForegroundColor White
Write-Host ""
Write-Host "# Check Calico NetworkPolicies" -ForegroundColor Yellow
Write-Host "kubectl get networkpolicy -n $namespace" -ForegroundColor White
Write-Host ""
Write-Host "# View application logs" -ForegroundColor Yellow
Write-Host "kubectl logs -n $namespace -l app=backend -f" -ForegroundColor White
Write-Host ""

if ($successRate -ge 90) {
    Write-Host "🎉 All systems operational! Platform is ready for use." -ForegroundColor Green
} elseif ($successRate -ge 70) {
    Write-Host "⚠️  Most checks passed, but some components need attention." -ForegroundColor Yellow
} else {
    Write-Host "❌ Multiple issues detected. Please review failed checks above." -ForegroundColor Red
}
Write-Host ""

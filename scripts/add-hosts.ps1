# Add hosts entries for local development - SHA's K8s Blog Platform
# This script must be run as Administrator

param(
    [Parameter(Mandatory=$false)]
    [switch]$Remove
)

$hostsFile = "C:\Windows\System32\drivers\etc\hosts"
$entries = @(
    "127.0.0.1 sha-dev.blog.local",
    "127.0.0.1 sha-argocd-dev.local",
    "127.0.0.1 sha-grafana-dev.local",
    "127.0.0.1 sha-vault-dev.local",
    "127.0.0.1 sha-staging.blog.local",
    "127.0.0.1 sha-grafana-staging.local",
    "127.0.0.1 sha-vault-staging.local",
    "127.0.0.1 sha.blog.local",
    "127.0.0.1 sha-grafana.local",
    "127.0.0.1 sha-vault.local"
)

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "❌ This script must be run as Administrator!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Right-click PowerShell and select 'Run as Administrator', then run this script again." -ForegroundColor Yellow
    exit 1
}

Write-Host "🔧 Hosts File Manager" -ForegroundColor Cyan
Write-Host "=====================" -ForegroundColor Cyan
Write-Host ""

if ($Remove) {
    Write-Host "Removing entries from hosts file..." -ForegroundColor Yellow
    
    $content = Get-Content $hostsFile
    $newContent = $content | Where-Object { 
        $line = $_
        $shouldKeep = $true
        foreach ($entry in $entries) {
            if ($line -eq $entry) {
                $shouldKeep = $false
                break
            }
        }
        $shouldKeep
    }
    
    $newContent | Set-Content $hostsFile
    Write-Host "✅ Entries removed successfully!" -ForegroundColor Green
}
else {
    Write-Host "Adding entries to hosts file..." -ForegroundColor Yellow
    
    $content = Get-Content $hostsFile
    $modified = $false
    
    foreach ($entry in $entries) {
        if ($content -notcontains $entry) {
            Add-Content -Path $hostsFile -Value $entry
            Write-Host "  ✅ Added: $entry" -ForegroundColor Green
            $modified = $true
        }
        else {
            Write-Host "  ⏭️  Already exists: $entry" -ForegroundColor Gray
        }
    }
    
    if ($modified) {
        Write-Host ""
        Write-Host "✅ Hosts file updated successfully!" -ForegroundColor Green
    }
    else {
        Write-Host ""
        Write-Host "✅ All entries already exist!" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Current hosts file entries for myapp.local:" -ForegroundColor Cyan
Get-Content $hostsFile | Select-String "myapp.local" | ForEach-Object {
    Write-Host "  $_" -ForegroundColor Gray
}

Write-Host ""
Write-Host "You can now access:" -ForegroundColor Yellow
Write-Host "  http://dev.myapp.local" -ForegroundColor Cyan
Write-Host "  http://staging.myapp.local" -ForegroundColor Cyan
Write-Host "  http://prod.myapp.local" -ForegroundColor Cyan

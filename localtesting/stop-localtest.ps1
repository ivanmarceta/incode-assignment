param(
    [switch]$DeleteNamespace
)

$ErrorActionPreference = "Stop"

$runtimeDir = Join-Path $PSScriptRoot ".runtime"
$pidFiles = @(
    @{ Name = "prometheus-port-forward"; Path = (Join-Path $runtimeDir "prometheus-port-forward.pid") },
    @{ Name = "grafana-port-forward"; Path = (Join-Path $runtimeDir "grafana-port-forward.pid") },
    @{ Name = "frontend"; Path = (Join-Path $runtimeDir "frontend.pid") },
    @{ Name = "port-forward"; Path = (Join-Path $runtimeDir "port-forward.pid") }
)

foreach ($pidFile in $pidFiles) {
    if (Test-Path $pidFile.Path) {
        $pidValue = Get-Content $pidFile.Path | Select-Object -First 1
        if ($pidValue) {
            try {
                Stop-Process -Id ([int]$pidValue) -Force -ErrorAction Stop
                Write-Host "Stopped $($pidFile.Name) process ($pidValue)."
            } catch {
                Write-Host "$($pidFile.Name) process ($pidValue) was already stopped."
            }
        }

        Remove-Item -LiteralPath $pidFile.Path -Force
    }
}

try {
    & helm uninstall snake-api -n snake-local | Out-Null
    Write-Host "Uninstalled snake-api Helm release."
} catch {
    Write-Host "snake-api Helm release was already absent."
}

try {
    & helm uninstall snake-grafana-dashboards -n monitoring | Out-Null
    Write-Host "Uninstalled snake-grafana-dashboards Helm release."
} catch {
    Write-Host "snake-grafana-dashboards Helm release was already absent."
}

try {
    & helm uninstall monitoring -n monitoring | Out-Null
    Write-Host "Uninstalled monitoring Helm release."
} catch {
    Write-Host "Monitoring Helm release was already absent."
}

if ($DeleteNamespace) {
    Write-Host "Deleting snake-local namespace..."
    & kubectl delete namespace snake-local --ignore-not-found
    Write-Host "Deleting monitoring namespace..."
    & kubectl delete namespace monitoring --ignore-not-found
}

Write-Host "Local test environment stopped."

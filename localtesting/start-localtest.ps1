param(
    [switch]$RebuildImage,
    [switch]$WithMonitoring,
    [int]$ApiPort = 18080,
    [int]$FrontendPort = 4173,
    [int]$GrafanaPort = 13000,
    [int]$PrometheusPort = 19090
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$runtimeDir = Join-Path $PSScriptRoot ".runtime"
$overlayPath = Join-Path $PSScriptRoot "overlay"
$chartPath = Join-Path $root "helm/snake-api"
$dashboardChartPath = Join-Path $root "helm/snake-grafana-dashboards"
$localValuesPath = Join-Path $root "helm/values-local.yaml"
$monitoringValuesPath = Join-Path $root "helm/monitoring-values.yaml"

New-Item -ItemType Directory -Force -Path $runtimeDir | Out-Null

Write-Host "Using workspace: $root"

Write-Host "Checking Minikube status..."
& minikube status | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Minikube is not running. Starting it with the docker driver..."
    & minikube start --driver=docker
}

if ($RebuildImage) {
    Write-Host "Building backend image into Minikube..."
    & minikube image build -t incode-snake-backend:local (Join-Path $root "backend")
}

Write-Host "Applying localtesting overlay..."
& kubectl apply -k $overlayPath

Write-Host "Waiting for PostgreSQL rollout..."
& kubectl rollout status deployment/postgres -n snake-local --timeout=180s

if ($WithMonitoring) {
    Write-Host "Installing Prometheus and Grafana via kube-prometheus-stack..."
    & helm repo add prometheus-community https://prometheus-community.github.io/helm-charts | Out-Null
    & helm repo update | Out-Null
    & helm upgrade --install monitoring prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace -f $monitoringValuesPath
    Write-Host "Installing Grafana dashboards via Helm..."
    & helm upgrade --install snake-grafana-dashboards $dashboardChartPath --namespace monitoring --create-namespace
}

Write-Host "Deploying backend via Helm..."
$helmArgs = @(
    "upgrade",
    "--install",
    "snake-api",
    $chartPath,
    "--namespace",
    "snake-local",
    "--create-namespace",
    "-f",
    $localValuesPath
)

if ($WithMonitoring) {
    $helmArgs += @(
        "--set",
        "monitoring.serviceMonitor.enabled=true"
    )
}

& helm @helmArgs

Write-Host "Waiting for backend rollout..."
& kubectl rollout status deployment/snake-api -n snake-local --timeout=180s

Write-Host "Writing frontend config..."
& (Join-Path $PSScriptRoot "write-frontend-config.ps1") -Port $ApiPort

$portForwardOutLog = Join-Path $runtimeDir "port-forward.out.log"
$portForwardErrLog = Join-Path $runtimeDir "port-forward.err.log"
$frontendOutLog = Join-Path $runtimeDir "frontend.out.log"
$frontendErrLog = Join-Path $runtimeDir "frontend.err.log"
$grafanaOutLog = Join-Path $runtimeDir "grafana-port-forward.out.log"
$grafanaErrLog = Join-Path $runtimeDir "grafana-port-forward.err.log"
$prometheusOutLog = Join-Path $runtimeDir "prometheus-port-forward.out.log"
$prometheusErrLog = Join-Path $runtimeDir "prometheus-port-forward.err.log"
$portForwardPidFile = Join-Path $runtimeDir "port-forward.pid"
$frontendPidFile = Join-Path $runtimeDir "frontend.pid"
$grafanaPidFile = Join-Path $runtimeDir "grafana-port-forward.pid"
$prometheusPidFile = Join-Path $runtimeDir "prometheus-port-forward.pid"

Write-Host "Starting backend port-forward on http://127.0.0.1:$ApiPort ..."
$portForwardProcess = Start-Process -FilePath "powershell" -ArgumentList @(
    "-NoLogo",
    "-NoProfile",
    "-Command",
    "kubectl port-forward svc/snake-api $ApiPort`:80 -n snake-local"
) -WorkingDirectory $root -RedirectStandardOutput $portForwardOutLog -RedirectStandardError $portForwardErrLog -PassThru
Set-Content -LiteralPath $portForwardPidFile -Value $portForwardProcess.Id -Encoding ASCII

Start-Sleep -Seconds 2

Write-Host "Starting frontend server on http://localhost:$FrontendPort ..."
$frontendProcess = Start-Process -FilePath "powershell" -ArgumentList @(
    "-NoLogo",
    "-NoProfile",
    "-Command",
    "python -m http.server $FrontendPort"
) -WorkingDirectory (Join-Path $root "app/public") -RedirectStandardOutput $frontendOutLog -RedirectStandardError $frontendErrLog -PassThru
Set-Content -LiteralPath $frontendPidFile -Value $frontendProcess.Id -Encoding ASCII

if ($WithMonitoring) {
    Write-Host "Starting Grafana port-forward on http://127.0.0.1:$GrafanaPort ..."
    $grafanaProcess = Start-Process -FilePath "powershell" -ArgumentList @(
        "-NoLogo",
        "-NoProfile",
        "-Command",
        "kubectl port-forward svc/monitoring-grafana $GrafanaPort`:80 -n monitoring"
    ) -WorkingDirectory $root -RedirectStandardOutput $grafanaOutLog -RedirectStandardError $grafanaErrLog -PassThru
    Set-Content -LiteralPath $grafanaPidFile -Value $grafanaProcess.Id -Encoding ASCII

    Write-Host "Starting Prometheus port-forward on http://127.0.0.1:$PrometheusPort ..."
    $prometheusProcess = Start-Process -FilePath "powershell" -ArgumentList @(
        "-NoLogo",
        "-NoProfile",
        "-Command",
        "kubectl port-forward svc/monitoring-kube-prometheus-prometheus $PrometheusPort`:9090 -n monitoring"
    ) -WorkingDirectory $root -RedirectStandardOutput $prometheusOutLog -RedirectStandardError $prometheusErrLog -PassThru
    Set-Content -LiteralPath $prometheusPidFile -Value $prometheusProcess.Id -Encoding ASCII
}

Write-Host ""
Write-Host "Local test environment is starting."
Write-Host "Frontend: http://localhost:$FrontendPort"
Write-Host "Backend:  http://127.0.0.1:$ApiPort"
if ($WithMonitoring) {
    Write-Host "Grafana:  http://127.0.0.1:$GrafanaPort"
    Write-Host "Prometheus: http://127.0.0.1:$PrometheusPort"
}
Write-Host ""
Write-Host "Logs:"
Write-Host "  Port-forward stdout: $portForwardOutLog"
Write-Host "  Port-forward stderr: $portForwardErrLog"
Write-Host "  Frontend stdout:     $frontendOutLog"
Write-Host "  Frontend stderr:     $frontendErrLog"
if ($WithMonitoring) {
    Write-Host "  Grafana stdout:      $grafanaOutLog"
    Write-Host "  Grafana stderr:      $grafanaErrLog"
    Write-Host "  Prometheus stdout:   $prometheusOutLog"
    Write-Host "  Prometheus stderr:   $prometheusErrLog"
}
Write-Host ""
Write-Host "To stop everything:"
Write-Host "  .\localtesting\stop-localtest.ps1 -DeleteNamespace"

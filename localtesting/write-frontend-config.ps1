param(
    [string]$Namespace = "snake-local",
    [string]$OutputPath = "app/public/config.js",
    [int]$Port = 18080
)

$serviceUrl = "http://127.0.0.1:$Port"

$targetPath = Join-Path (Get-Location) $OutputPath
$targetDir = Split-Path -Parent $targetPath

if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
}

$content = @"
window.SNAKE_CONFIG = {
  apiBaseUrl: "$serviceUrl"
};
"@

Set-Content -LiteralPath $targetPath -Value $content -Encoding UTF8

Write-Host "Wrote frontend config to $targetPath"
Write-Host "API base URL: $serviceUrl"
Write-Host ""
Write-Host "If you are not using start-localtest.ps1, start the backend tunnel manually:"
Write-Host "kubectl port-forward svc/snake-api $Port`:80 -n $Namespace"

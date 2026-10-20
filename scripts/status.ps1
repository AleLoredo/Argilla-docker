# ==============================================================================
# Estado de la Pila de Argilla (PowerShell / Microsoft Windows)
# ==============================================================================
$ErrorActionPreference = "Continue"
$RootDir = Split-Path -Parent $PSScriptRoot
Set-Location -Path $RootDir

$composeCmd = "docker compose"
try {
    $null = docker compose version 2>&1
    if ($LASTEXITCODE -ne 0) { $composeCmd = "docker-compose" }
} catch {
    $composeCmd = "docker-compose"
}

$port = 6900
$apiKey = "argilla.apikey"
$user = "argilla"

if (Test-Path ".env") {
    $lines = Get-Content ".env"
    foreach ($line in $lines) {
        if ($line -match "^ARGILLA_PORT=(.*)$") { $port = $Matches[1].Trim() }
        if ($line -match "^ARGILLA_API_KEY=(.*)$") { $apiKey = $Matches[1].Trim() }
        if ($line -match "^ARGILLA_USER=(.*)$") { $user = $Matches[1].Trim() }
    }
}

Write-Host "=== Estado de los Contenedores ===" -ForegroundColor Cyan
if ($composeCmd -eq "docker compose") {
    docker compose ps
} else {
    docker-compose ps
}

Write-Host ""
Write-Host "=== Comprobación de Salud del Servicio ===" -ForegroundColor Cyan

$baseUrl = "http://127.0.0.1:$port"
try {
    $versionResp = Invoke-RestMethod -Uri "$baseUrl/api/v1/version" -TimeoutSec 5 -ErrorAction Stop
    Write-Host "[OK] Servidor Web / API respondiendo (HTTP 200)." -ForegroundColor Green
    
    $headers = @{ "X-Argilla-Api-Key" = $apiKey }
    $meResp = Invoke-RestMethod -Uri "$baseUrl/api/v1/me" -Headers $headers -TimeoutSec 5 -ErrorAction Stop
    if ($meResp) {
        Write-Host "[OK] Autenticación con API Key y conexión a Base de Datos correctas." -ForegroundColor Green
    }
    Write-Host "Acceso disponible en: $baseUrl (Usuario: $user)" -ForegroundColor Cyan
} catch {
    Write-Host "[ERROR] No se pudo conectar a Argilla en $baseUrl ($($_.Exception.Message))" -ForegroundColor Red
}

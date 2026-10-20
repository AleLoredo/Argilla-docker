# ==============================================================================
# Iniciar servicios de Argilla (PowerShell / Microsoft Windows)
# ==============================================================================
$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

$composeCmd = "docker compose"
try {
    $null = docker compose version 2>&1
    if ($LASTEXITCODE -ne 0) { $composeCmd = "docker-compose" }
} catch {
    $composeCmd = "docker-compose"
}

Write-Host "Iniciando contenedores de Argilla en Windows..." -ForegroundColor Cyan
if ($composeCmd -eq "docker compose") {
    docker compose up -d
} else {
    docker-compose up -d
}

$port = 6900
if (Test-Path ".env") {
    $portLine = Get-Content ".env" | Where-Object { $_ -match "^ARGILLA_PORT=" }
    if ($portLine) { $port = $portLine.Split("=")[1].Trim() }
}

Write-Host "Servicios iniciados. Acceso disponible en: http://localhost:$port" -ForegroundColor Green

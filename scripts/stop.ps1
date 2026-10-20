# ==============================================================================
# Detener servicios de Argilla (PowerShell / Microsoft Windows)
# ==============================================================================
$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot
Set-Location -Path $RootDir

$composeCmd = "docker compose"
try {
    $null = docker compose version 2>&1
    if ($LASTEXITCODE -ne 0) { $composeCmd = "docker-compose" }
} catch {
    $composeCmd = "docker-compose"
}

Write-Host "Deteniendo contenedores de Argilla (los volúmenes de datos se conservan)..." -ForegroundColor Yellow
if ($composeCmd -eq "docker compose") {
    docker compose stop
} else {
    docker-compose stop
}

Write-Host "[OK] Contenedores de Argilla detenidos." -ForegroundColor Green
Write-Host "Para volver a iniciarlos ejecute: .\scripts\start.ps1" -ForegroundColor Cyan

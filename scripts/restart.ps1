# ==============================================================================
# Reiniciar servicios de Argilla (PowerShell / Microsoft Windows)
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

Write-Host "Reiniciando servicios de Argilla..." -ForegroundColor Cyan
if ($composeCmd -eq "docker compose") {
    docker compose restart
} else {
    docker-compose restart
}

Write-Host "[OK] Servicios reiniciados correctamente." -ForegroundColor Green

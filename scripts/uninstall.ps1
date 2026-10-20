# ==============================================================================
# Desinstalación y Limpieza de Argilla (PowerShell / Microsoft Windows)
# ==============================================================================
[CmdletBinding()]
param (
    [Alias("v")]
    [switch]$Volumes,

    [Alias("y")]
    [switch]$Yes,

    [Alias("h")]
    [switch]$Help
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot
Set-Location -Path $RootDir

if ($Help) {
    Write-Host @"
Uso: .\scripts\uninstall.ps1 [OPCIONES]

Detiene y elimina los contenedores y redes del despliegue de Argilla en Windows.

OPCIONES:
    -Volumes, -v       Eliminar también los volúmenes persistentes (¡ADVERTENCIA: borra datos de anotación!)
    -Yes, -y           Confirmar automáticamente sin preguntar
    -Help, -h          Mostrar esta ayuda y salir
"@
    exit 0
}

$composeCmd = "docker compose"
try {
    $null = docker compose version 2>&1
    if ($LASTEXITCODE -ne 0) { $composeCmd = "docker-compose" }
} catch {
    $composeCmd = "docker-compose"
}

if ($Volumes) {
    if (-not $Yes) {
        Write-Host "[ADVERTENCIA] Se eliminarán TODOS los datos persistentes de la base de datos y de Elasticsearch." -ForegroundColor Red
        $resp = Read-Host "¿Está seguro de que desea continuar? [s/N]"
        if ($resp -notmatch '^(s|si|y|yes)$') {
            Write-Host "Operación cancelada."
            exit 0
        }
    }
    Write-Host "[INFO] Deteniendo contenedores y eliminando redes y volúmenes..." -ForegroundColor Yellow
    if ($composeCmd -eq "docker compose") {
        docker compose down -v --remove-orphans
    } else {
        docker-compose down -v --remove-orphans
    }
    Write-Host "[OK] Contenedores y volúmenes eliminados." -ForegroundColor Green
} else {
    Write-Host "[INFO] Deteniendo contenedores y eliminando redes (los volúmenes se conservan)..." -ForegroundColor Blue
    if ($composeCmd -eq "docker compose") {
        docker compose down --remove-orphans
    } else {
        docker-compose down --remove-orphans
    }
    Write-Host "[OK] Despliegue detenido. Los datos permanecen guardados en volúmenes Docker." -ForegroundColor Green
    Write-Host "[INFO] Para eliminar también los datos, ejecute: .\scripts\uninstall.ps1 -Volumes" -ForegroundColor Cyan
}

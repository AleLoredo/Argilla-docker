# ==============================================================================
# Script de Instalación y Limpieza de Argilla con Docker (Nativo Microsoft Windows)
# ==============================================================================
[CmdletBinding()]
param (
    [Alias("p")]
    [string]$Port = "",

    [Alias("u")]
    [string]$User = "",

    [Alias("pwd", "pass")]
    [string]$Password = "",

    [Alias("k")]
    [string]$ApiKey = "",

    [Alias("w")]
    [string]$Workspace = "",

    [Alias("t")]
    [int]$Timeout = 180,

    [switch]$NoWait,
    [switch]$Clean,
    [switch]$CleanOnly,
    [switch]$KeepData,
    [switch]$Pull,

    [Alias("y")]
    [switch]$Yes,

    [Alias("h")]
    [switch]$Help
)

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

if ($Help) {
    Write-Host @"
Uso: .\install.ps1 [OPCIONES]

Instalador y limpiador inteligente para Argilla en Microsoft Windows mediante Docker y Docker Compose.

OPCIONES DE CONFIGURACIÓN:
    -Port <puerto>          Puerto en el host (por defecto: 6900)
    -User <usuario>         Usuario administrador inicial (por defecto: argilla)
    -Password <clave>       Contraseña administrador inicial (por defecto: 12345678)
    -ApiKey <clave>         Clave de API para autenticación (por defecto: argilla.apikey)
    -Workspace <espacio>    Nombre del espacio de trabajo inicial (por defecto: default)
    -Timeout <segundos>     Tiempo máximo de espera para arranque (por defecto: 180s)
    -NoWait                 No esperar a que los servicios estén listos

OPCIONES DE LIMPIEZA Y DATOS PREVIOS:
    -Clean                  Eliminar automáticamente toda la información anterior y continuar
    -CleanOnly              Solo realizar la limpieza de datos y salir (modo limpiador)
    -KeepData               Conservar datos anteriores sin preguntar
    -Pull                   Forzar la descarga de imágenes aunque existan en la caché local
    -Yes                    Confirmar automáticamente ('Sí') a todas las preguntas
    -Help                   Mostrar esta ayuda y salir

EJEMPLOS:
    .\install.ps1                       # Instalación interactiva / inteligente
    .\install.ps1 -Clean -Yes           # Reinstalación 100% limpia y desatendida
    .\install.ps1 -CleanOnly -Yes       # Usar el script exclusivamente como limpiador
    .\install.ps1 -Port 7000            # Instalación en puerto personalizado
"@
    exit 0
}

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "     INSTALACIÓN Y GESTIÓN DE ARGILLA (MICROSOFT WINDOWS / DOCKER / UGR-NLP)    " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan

# 1. Detección de Arquitectura y Configuración Diferencial
$Arch = $env:PROCESSOR_ARCHITECTURE
Write-Host "[INFO] Plataforma: Microsoft Windows | Arquitectura CPU: $Arch" -ForegroundColor Blue
Write-Host "[INFO] Configuración diferencial aplicada: Perfil estándar Windows (sin banderas de Apple Silicon ARM)." -ForegroundColor Blue

# 2. Comprobar Docker y Docker Compose
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCmd) {
    Write-Host "[ERROR] Docker no está instalado o no se encuentra en el PATH." -ForegroundColor Red
    Write-Host "[ERROR] Por favor, instale Docker Desktop desde https://docs.docker.com/desktop/setup/install/windows-install/" -ForegroundColor Red
    exit 1
}

# Comprobar si el demonio de Docker está activo
try {
    $null = docker info 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Docker daemon not responding" }
    Write-Host "[OK] Docker CLI y servicio/demonio Docker están activos." -ForegroundColor Green
} catch {
    Write-Host "[ERROR] El servicio de Docker Desktop no se está ejecutando." -ForegroundColor Red
    Write-Host "[ERROR] Inicie Docker Desktop en Windows y espere a que el motor arranque completamente." -ForegroundColor Red
    exit 1
}

# Determinar comando de Compose
$composeCmd = ""
try {
    $null = docker compose version 2>&1
    if ($LASTEXITCODE -eq 0) { $composeCmd = "docker compose" }
} catch {}

if (-not $composeCmd) {
    $composeExe = Get-Command docker-compose -ErrorAction SilentlyContinue
    if ($composeExe) {
        $composeCmd = "docker-compose"
    } else {
        Write-Host "[ERROR] Docker Compose no está instalado o habilitado en Docker Desktop." -ForegroundColor Red
        exit 1
    }
}
Write-Host "[OK] Docker Compose detectado ($composeCmd)." -ForegroundColor Green

# 3. Preparar archivo .env
if (-not (Test-Path ".env")) {
    Write-Host "[INFO] Creando archivo de entorno '.env' a partir de '.env.example'..." -ForegroundColor Blue
    Copy-Item ".env.example" ".env"
}

function Set-EnvVar([string]$Key, [string]$Val) {
    $content = Get-Content ".env" -Raw
    $pattern = "(?m)^$Key=.*$"
    if ($content -match $pattern) {
        $content = $content -replace $pattern, "$Key=$Val"
    } else {
        $content += "`n$Key=$Val"
    }
    Set-Content ".env" -Value $content -NoNewline
}

if ($Port) { Set-EnvVar "ARGILLA_PORT" $Port }
if ($User) { Set-EnvVar "ARGILLA_USER" $User }
if ($Password) { Set-EnvVar "ARGILLA_PASSWORD" $Password }
if ($ApiKey) { Set-EnvVar "ARGILLA_API_KEY" $ApiKey }
if ($Workspace) { Set-EnvVar "ARGILLA_WORKSPACE" $Workspace }
# En Windows ES_JAVA_OPTS_EXTRA debe ser vacío para evitar el flag -XX:UseSVE=0
Set-EnvVar "ES_JAVA_OPTS_EXTRA" ""

# Cargar variables de entorno locales
Get-Content ".env" | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
        $parts = $line.Split("=", 2)
        [System.Environment]::SetEnvironmentVariable($parts[0].Trim(), $parts[1].Trim(), "Process")
    }
}

$CurrentPort = if ($env:ARGILLA_PORT) { [int]$env:ARGILLA_PORT } else { 6900 }
$CurrentApiKey = if ($env:ARGILLA_API_KEY) { $env:ARGILLA_API_KEY } else { "argilla.apikey" }
$CurrentUser = if ($env:ARGILLA_USER) { $env:ARGILLA_USER } else { "argilla" }
$CurrentPassword = if ($env:ARGILLA_PASSWORD) { $env:ARGILLA_PASSWORD } else { "12345678" }
$CurrentWorkspace = if ($env:ARGILLA_WORKSPACE) { $env:ARGILLA_WORKSPACE } else { "default" }

# Comprobar disponibilidad del puerto
$portBusy = $false
try {
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $iar = $tcpClient.BeginConnect("127.0.0.1", $CurrentPort, $null, $null)
    $success = $iar.AsyncWaitHandle.WaitOne(800, $false)
    if ($success -and $tcpClient.Connected) {
        $portBusy = $true
        $tcpClient.EndConnect($iar)
    }
    $tcpClient.Close()
} catch {}

if ($portBusy) {
    Write-Host "[AVISO] El puerto $CurrentPort parece estar en uso. Si ya pertenece a Argilla, los contenedores se actualizarán." -ForegroundColor Yellow
} else {
    Write-Host "[OK] Puerto $CurrentPort disponible." -ForegroundColor Green
}

# 4. Detección y gestión de información previa (Volúmenes / Contenedores)
$existingVolumes = @()
try {
    $existingVolumes = (docker volume ls -q --filter "name=argilla" 2>$null) -split "`r?`n" | Where-Object { $_ -ne "" }
} catch {}

$hasExistingData = $false
if ($existingVolumes.Count -gt 0) { $hasExistingData = $true }

$containers = @()
try {
    if ($composeCmd -eq "docker compose") {
        $containers = (docker compose ps -a -q 2>$null) -split "`r?`n" | Where-Object { $_ -ne "" }
    } else {
        $containers = (docker-compose ps -a -q 2>$null) -split "`r?`n" | Where-Object { $_ -ne "" }
    }
} catch {}
if ($containers.Count -gt 0) { $hasExistingData = $true }

$performCleanup = $false

if ($Clean -or $CleanOnly) {
    $performCleanup = $true
} elseif ($KeepData) {
    $performCleanup = $false
    Write-Host "[INFO] Se conservarán los datos y volúmenes anteriores (-KeepData)." -ForegroundColor Blue
} elseif ($hasExistingData) {
    Write-Host ""
    Write-Host "────────────────────────────────────────────────────────────────────────────────" -ForegroundColor Yellow
    Write-Host "                   AVISO: SE DETECTARON ACTIVIDADES PREVIAS                      " -ForegroundColor Yellow
    Write-Host "────────────────────────────────────────────────────────────────────────────────" -ForegroundColor Yellow
    Write-Host "Se detectaron volúmenes de datos o contenedores de una instalación anterior de Argilla."
    Write-Host "Si no se eliminan, las actividades anteriores permanecerán guardadas en la base de datos."
    Write-Host ""

    if ($Yes) {
        $performCleanup = $true
    } else {
        $cleanResp = Read-Host "¿Desea BORRAR toda la información anterior para una instalación 100% limpia? [s/N]"
        if ($cleanResp -match '^(s|si|y|yes)$') {
            $performCleanup = $true
        } else {
            $performCleanup = $false
            Write-Host "[INFO] Se conservarán los datos existentes." -ForegroundColor Blue
        }
    }
}

# Ejecución de la limpieza
if ($performCleanup) {
    Write-Host "[INFO] Deteniendo contenedores y eliminando volúmenes de datos persistentes..." -ForegroundColor Yellow
    if ($composeCmd -eq "docker compose") {
        docker compose down -v --remove-orphans 2>$null
    } else {
        docker-compose down -v --remove-orphans 2>$null
    }

    if ($existingVolumes.Count -gt 0) {
        foreach ($vol in $existingVolumes) {
            docker volume rm -f $vol 2>$null | Out-Null
        }
    }
    Write-Host "[OK] Limpieza completada. Todos los datos, usuarios y anotaciones previas han sido eliminados." -ForegroundColor Green

    if ($CleanOnly) {
        Write-Host "[OK] Modo de solo limpieza finalizado exitosamente. No se iniciará una nueva instalación." -ForegroundColor Green
        exit 0
    }

    if (-not $Yes -and -not $Clean) {
        Write-Host ""
        $contResp = Read-Host "¿Desea proceder ahora con una nueva instalación limpia de Argilla? [S/n]"
        if ($contResp -match '^(n|no)$') {
            Write-Host "[INFO] El instalador actuó como limpiador del sistema. Finalizando sin instalar." -ForegroundColor Blue
            exit 0
        } else {
            Write-Host "[INFO] Continuando con la nueva instalación..." -ForegroundColor Blue
        }
    }
}

# 5. Verificación inteligente y descarga de imágenes
$argillaVersion = if ($env:ARGILLA_VERSION) { $env:ARGILLA_VERSION } else { "latest" }
$requiredImages = @(
    "argilla/argilla-server:$argillaVersion",
    "postgres:14-alpine",
    "docker.elastic.co/elasticsearch/elasticsearch:8.17.0",
    "redis:7-alpine"
)

$missingImages = @()
foreach ($img in $requiredImages) {
    $null = docker image inspect $img 2>&1
    if ($LASTEXITCODE -ne 0) {
        $missingImages += $img
    }
}

if ($Pull) {
    Write-Host "[INFO] Forzando descarga/actualización de imágenes Docker..." -ForegroundColor Blue
    if ($composeCmd -eq "docker compose") { docker compose pull } else { docker-compose pull }
} elseif ($missingImages.Count -gt 0) {
    Write-Host "[INFO] Se detectaron $($missingImages.Count) imagen(es) no disponibles localmente. Descargando..." -ForegroundColor Blue
    foreach ($img in $missingImages) {
        Write-Host "  --> Descargando: $img" -ForegroundColor Cyan
        docker pull $img
    }
} else {
    Write-Host "[OK] Todas las imágenes necesarias se encuentran disponibles en la caché local." -ForegroundColor Green
}

# 6. Levantamiento de la pila de contenedores
Write-Host "[INFO] Levantando la pila de contenedores de Argilla en segundo plano..." -ForegroundColor Blue
if ($composeCmd -eq "docker compose") {
    docker compose up -d
} else {
    docker-compose up -d
}

# 7. Espera activa de preparación de Argilla
if (-not $NoWait) {
    Write-Host "[INFO] Esperando a que el servidor Argilla esté listo en http://127.0.0.1:$CurrentPort (límite: ${Timeout}s)..." -ForegroundColor Blue
    $startTime = [DateTime]::UtcNow
    $isReady = $false

    while (([DateTime]::UtcNow - $startTime).TotalSeconds -lt $Timeout) {
        try {
            $verResp = Invoke-RestMethod -Uri "http://127.0.0.1:$CurrentPort/api/v1/version" -TimeoutSec 3 -ErrorAction Stop
            $authHeaders = @{ "X-Argilla-Api-Key" = $CurrentApiKey }
            $meResp = Invoke-RestMethod -Uri "http://127.0.0.1:$CurrentPort/api/v1/me" -Headers $authHeaders -TimeoutSec 3 -ErrorAction Stop
            if ($meResp) {
                Write-Host ""
                Write-Host "[OK] Argilla está 100% operativo y listo para recibir peticiones en Windows." -ForegroundColor Green
                $isReady = $true
                break
            }
        } catch {
            Write-Host -NoNewline "."
            Start-Sleep -Seconds 3
        }
    }

    if (-not $isReady) {
        Write-Host ""
        Write-Host "[ERROR] Tiempo de espera agotado antes de que Argilla respondiera correctamente." -ForegroundColor Red
        if ($composeCmd -eq "docker compose") {
            docker compose logs --tail=25 argilla elasticsearch
        } else {
            docker-compose logs --tail=25 argilla elasticsearch
        }
        exit 1
    }
}

# 8. Resumen de instalación
Write-Host ""
Write-Host "================================================================================" -ForegroundColor Green
Write-Host "             ¡DESPLIEGUE DE ARGILLA COMPLETADO SATISFACTORIAMENTE!               " -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Green
Write-Host "  Plataforma Host:       Microsoft Windows ($Arch)" -ForegroundColor Cyan
Write-Host "  URL Interfaz Web:      http://localhost:$CurrentPort" -ForegroundColor Cyan
Write-Host "  Endpoint API REST:     http://localhost:$CurrentPort/api/v1" -ForegroundColor Cyan
Write-Host "  Usuario Admin:         $CurrentUser" -ForegroundColor Yellow
Write-Host "  Contraseña Admin:      $CurrentPassword" -ForegroundColor Yellow
Write-Host "  API Key:               $CurrentApiKey" -ForegroundColor Yellow
Write-Host "  Workspace Inicial:     $CurrentWorkspace" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Comandos de gestión rápida en PowerShell:"
Write-Host "    - Ver estado y salud:     .\status.ps1" -ForegroundColor Cyan
Write-Host "    - Detener el servicio:    .\stop.ps1" -ForegroundColor Cyan
Write-Host "    - Iniciar el servicio:    .\start.ps1" -ForegroundColor Cyan
Write-Host "    - Limpieza total:         .\install.ps1 -CleanOnly -Yes" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Green

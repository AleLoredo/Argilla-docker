#!/usr/bin/env bash
# ==============================================================================
# Verificación de Requisitos Previos para Despliegue de Argilla (Multiplataforma)
# Compatible con: macOS, Windows (Git Bash/MSYS/WSL2) y Linux
# ==============================================================================
set -euo pipefail

# Colores para salida de consola
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

ERRORS=0

# 1. Detección de Sistema Operativo y Arquitectura
OS_RAW="$(uname -s 2>/dev/null || echo "Unknown")"
ARCH_RAW="$(uname -m 2>/dev/null || echo "Unknown")"

case "$OS_RAW" in
    Darwin*)
        PLATFORM="macos"
        PLATFORM_NAME="macOS"
        ;;
    Linux*)
        if grep -qi microsoft /proc/version 2>/dev/null; then
            PLATFORM="windows-wsl"
            PLATFORM_NAME="Microsoft Windows (WSL2)"
        else
            PLATFORM="linux"
            PLATFORM_NAME="GNU/Linux"
        fi
        ;;
    MINGW*|MSYS*|CYGWIN*)
        PLATFORM="windows-gitbash"
        PLATFORM_NAME="Microsoft Windows (Git Bash / MSYS)"
        ;;
    *)
        PLATFORM="unknown"
        PLATFORM_NAME="Sistema Desconocido ($OS_RAW)"
        ;;
esac

case "$ARCH_RAW" in
    x86_64|amd64)
        ARCH="x86_64"
        ;;
    arm64|aarch64)
        ARCH="arm64"
        ;;
    *)
        ARCH="$ARCH_RAW"
        ;;
esac

echo -e "${CYAN}${BOLD}[SISTEMA DETECTADO]${NC} Plataforma: ${YELLOW}${PLATFORM_NAME}${NC} | Arquitectura: ${YELLOW}${ARCH}${NC}"

# 2. Comprobar Docker
if command -v docker >/dev/null 2>&1; then
    DOCKER_VERSION=$(docker --version 2>/dev/null || echo "Detectado")
    log_ok "Docker CLI detectado: ${DOCKER_VERSION}"
elif command -v docker.exe >/dev/null 2>&1; then
    DOCKER_VERSION=$(docker.exe --version 2>/dev/null || echo "Detectado")
    log_ok "Docker CLI (Windows) detectado: ${DOCKER_VERSION}"
else
    log_error "Docker no está instalado o no se encuentra en el PATH."
    log_error "Instale Docker Desktop desde https://docs.docker.com/get-docker/"
    ERRORS=$((ERRORS + 1))
fi

# 3. Comprobar Docker Compose (Plugin v2 o Standalone)
COMPOSE_CMD=""
if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
    COMPOSE_VERSION=$(docker compose version 2>/dev/null || echo "")
    log_ok "Docker Compose (plugin v2) detectado: ${COMPOSE_VERSION}"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
    COMPOSE_VERSION=$(docker-compose --version 2>/dev/null || echo "")
    log_ok "Docker Compose (standalone) detectado: ${COMPOSE_VERSION}"
elif command -v docker-compose.exe >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose.exe"
    COMPOSE_VERSION=$(docker-compose.exe --version 2>/dev/null || echo "")
    log_ok "Docker Compose (Windows) detectado: ${COMPOSE_VERSION}"
else
    log_error "Docker Compose no está instalado."
    log_error "Instale Docker Compose desde https://docs.docker.com/compose/install/"
    ERRORS=$((ERRORS + 1))
fi

# 4. Comprobar si el demonio de Docker está activo y respondiendo
if command -v docker >/dev/null 2>&1 || command -v docker.exe >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1 || (command -v docker.exe >/dev/null 2>&1 && docker.exe info >/dev/null 2>&1); then
        log_ok "El servicio/demonio de Docker está activo y respondiendo."
    else
        log_error "El demonio de Docker no se está ejecutando."
        log_error "Por favor, inicie Docker Desktop (en macOS/Windows) o el servicio Docker ('sudo systemctl start docker' en Linux)."
        ERRORS=$((ERRORS + 1))
    fi
fi

# 5. Comprobaciones de memoria para Elasticsearch según el Sistema Operativo
REQUIRED_MAP_COUNT=262144

if [ "$PLATFORM" = "linux" ]; then
    CURRENT_MAP_COUNT=$(sysctl -n vm.max_map_count 2>/dev/null || echo "0")
    if [ "$CURRENT_MAP_COUNT" -lt "$REQUIRED_MAP_COUNT" ]; then
        log_warn "Elasticsearch requiere vm.max_map_count >= ${REQUIRED_MAP_COUNT} (actual: ${CURRENT_MAP_COUNT})."
        if [ "$(id -u)" -eq 0 ]; then
            log_info "Configurando vm.max_map_count=${REQUIRED_MAP_COUNT} automáticamente..."
            sysctl -w vm.max_map_count=${REQUIRED_MAP_COUNT} >/dev/null
            echo "vm.max_map_count=${REQUIRED_MAP_COUNT}" > /etc/sysctl.d/99-argilla-elasticsearch.conf 2>/dev/null || true
            log_ok "vm.max_map_count configurado correctamente."
        elif sudo -n true 2>/dev/null; then
            log_info "Configurando vm.max_map_count=${REQUIRED_MAP_COUNT} con sudo..."
            sudo sysctl -w vm.max_map_count=${REQUIRED_MAP_COUNT} >/dev/null
            echo "vm.max_map_count=${REQUIRED_MAP_COUNT}" | sudo tee /etc/sysctl.d/99-argilla-elasticsearch.conf >/dev/null 2>&1 || true
            log_ok "vm.max_map_count configurado correctamente."
        else
            log_warn "No se tienen permisos de root para configurar vm.max_map_count automáticamente."
            log_warn "Ejecute manualmente: sudo sysctl -w vm.max_map_count=${REQUIRED_MAP_COUNT}"
        fi
    else
        log_ok "vm.max_map_count en Linux es adecuado (${CURRENT_MAP_COUNT} >= ${REQUIRED_MAP_COUNT})."
    fi
elif [ "$PLATFORM" = "windows-wsl" ]; then
    CURRENT_MAP_COUNT=$(sysctl -n vm.max_map_count 2>/dev/null || echo "0")
    if [ "$CURRENT_MAP_COUNT" -lt "$REQUIRED_MAP_COUNT" ]; then
        log_warn "En WSL2, Elasticsearch puede requerir vm.max_map_count >= ${REQUIRED_MAP_COUNT} (actual: ${CURRENT_MAP_COUNT})."
        if sudo -n true 2>/dev/null; then
            sudo sysctl -w vm.max_map_count=${REQUIRED_MAP_COUNT} >/dev/null 2>&1 || true
            log_ok "vm.max_map_count configurado temporalmente en WSL2."
        else
            log_info "Si Elasticsearch falla, configure en PowerShell: wsl -d docker-desktop sysctl -w vm.max_map_count=${REQUIRED_MAP_COUNT}"
        fi
    else
        log_ok "vm.max_map_count en WSL2 es adecuado (${CURRENT_MAP_COUNT} >= ${REQUIRED_MAP_COUNT})."
    fi
elif [ "$PLATFORM" = "windows-gitbash" ]; then
    log_ok "En Microsoft Windows con Docker Desktop, vm.max_map_count es administrado internamente por WSL2."
elif [ "$PLATFORM" = "macos" ]; then
    log_ok "En macOS, Docker Desktop gestiona los límites de memoria en su máquina virtual nativa."
fi

# 6. Comprobar disponibilidad del puerto (Multiplataforma)
TARGET_PORT="${ARGILLA_PORT:-6900}"
IS_PORT_BUSY=0

# Intentar primero con Python (el método más portable entre macOS, Linux y Windows)
CHECK_PYTHON_CMD="import socket, sys; s = socket.socket(socket.AF_INET, socket.SOCK_STREAM); s.settimeout(1); res = s.connect_ex(('127.0.0.1', int('${TARGET_PORT}'))); sys.exit(0 if res == 0 else 1)"

if python3 -c "$CHECK_PYTHON_CMD" 2>/dev/null; then
    IS_PORT_BUSY=1
elif python -c "$CHECK_PYTHON_CMD" 2>/dev/null; then
    IS_PORT_BUSY=1
elif command -v lsof >/dev/null 2>&1; then
    if lsof -i :"$TARGET_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
        IS_PORT_BUSY=1
    fi
elif command -v nc >/dev/null 2>&1; then
    if nc -z 127.0.0.1 "$TARGET_PORT" 2>/dev/null; then
        IS_PORT_BUSY=1
    fi
elif command -v netstat >/dev/null 2>&1; then
    if netstat -an 2>/dev/null | grep -E "(:|\.)${TARGET_PORT}[[:space:]]+.*LISTEN" >/dev/null 2>&1; then
        IS_PORT_BUSY=1
    fi
fi

if [ "$IS_PORT_BUSY" -eq 1 ]; then
    log_warn "El puerto ${TARGET_PORT} parece estar en uso. Si ya pertenece a Argilla, los contenedores se actualizarán."
    log_warn "Si pertenece a otro servicio, configure un puerto alternativo en ARGILLA_PORT dentro de .env."
else
    log_ok "Puerto ${TARGET_PORT} disponible."
fi

# 7. Resumen de validaciones
if [ "$ERRORS" -gt 0 ]; then
    log_error "Se encontraron ${ERRORS} error(es) en los requisitos previos."
    exit 1
fi

log_ok "Todos los requisitos previos se cumplen satisfactoriamente."
exit 0

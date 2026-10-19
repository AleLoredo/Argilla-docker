#!/usr/bin/env bash
# ==============================================================================
# Verificación de Requisitos Previos para Despliegue de Argilla
# ==============================================================================
set -euo pipefail

# Colores para salida de consola
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

ERRORS=0

log_info "Comprobando requisitos del sistema para Argilla..."

# 1. Comprobar Docker
if command -v docker >/dev/null 2>&1; then
    DOCKER_VERSION=$(docker --version 2>/dev/null || echo "Desconocida")
    log_ok "Docker detectado: ${DOCKER_VERSION}"
else
    log_error "Docker no está instalado o no se encuentra en el PATH."
    log_error "Instale Docker desde https://docs.docker.com/get-docker/"
    ERRORS=$((ERRORS + 1))
fi

# 2. Comprobar Docker Compose
COMPOSE_CMD=""
if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
    COMPOSE_VERSION=$(docker compose version 2>/dev/null || echo "")
    log_ok "Docker Compose (plugin v2) detectado: ${COMPOSE_VERSION}"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
    COMPOSE_VERSION=$(docker-compose --version 2>/dev/null || echo "")
    log_ok "Docker Compose (standalone) detectado: ${COMPOSE_VERSION}"
else
    log_error "Docker Compose no está instalado."
    log_error "Instale Docker Compose desde https://docs.docker.com/compose/install/"
    ERRORS=$((ERRORS + 1))
fi

# 3. Comprobar si el demonio de Docker está ejecutándose
if command -v docker >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then
        log_ok "El servicio/demonio de Docker está activo y respondiendo."
    else
        log_error "El demonio de Docker no se está ejecutando."
        log_error "Inicie Docker (Docker Desktop en macOS/Windows o 'sudo systemctl start docker' en Linux)."
        ERRORS=$((ERRORS + 1))
    fi
fi

# 4. Comprobaciones específicas de Linux (Elasticsearch vm.max_map_count)
OS_TYPE="$(uname -s)"
if [ "$OS_TYPE" = "Linux" ]; then
    CURRENT_MAP_COUNT=$(sysctl -n vm.max_map_count 2>/dev/null || echo "0")
    REQUIRED_MAP_COUNT=262144
    if [ "$CURRENT_MAP_COUNT" -lt "$REQUIRED_MAP_COUNT" ]; then
        log_warn "Elasticsearch requiere que 'vm.max_map_count' sea al menos ${REQUIRED_MAP_COUNT} (actual: ${CURRENT_MAP_COUNT})."
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
            log_warn "Por favor ejecute manualmente: sudo sysctl -w vm.max_map_count=${REQUIRED_MAP_COUNT}"
        fi
    else
        log_ok "vm.max_map_count en Linux es adecuado (${CURRENT_MAP_COUNT} >= ${REQUIRED_MAP_COUNT})."
    fi
fi

# 5. Comprobar disponibilidad del puerto
TARGET_PORT="${ARGILLA_PORT:-6900}"
IS_PORT_BUSY=0
if command -v lsof >/dev/null 2>&1; then
    if lsof -i :"$TARGET_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
        IS_PORT_BUSY=1
    fi
elif command -v nc >/dev/null 2>&1; then
    if nc -z 127.0.0.1 "$TARGET_PORT" 2>/dev/null; then
        IS_PORT_BUSY=1
    fi
elif python3 -c "import socket; s = socket.socket(); s.connect(('127.0.0.1', int('$TARGET_PORT')))" 2>/dev/null; then
    IS_PORT_BUSY=1
fi

if [ "$IS_PORT_BUSY" -eq 1 ]; then
    log_warn "El puerto ${TARGET_PORT} parece estar en uso. Si ya pertenece a Argilla, se actualizará el contenedor."
    log_warn "Si pertenece a otro servicio, configure un puerto diferente en ARGILLA_PORT dentro del archivo .env."
else
    log_ok "Puerto ${TARGET_PORT} disponible."
fi

if [ "$ERRORS" -gt 0 ]; then
    log_error "Se encontraron ${ERRORS} error(es) en los requisitos previos."
    exit 1
fi

log_ok "Todos los requisitos previos se cumplen satisfactoriamente."
exit 0

#!/usr/bin/env bash
# ==============================================================================
# Script de Instalación Desatendida de Argilla con Docker
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colores para salida de consola
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

show_help() {
    cat <<EOF
Uso: ./install.sh [OPCIONES]

Instalador desatendido para Argilla mediante Docker y Docker Compose.

OPCIONES:
    -p, --port PUERTO         Puerto en el host (por defecto: 6900)
    -u, --user USUARIO        Usuario administrador inicial (por defecto: argilla)
    -P, --password PASSWORD   Contraseña administrador inicial (por defecto: 12345678)
    -k, --api-key API_KEY     Clave de API para autenticación (por defecto: argilla.apikey)
    -w, --workspace ESPACIO   Nombre del espacio de trabajo inicial (por defecto: default)
    -t, --timeout SEGUNDOS    Tiempo máximo de espera para arranque (por defecto: 180s)
    --no-wait                 No esperar a que los servicios estén listos
    -h, --help                Mostrar esta ayuda y salir

EJEMPLOS:
    ./install.sh                             # Instalación 100% desatendida con valores por defecto
    ./install.sh -p 7000 -P "MiClaveSegura"  # Instalación con puerto y clave personalizados
EOF
}

CUSTOM_PORT=""
CUSTOM_USER=""
CUSTOM_PASS=""
CUSTOM_KEY=""
CUSTOM_WORKSPACE=""
TIMEOUT=180
NO_WAIT=0

while [ $# -gt 0 ]; do
    case "$1" in
        -p|--port)
            CUSTOM_PORT="$2"; shift 2 ;;
        -u|--user)
            CUSTOM_USER="$2"; shift 2 ;;
        -P|--password)
            CUSTOM_PASS="$2"; shift 2 ;;
        -k|--api-key)
            CUSTOM_KEY="$2"; shift 2 ;;
        -w|--workspace)
            CUSTOM_WORKSPACE="$2"; shift 2 ;;
        -t|--timeout)
            TIMEOUT="$2"; shift 2 ;;
        --no-wait)
            NO_WAIT=1; shift ;;
        -h|--help)
            show_help; exit 0 ;;
        *)
            echo -e "${RED}[ERROR]${NC} Opción desconocida: $1"
            show_help
            exit 1
            ;;
    esac
done

echo -e "${CYAN}${BOLD}"
echo "================================================================================"
echo "          INSTALACIÓN DESATENDIDA DE ARGILLA (DOCKER / UGR-NLP)"
echo "================================================================================"
echo -e "${NC}"

# 1. Asegurar archivo .env
if [ ! -f .env ]; then
    echo -e "${BLUE}[INFO]${NC} Creando archivo de entorno '.env' a partir de '.env.example'..."
    cp .env.example .env
fi

# 2. Aplicar sobreescrituras si se pasaron flags
update_env_var() {
    local key="$1"
    local val="$2"
    if [ -n "$val" ]; then
        if grep -q "^${key}=" .env; then
            sed -i.bak "s|^${key}=.*|${key}=${val}|" .env && rm -f .env.bak
        else
            echo "${key}=${val}" >> .env
        fi
    fi
}

update_env_var "ARGILLA_PORT" "$CUSTOM_PORT"
update_env_var "ARGILLA_USER" "$CUSTOM_USER"
update_env_var "ARGILLA_PASSWORD" "$CUSTOM_PASS"
update_env_var "ARGILLA_API_KEY" "$CUSTOM_KEY"
update_env_var "ARGILLA_WORKSPACE" "$CUSTOM_WORKSPACE"

# Cargar variables del entorno
set -a
# shellcheck disable=SC1091
source .env
set +a

# 3. Comprobar requisitos previos
bash ./scripts/check_prerequisites.sh

# 4. Determinar comando de Docker Compose
if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    echo -e "${RED}[ERROR]${NC} Docker Compose no encontrado."
    exit 1
fi

# 5. Descargar imágenes e iniciar servicios en segundo plano
echo -e "${BLUE}[INFO]${NC} Descargando imágenes de Docker necesarias..."
$COMPOSE_CMD pull

echo -e "${BLUE}[INFO]${NC} Levantando la pila de contenedores de Argilla en segundo plano..."
$COMPOSE_CMD up -d

# 6. Esperar a que el servicio esté operativo si no se indicó --no-wait
if [ "$NO_WAIT" -eq 0 ]; then
    bash ./scripts/wait_for_ready.sh "${ARGILLA_PORT:-6900}" "${ARGILLA_API_KEY:-argilla.apikey}" "$TIMEOUT"
fi

# 7. Resumen de instalación
echo ""
echo -e "${GREEN}${BOLD}================================================================================${NC}"
echo -e "${GREEN}${BOLD}             ¡DESPLIEGUE DE ARGILLA COMPLETADO SATISFACTORIAMENTE!               ${NC}"
echo -e "${GREEN}${BOLD}================================================================================${NC}"
echo -e "  ${BOLD}URL Interfaz Web:${NC}      ${CYAN}http://localhost:${ARGILLA_PORT:-6900}${NC}"
echo -e "  ${BOLD}Endpoint API REST:${NC}     ${CYAN}http://localhost:${ARGILLA_PORT:-6900}/api/v1${NC}"
echo -e "  ${BOLD}Usuario Admin:${NC}         ${YELLOW}${ARGILLA_USER:-argilla}${NC}"
echo -e "  ${BOLD}Contraseña Admin:${NC}      ${YELLOW}${ARGILLA_PASSWORD:-12345678}${NC}"
echo -e "  ${BOLD}API Key:${NC}                 ${YELLOW}${ARGILLA_API_KEY:-argilla.apikey}${NC}"
echo -e "  ${BOLD}Workspace Inicial:${NC}     ${YELLOW}${ARGILLA_WORKSPACE:-default}${NC}"
echo ""
echo -e "  ${BOLD}Comandos de gestión rápida:${NC}"
echo -e "    - Ver estado y salud:     ${CYAN}./status.sh${NC}  o  ${CYAN}make status${NC}"
echo -e "    - Consultar logs:         ${CYAN}make logs${NC}"
echo -e "    - Detener el servicio:    ${CYAN}./stop.sh${NC}    o  ${CYAN}make stop${NC}"
echo -e "    - Iniciar el servicio:    ${CYAN}./start.sh${NC}   o  ${CYAN}make start${NC}"
echo -e "    - Probar conexión API:    ${CYAN}bash examples/quick_test.sh${NC}"
echo -e "${GREEN}${BOLD}================================================================================${NC}"

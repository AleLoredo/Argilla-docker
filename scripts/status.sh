#!/usr/bin/env bash
# ==============================================================================
# Estado de la Pila de Argilla
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
elif command -v docker-compose.exe >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose.exe"
else
    echo "Error: Docker Compose no está instalado." >&2
    exit 1
fi

PORT=$(grep '^ARGILLA_PORT=' .env 2>/dev/null | cut -d '=' -f2 || echo "6900")
API_KEY=$(grep '^ARGILLA_API_KEY=' .env 2>/dev/null | cut -d '=' -f2 || echo "argilla.apikey")
USER=$(grep '^ARGILLA_USER=' .env 2>/dev/null | cut -d '=' -f2 || echo "argilla")

echo -e "${CYAN}${BOLD}=== Estado de los Contenedores ===${NC}"
$COMPOSE_CMD ps

echo ""
echo -e "${CYAN}${BOLD}=== Comprobación de Salud del Servicio ===${NC}"

BASE_URL="http://127.0.0.1:${PORT}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/v1/version" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" -eq 200 ]; then
    VERSION_PAYLOAD=$(curl -s "${BASE_URL}/api/v1/version" 2>/dev/null || echo "")
    echo -e "${GREEN}[OK]${NC} Servidor Web / API respondiendo (HTTP 200): ${VERSION_PAYLOAD}"
    
    # Comprobar endpoint autenticado
    ME_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "X-Argilla-Api-Key: ${API_KEY}" "${BASE_URL}/api/v1/me" 2>/dev/null || echo "000")
    if [ "$ME_CODE" -eq 200 ]; then
        echo -e "${GREEN}[OK]${NC} Autenticación con API Key y conexión a Base de Datos correctas."
    else
        echo -e "${YELLOW}[AVISO]${NC} La API Key o la conexión a la base de datos reportó HTTP ${ME_CODE}."
    fi
    echo -e "Acceso disponible en: ${CYAN}${BASE_URL}${NC} (Usuario: ${YELLOW}${USER}${NC})"
elif [ "$HTTP_CODE" -eq 000 ]; then
    echo -e "${RED}[ERROR]${NC} No se puede conectar a Argilla en ${BASE_URL} (¿Contenedores caídos?)."
else
    echo -e "${YELLOW}[AVISO]${NC} El servidor respondió con código HTTP: ${HTTP_CODE}"
fi

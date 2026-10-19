#!/usr/bin/env bash
# ==============================================================================
# Espera activa y desatendida hasta que Argilla esté listo y operativo
# ==============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PORT="${1:-${ARGILLA_PORT:-6900}}"
API_KEY="${2:-${ARGILLA_API_KEY:-argilla.apikey}}"
TIMEOUT="${3:-${WAIT_TIMEOUT:-180}}"

BASE_URL="http://127.0.0.1:${PORT}"
START_TIME=$(date +%s)
ELAPSED=0

echo -e "${BLUE}[INFO]${NC} Esperando a que el servidor Argilla esté listo en ${BASE_URL} (tiempo límite: ${TIMEOUT}s)..."

while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
    # 1. Comprobar endpoint público de versión
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/v1/version" 2>/dev/null || echo "000")
    
    if [ "$HTTP_CODE" -eq 200 ]; then
        # 2. Comprobar autenticación con la API Key
        AUTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "X-Argilla-Api-Key: ${API_KEY}" "${BASE_URL}/api/v1/me" 2>/dev/null || echo "000")
        if [ "$AUTH_CODE" -eq 200 ]; then
            VERSION_INFO=$(curl -s "${BASE_URL}/api/v1/version" 2>/dev/null || echo '{"version":"ok"}')
            echo ""
            echo -e "${GREEN}[OK]${NC} Argilla está 100% operativo y listo para recibir peticiones."
            echo -e "${GREEN}[OK]${NC} Respuesta de versión: ${VERSION_INFO}"
            exit 0
        fi
    fi

    # Mostrar progreso
    printf "."
    sleep 3
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
done

echo ""
echo -e "${RED}[ERROR]${NC} Tiempo de espera agotado (${TIMEOUT}s) antes de que Argilla respondiera correctamente."
echo -e "${YELLOW}[INFO]${NC} Inspeccionando últimos registros de los contenedores..."

if docker compose version >/dev/null 2>&1; then
    docker compose logs --tail=20 argilla elasticsearch || true
elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose logs --tail=20 argilla elasticsearch || true
fi

exit 1

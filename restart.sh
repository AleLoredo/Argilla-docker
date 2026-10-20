#!/usr/bin/env bash
# ==============================================================================
# Reiniciar servicios de Argilla
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

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

echo "Reiniciando servicios de Argilla..."
$COMPOSE_CMD restart

PORT=$(grep '^ARGILLA_PORT=' .env 2>/dev/null | cut -d '=' -f2 || echo "6900")
API_KEY=$(grep '^ARGILLA_API_KEY=' .env 2>/dev/null | cut -d '=' -f2 || echo "argilla.apikey")

if [ -f ./scripts/wait_for_ready.sh ]; then
    bash ./scripts/wait_for_ready.sh "$PORT" "$API_KEY" 60
fi

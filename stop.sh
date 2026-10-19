#!/usr/bin/env bash
# ==============================================================================
# Detener servicios de Argilla sin borrar datos
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    echo "Error: Docker Compose no está instalado." >&2
    exit 1
fi

echo "Deteniendo contenedores de Argilla..."
$COMPOSE_CMD stop
echo "Servicios detenidos correctamente. Los datos persisten en los volúmenes de Docker."

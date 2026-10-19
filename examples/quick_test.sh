#!/usr/bin/env bash
# ==============================================================================
# Prueba Rápida de la API REST de Argilla
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PORT=$(grep '^ARGILLA_PORT=' "$ROOT_DIR/.env" 2>/dev/null | cut -d '=' -f2 || echo "6900")
API_KEY=$(grep '^ARGILLA_API_KEY=' "$ROOT_DIR/.env" 2>/dev/null | cut -d '=' -f2 || echo "argilla.apikey")

BASE_URL="http://127.0.0.1:${PORT}"

echo "===================================================================="
echo "          PROBANDO CONEXIÓN A ARGILLA: ${BASE_URL}"
echo "===================================================================="

echo ""
echo "1. Comprobando versión del servidor (/api/v1/version)..."
curl -s -f "${BASE_URL}/api/v1/version" | python3 -m json.tool || curl -s "${BASE_URL}/api/v1/version"
echo ""

echo "2. Comprobando usuario autenticado (/api/v1/me)..."
curl -s -f -H "X-Argilla-Api-Key: ${API_KEY}" "${BASE_URL}/api/v1/me" | python3 -m json.tool || curl -s -H "X-Argilla-Api-Key: ${API_KEY}" "${BASE_URL}/api/v1/me"
echo ""

echo "3. Comprobando workspaces existentes (/api/v1/workspaces)..."
curl -s -f -H "X-Argilla-Api-Key: ${API_KEY}" "${BASE_URL}/api/v1/workspaces" | python3 -m json.tool || curl -s -H "X-Argilla-Api-Key: ${API_KEY}" "${BASE_URL}/api/v1/workspaces"
echo ""

echo "===================================================================="
echo "                 PRUEBA FINALIZADA CON ÉXITO"
echo "===================================================================="

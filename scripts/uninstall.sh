#!/usr/bin/env bash
# ==============================================================================
# Desinstalación y limpieza de Argilla
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REMOVE_VOLUMES=0
ASSUME_YES=0

show_help() {
    cat <<EOF
Uso: ./scripts/uninstall.sh [OPCIONES]

Detiene y elimina los contenedores y redes del despliegue de Argilla.

OPCIONES:
    -v, --volumes       Eliminar también los volúmenes persistentes (¡ADVERTENCIA: borra datos de anotación!)
    -y, --yes           Confirmar automáticamente sin preguntar
    -h, --help          Mostrar esta ayuda y salir
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        -v|--volumes)
            REMOVE_VOLUMES=1; shift ;;
        -y|--yes)
            ASSUME_YES=1; shift ;;
        -h|--help)
            show_help; exit 0 ;;
        *)
            echo -e "${RED}[ERROR]${NC} Opción desconocida: $1"
            show_help
            exit 1
            ;;
    esac
done

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

if [ "$REMOVE_VOLUMES" -eq 1 ]; then
    if [ "$ASSUME_YES" -eq 0 ]; then
        echo -e "${RED}[ADVERTENCIA]${NC} Se eliminarán TODOS los datos persistentes de la base de datos y de Elasticsearch."
        read -r -p "¿Está seguro de que desea continuar? [s/N]: " RESP
        case "$RESP" in
            [sS][iI]|[sS]|[yY][eE][sS]|[yY]) ;;
            *) echo "Operación cancelada."; exit 0 ;;
        esac
    fi
    echo -e "${YELLOW}[INFO]${NC} Deteniendo contenedores y eliminando redes y volúmenes..."
    $COMPOSE_CMD down -v --remove-orphans
    
    # Limpiar cualquier volumen residual de Argilla
    if command -v docker >/dev/null 2>&1; then
        RESIDUAL_VOLS=$(docker volume ls -q --filter "name=argilla" 2>/dev/null || echo "")
        if [ -n "$RESIDUAL_VOLS" ]; then
            for v in $RESIDUAL_VOLS; do
                docker volume rm -f "$v" >/dev/null 2>&1 || true
            done
        fi
    fi
    echo -e "${GREEN}[OK]${NC} Contenedores y volúmenes eliminados satisfactoriamente."
else
    echo -e "${BLUE}[INFO]${NC} Deteniendo contenedores y eliminando redes (los volúmenes se conservan)..."
    $COMPOSE_CMD down --remove-orphans
    echo -e "${GREEN}[OK]${NC} Despliegue detenido. Los datos permanecen guardados en volúmenes Docker."
    echo -e "${BLUE}[INFO]${NC} Para eliminar también los datos, ejecute: ./scripts/uninstall.sh --volumes"
fi

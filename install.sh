#!/usr/bin/env bash
# ==============================================================================
# Script de Instalación y Limpieza Desatendida de Argilla con Docker
# Compatible con: macOS (Apple Silicon y x86), Microsoft Windows (Git Bash/WSL2) y Linux
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
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

show_help() {
    cat <<EOF
Uso: ./install.sh [OPCIONES]

Instalador y limpiador inteligente para Argilla mediante Docker y Docker Compose.
Detecta automáticamente el sistema operativo (macOS, Windows, Linux) y arquitectura
para aplicar las configuraciones diferenciales requeridas.

OPCIONES DE CONFIGURACIÓN:
    -p, --port PUERTO         Puerto en el host (por defecto: 6900)
    -u, --user USUARIO        Usuario administrador inicial (por defecto: argilla)
    -P, --password PASSWORD   Contraseña administrador inicial (por defecto: 12345678)
    -k, --api-key API_KEY     Clave de API para autenticación (por defecto: argilla.apikey)
    -w, --workspace ESPACIO   Nombre del espacio de trabajo inicial (por defecto: default)
    -t, --timeout SEGUNDOS    Tiempo máximo de espera para arranque (por defecto: 180s)
    --no-wait                 No esperar a que los servicios estén listos

OPCIONES DE LIMPIEZA Y DATOS PREVIOS:
    --clean                   Eliminar automáticamente toda la información anterior y continuar
    --clean-only              Solo realizar la limpieza de datos y salir (modo limpiador)
    --keep-data               Conservar datos anteriores sin preguntar
    --pull                    Forzar la descarga de imágenes aunque existan en la caché local
    -y, --yes                 Responder 'sí' a todas las confirmaciones interactivas
    -h, --help                Mostrar esta ayuda y salir

EJEMPLOS:
    ./install.sh                             # Instalación interactiva / inteligente
    ./install.sh --clean -y                  # Reinstalación 100% limpia y desatendida
    ./install.sh --clean-only -y             # Usar el script exclusivamente como limpiador
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
CLEAN_MODE=""      # "clean", "clean-only", "keep"
FORCE_PULL=0
ASSUME_YES=0

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
        --clean)
            CLEAN_MODE="clean"; shift ;;
        --clean-only)
            CLEAN_MODE="clean-only"; shift ;;
        --keep-data)
            CLEAN_MODE="keep"; shift ;;
        --pull)
            FORCE_PULL=1; shift ;;
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

echo -e "${CYAN}${BOLD}"
echo "================================================================================"
echo "          INSTALACIÓN Y GESTIÓN DE ARGILLA (DOCKER / UGR-NLP)"
echo "================================================================================"
echo -e "${NC}"

# 1. Determinar comando de Docker Compose disponible
if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
elif command -v docker-compose.exe >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose.exe"
else
    echo -e "${RED}[ERROR]${NC} Docker Compose no encontrado. Asegúrese de tener Docker Desktop activo."
    exit 1
fi

# 2. Detección de Sistema Operativo y Arquitectura (Configuración Diferencial)
OS_RAW="$(uname -s 2>/dev/null || echo "Unknown")"
ARCH_RAW="$(uname -m 2>/dev/null || echo "Unknown")"

case "$OS_RAW" in
    Darwin*)
        OS_NAME="macOS"
        ;;
    Linux*)
        if grep -qi microsoft /proc/version 2>/dev/null; then
            OS_NAME="Windows (WSL2)"
        else
            OS_NAME="Linux"
        fi
        ;;
    MINGW*|MSYS*|CYGWIN*)
        OS_NAME="Windows (Git Bash/MSYS)"
        ;;
    *)
        OS_NAME="Desconocido ($OS_RAW)"
        ;;
esac

echo -e "${BLUE}[INFO]${NC} Plataforma: ${YELLOW}${OS_NAME}${NC} | Arquitectura CPU: ${YELLOW}${ARCH_RAW}${NC}"

# Configuración diferencial para JVM de Elasticsearch:
# - Apple Silicon (macOS arm64): Requiere -XX:UseSVE=0 para evitar SIGILL/crash
# - Windows y arquitecturas x86_64: No deben usar -XX:UseSVE=0 ya que provocaría fallo en Java
DIFF_JAVA_OPTS=""
if [ "$OS_RAW" = "Darwin" ] && [ "$ARCH_RAW" = "arm64" ]; then
    DIFF_JAVA_OPTS="-XX:UseSVE=0"
    echo -e "${BLUE}[INFO]${NC} Configuración diferencial aplicada: ${YELLOW}Parámetro ARM SVE para Apple Silicon activado.${NC}"
else
    echo -e "${BLUE}[INFO]${NC} Configuración diferencial aplicada: ${YELLOW}Perfil estándar x86/Windows (sin banderas exclusivas de ARM).${NC}"
fi

# 3. Asegurar y actualizar archivo .env
if [ ! -f .env ]; then
    echo -e "${BLUE}[INFO]${NC} Creando archivo de entorno '.env' a partir de '.env.example'..."
    cp .env.example .env
fi

update_env_var() {
    local key="$1"
    local val="$2"
    if grep -q "^${key}=" .env; then
        sed -i.bak "s|^${key}=.*|${key}=${val}|" .env && rm -f .env.bak
    else
        echo "${key}=${val}" >> .env
    fi
}

[ -n "$CUSTOM_PORT" ] && update_env_var "ARGILLA_PORT" "$CUSTOM_PORT"
[ -n "$CUSTOM_USER" ] && update_env_var "ARGILLA_USER" "$CUSTOM_USER"
[ -n "$CUSTOM_PASS" ] && update_env_var "ARGILLA_PASSWORD" "$CUSTOM_PASS"
[ -n "$CUSTOM_KEY" ] && update_env_var "ARGILLA_API_KEY" "$CUSTOM_KEY"
[ -n "$CUSTOM_WORKSPACE" ] && update_env_var "ARGILLA_WORKSPACE" "$CUSTOM_WORKSPACE"
update_env_var "ES_JAVA_OPTS_EXTRA" "$DIFF_JAVA_OPTS"

# Cargar variables del entorno
set -a
# shellcheck disable=SC1091
source .env
set +a

# 4. Comprobar requisitos previos del sistema
bash ./scripts/check_prerequisites.sh

# 5. Detección y gestión de información previa (Volúmenes / Contenedores de Argilla)
HAS_EXISTING_DATA=0
EXISTING_VOLUMES=""

# Buscar volúmenes pertenecientes al stack de Argilla
if command -v docker >/dev/null 2>&1; then
    EXISTING_VOLUMES=$(docker volume ls -q --filter "name=argilla" 2>/dev/null || echo "")
fi

if [ -n "$EXISTING_VOLUMES" ]; then
    HAS_EXISTING_DATA=1
fi

# Verificar si hay contenedores ya existentes o en ejecución
CONTAINERS_COUNT=$($COMPOSE_CMD ps -a -q 2>/dev/null | wc -l | tr -d ' ' || echo "0")
if [ "$CONTAINERS_COUNT" -gt 0 ]; then
    HAS_EXISTING_DATA=1
fi

PERFORM_CLEANUP=0

if [ "$CLEAN_MODE" = "clean" ] || [ "$CLEAN_MODE" = "clean-only" ]; then
    PERFORM_CLEANUP=1
elif [ "$CLEAN_MODE" = "keep" ]; then
    PERFORM_CLEANUP=0
    echo -e "${BLUE}[INFO]${NC} Se conservarán los datos y volúmenes anteriores (--keep-data)."
elif [ "$HAS_EXISTING_DATA" -eq 1 ]; then
    echo ""
    echo -e "${YELLOW}${BOLD}────────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "${YELLOW}${BOLD}                   AVISO: SE DETECTARON ACTIVIDADES PREVIAS                      ${NC}"
    echo -e "${YELLOW}${BOLD}────────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "Se detectaron volúmenes de datos o contenedores de una instalación anterior de Argilla."
    echo -e "Si no se eliminan, las actividades anteriores permanecerán guardadas en la base de datos."
    echo ""

    if [ "$ASSUME_YES" -eq 1 ]; then
        PERFORM_CLEANUP=1
    else
        read -r -p "¿Desea BORRAR toda la información anterior para una instalación 100% limpia? [s/N]: " CLEAN_RESP
        case "$CLEAN_RESP" in
            [sS][iI]|[sS]|[yY][eE][sS]|[yY])
                PERFORM_CLEANUP=1
                ;;
            *)
                PERFORM_CLEANUP=0
                echo -e "${BLUE}[INFO]${NC} Se conservarán los datos existentes."
                ;;
        esac
    fi
fi

# Ejecutar limpieza si fue seleccionada
if [ "$PERFORM_CLEANUP" -eq 1 ]; then
    echo -e "${YELLOW}[INFO]${NC} Deteniendo contenedores y eliminando volúmenes de datos persistentes..."
    $COMPOSE_CMD down -v --remove-orphans 2>/dev/null || true
    
    # Asegurar borrado de volúmenes con prefijo del proyecto
    if [ -n "$EXISTING_VOLUMES" ]; then
        for vol in $EXISTING_VOLUMES; do
            docker volume rm -f "$vol" >/dev/null 2>&1 || true
        done
    fi
    echo -e "${GREEN}[OK]${NC} Limpieza completada. Todos los datos, usuarios y anotaciones previas han sido eliminados."

    # Si se invocó con --clean-only, finalizar aquí (rol limpiador desatendido)
    if [ "$CLEAN_MODE" = "clean-only" ]; then
        echo -e "${GREEN}${BOLD}[OK] Proceso de limpieza finalizado exitosamente. No se iniciará una nueva instalación.${NC}"
        exit 0
    fi

    # Consultar si desea continuar con la nueva instalación (Rol limpiador interactivo)
    if [ "$ASSUME_YES" -eq 0 ] && [ "$CLEAN_MODE" != "clean" ]; then
        echo ""
        read -r -p "¿Desea proceder ahora con una nueva instalación limpia de Argilla? [S/n]: " CONT_RESP
        case "$CONT_RESP" in
            [nN][oO]|[nN])
                echo -e "${BLUE}[INFO]${NC} El instalador actuó como limpiador del sistema. Finalizando sin instalar."
                exit 0
                ;;
            *)
                echo -e "${BLUE}[INFO]${NC} Continuando con la nueva instalación..."
                ;;
        esac
    fi
fi

# 6. Verificación inteligente y descarga de imágenes
REQUIRED_IMAGES=(
    "argilla/argilla-server:${ARGILLA_VERSION:-latest}"
    "postgres:14-alpine"
    "docker.elastic.co/elasticsearch/elasticsearch:8.17.0"
    "redis:7-alpine"
)

MISSING_IMAGES=()
for img in "${REQUIRED_IMAGES[@]}"; do
    if ! docker image inspect "$img" >/dev/null 2>&1; then
        MISSING_IMAGES+=("$img")
    fi
done

if [ "$FORCE_PULL" -eq 1 ]; then
    echo -e "${BLUE}[INFO]${NC} Forzando descarga/actualización de imágenes Docker..."
    $COMPOSE_CMD pull
elif [ "${#MISSING_IMAGES[@]}" -gt 0 ]; then
    echo -e "${BLUE}[INFO]${NC} Se detectaron ${#MISSING_IMAGES[@]} imagen(es) no disponibles localmente. Descargando..."
    for img in "${MISSING_IMAGES[@]}"; do
        echo -e "${CYAN}  --> Descargando: ${img}${NC}"
        docker pull "$img"
    done
else
    echo -e "${GREEN}[OK]${NC} Todas las imágenes de Docker necesarias se encuentran disponibles en la caché local."
fi

# 7. Levantamiento de la pila de contenedores
echo -e "${BLUE}[INFO]${NC} Levantando la pila de contenedores de Argilla en segundo plano..."
$COMPOSE_CMD up -d

# 8. Esperar a que el servicio esté operativo si no se indicó --no-wait
if [ "$NO_WAIT" -eq 0 ]; then
    bash ./scripts/wait_for_ready.sh "${ARGILLA_PORT:-6900}" "${ARGILLA_API_KEY:-argilla.apikey}" "$TIMEOUT"
fi

# 9. Resumen de instalación
echo ""
echo -e "${GREEN}${BOLD}================================================================================${NC}"
echo -e "${GREEN}${BOLD}             ¡DESPLIEGUE DE ARGILLA COMPLETADO SATISFACTORIAMENTE!               ${NC}"
echo -e "${GREEN}${BOLD}================================================================================${NC}"
echo -e "  ${BOLD}Plataforma Host:${NC}       ${CYAN}${OS_NAME} (${ARCH_RAW})${NC}"
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
echo -e "    - Limpieza total:         ${CYAN}./install.sh --clean-only -y${NC}"
echo -e "    - Probar conexión API:    ${CYAN}bash examples/quick_test.sh${NC}"
echo -e "${GREEN}${BOLD}================================================================================${NC}"

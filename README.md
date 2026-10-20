# Despliegue Desatendido de Argilla con Docker

Este repositorio proporciona una solución robusta y completamente automatizada para la **instalación desatendida de la plataforma de anotación [Argilla](https://argilla.io/)** utilizando **Docker** y **Docker Compose**.

Diseñado para despliegues en servidores, entornos locales de desarrollo y laboratorios docentes (UGR-NLP).

---

##  Arquitectura del Despliegue

La pila se compone de servicios aislados y coordinados mediante comprobaciones de salud (*healthchecks*):

```mermaid
graph TD
    User["👤 Usuario / Navegador Web"] -->|Puerto 6900| ArgillaServer["🚀 Argilla Server (FastAPI)"]
    SDK["🐍 Python SDK / REST API"] -->|Puerto 6900| ArgillaServer
    
    subgraph Docker Network [Red Docker Interna: argilla-net]
        ArgillaServer -->|Almacenamiento relacional| Postgres[("🐘 PostgreSQL 14")]
        ArgillaServer -->|Indexación y Búsqueda| Elastic[("🔍 Elasticsearch 8")]
        ArgillaServer -->|Cola de tareas| Redis[("⚡ Redis 7")]
        
        Worker["⚙️ Argilla Background Worker"] --> Redis
        Worker --> Postgres
        Worker --> Elastic
    end

    Postgres --> VolPG[("💾 postgresdata")]
    Elastic --> VolES[("💾 elasticdata")]
    ArgillaServer --> VolArg[("💾 argilladata")]
    Redis --> VolRed[("💾 redisdata")]
```

---

## ⚡ Requisitos Previos

- **Docker Engine** (v20.10 o superior)
- **Docker Compose** (plugin v2 o standalone)
- **Memoria RAM disponible:** Mínimo 2 GB libres (Elasticsearch y Argilla).

---

## 🚀 Instalación y Despliegue Multiplataforma

El instalador detecta automáticamente si el sistema es **macOS** (Apple Silicon / Intel), **Microsoft Windows** (PowerShell, Git Bash o WSL2) o **GNU/Linux**, aplicando las configuraciones diferenciales necesarias (por ejemplo, deshabilitando banderas exclusivas de procesadores ARM en máquinas x86/Windows para evitar fallos de Java).

### En macOS y Linux (Bash / Make)

```bash
# Instalación estándar interactiva / desatendida
./install.sh

# O mediante make:
make install
```

### En Microsoft Windows (PowerShell Nativo)

Abra PowerShell en la carpeta del proyecto y ejecute:

```powershell
.\install.ps1
```

> [!TIP]
> Si la política de ejecución de PowerShell bloquea los scripts locales, ejecute:  
> `powershell -ExecutionPolicy Bypass -File .\install.ps1`

También puede utilizar **Git Bash** o **WSL2** en Windows ejecutando directamente `./install.sh`.

---

## 🧹 Rol Dual: Instalador y Limpiador de Datos Anteriores

Una causa habitual de confusión al trabajar con Argilla es que al eliminar o detener el contenedor, **las actividades y anotaciones previas persisten en los volúmenes de Docker**.

El nuevo proceso de instalación detecta si existen actividades previas y ofrece gestionarlas:

1. **Detección inteligente de datos:** Detecta si existen volúmenes persistentes de bases de datos (`postgresdata`, `elasticdata`, `redisdata`, `argilladata`).
2. **Opción de limpieza total:** Pregunta al usuario si desea eliminar toda la información anterior para comenzar desde cero.
3. **Rol como "Limpiador" independiente:** Tras la limpieza, pregunta si desea proceder con una nueva instalación o si solo deseaba limpiar el sistema (`[S/n]`).
4. **Descarga selectiva:** Comprueba si las imágenes ya existen en la caché local de Docker antes de descargarlas, evitando transferencias innecesarias de red.

### Comandos de Limpieza Rápida:

```bash
# En macOS / Linux / Git Bash:
./install.sh --clean -y         # Reinstalación 100% limpia y desatendida (elimina datos previos)
./install.sh --clean-only -y    # Usar como LIMPIADOR exclusivo (borra datos y finaliza sin instalar)
make clean-install              # Vía Makefile: reinstalación desde cero
make clean-only                 # Vía Makefile: limpiador exclusivo

# En Microsoft Windows (PowerShell):
.\install.ps1 -Clean -Yes       # Reinstalación 100% limpia
.\install.ps1 -CleanOnly -Yes   # Limpiador exclusivo (borra volúmenes y finaliza)
```


---

## 🔑 Credenciales y Acceso por Defecto

Una vez completada la instalación, acceda a través de su navegador web:

- **URL de la Interfaz Web:** [http://localhost:6900](http://localhost:6900)
- **Endpoint API REST:** [http://localhost:6900/api/v1](http://localhost:6900/api/v1)
- **Usuario:** `argilla`
- **Contraseña:** `12345678`
- **API Key:** `argilla.apikey`
- **Espacio de trabajo (Workspace):** `default`

---

## 🔧 Gestión del Dataset y Anotaciones (Scripts Python)

Para trabajar con el dataset de evaluación (`telco_multitask_evaluation`), se proporcionan scripts en Python para la preparación, carga, verificación del progreso de anotación y exportación de datos.

### 1. Preparación del Entorno Virtual

```bash
# Crear el venv local
python3 -m venv .venv

# Activar el entorno
source .venv/bin/activate

# Instalar dependencias
pip install --upgrade pip
pip install argilla
```

### 2. Scripts Disponibles

#### `upload_to_argilla.py` (Carga inicial)
Carga el conjunto de datos desde `train-dataset1/train.jsonl` en Argilla bajo el nombre `telco_multitask_evaluation`. Configura dinámicamente las preguntas del dataset (`choice`, `noul`, `score`), añade metadatos y asigna sugerencias iniciales a cada registro.
```bash
python upload_to_argilla.py
```

#### `comprobar.py` (Verificación de estado de anotación)
Comprueba el estado del dataset `telco_multitask_evaluation` en la base de datos de Argilla. Realiza las siguientes tareas:
- **Conteo de registros anotados:** Contabiliza los registros que ya tienen respuestas guardadas (`responses`).
- **Conteo de registros pendientes:** Identifica los registros que aún no han sido respondidos.
- **Identificación de anotadores:** Lista los identificadores únicos (`user_id`) de los usuarios que han enviado respuestas.
- Imprime un resumen del progreso por consola para seguimiento rápido sin necesidad de acceder a la interfaz web.
```bash
python comprobar.py
```

#### `exportarr-anotados.py` (Exportación de datos anotados)
Extrae las respuestas guardadas del dataset `telco_multitask_evaluation` y genera un dataset limpio y estructurado para su posterior uso o entrenamiento:
- **Mapeo de respuestas por tarea (*primitive*):**
  - `choice`: Extrae la selección del departamento (`department`).
  - `noul`: Extrae y convierte a entero la confirmación binaria (`binary_confirmation`).
  - `score`: Extrae y convierte a entero el nivel de frustración (`frustration_score`).
- **Mecanismo de respaldo (*fallback*):** Si un registro no tiene una respuesta guardada por un usuario, recupera el valor de las sugerencias (`suggestions`).
- **Exportación a JSONL:** Guarda los registros procesados en `train-dataset1/train_annotated.jsonl` con los campos `id`, `primitive`, `state`, `question` (tipo e instrucciones), `target` y `status`.
```bash
python exportarr-anotados.py
```

---

## ⚙️ Opciones de Personalización

Puede personalizar los parámetros pasando argumentos al instalador o modificando el archivo `.env`:

### Parámetros de línea de comandos en `install.sh` y `install.ps1`

```bash
# macOS / Linux / Git Bash:
./install.sh -p 7000 -P "MiClaveSuperSegura" -k "mi.clave.api.personalizada" -w "mi-workspace"

# Microsoft Windows (PowerShell):
.\install.ps1 -Port 7000 -Password "MiClaveSuperSegura" -ApiKey "mi.clave.api.personalizada"
```

| Opción Bash | Opción PowerShell | Descripción | Valor por defecto |
| :--- | :--- | :--- | :--- |
| `-p`, `--port` | `-Port` | Puerto expuesto en el host | `6900` |
| `-u`, `--user` | `-User` | Nombre del usuario administrador | `argilla` |
| `-P`, `--password` | `-Password` | Contraseña del usuario administrador | `12345678` |
| `-k`, `--api-key` | `-ApiKey` | API Key para autenticación en clientes | `argilla.apikey` |
| `-w`, `--workspace` | `-Workspace` | Espacio de trabajo inicial | `default` |
| `-t`, `--timeout` | `-Timeout` | Tiempo máximo de espera en segundos para arranque | `180` |
| `--clean` | `-Clean` | Borra datos/volúmenes previos y reinstala | Desactivado |
| `--clean-only` | `-CleanOnly` | Modo limpiador: solo borra datos previos y finaliza | Desactivado |
| `--keep-data` | `-KeepData` | Conserva datos anteriores sin consultar al usuario | Desactivado |
| `--pull` | `-Pull` | Fuerza descarga de imágenes aunque existan en local | Desactivado |
| `-y`, `--yes` | `-Yes` | Responde automáticamente 'Sí' a las confirmaciones | Desactivado |
| `--no-wait` | `-NoWait` | No esperar a que los servicios estén listos | Desactivado |
| `-h`, `--help` | `-Help` | Muestra la ayuda en pantalla | — |

### Variables de Entorno (`.env`)

El archivo `.env` permite configurar ajustes adicionales:

```env
ARGILLA_VERSION=latest
ARGILLA_PORT=6900
ARGILLA_USER=argilla
ARGILLA_PASSWORD=12345678
ARGILLA_API_KEY=argilla.apikey
ARGILLA_WORKSPACE=default
HF_HUB_DISABLE_TELEMETRY=1
BACKGROUND_NUM_WORKERS=2
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=argilla
ES_HEAP_SIZE=512m
# Configurado automáticamente por el instalador (-XX:UseSVE=0 para Apple Silicon)
ES_JAVA_OPTS_EXTRA=
```

---

## 🛠️ Comandos de Gestión y Mantenimiento

Se incluyen scripts tanto para Unix/Bash como para PowerShell (Windows) y atajos de `Makefile`:

| Acción | Bash (macOS/Linux) | PowerShell (Windows) | Vía Make | Descripción |
| :--- | :--- | :--- | :--- | :--- |
| **Instalación estándar** | `./install.sh` | `.\install.ps1` | `make install` | Instalación guiada / inteligente |
| **Instalación limpia** | `./install.sh --clean -y` | `.\install.ps1 -Clean -Yes` | `make clean-install` | Borra datos previos y reinstala |
| **Limpiador exclusivo** | `./install.sh --clean-only -y`| `.\install.ps1 -CleanOnly -Yes` | `make clean-only` | Saneamiento total de datos previos |
| **Iniciar** | `./start.sh` | `.\start.ps1` | `make start` | Inicia contenedores existentes |
| **Detener** | `./stop.sh` | `.\stop.ps1` | `make stop` | Pausa contenedores (los datos se conservan) |
| **Reiniciar** | `./restart.sh` | `.\restart.ps1` | `make restart` | Reinicia todos los servicios |
| **Consultar estado** | `./status.sh` | `.\status.ps1` | `make status` | Muestra estado de contenedores y salud del API |
| **Ver logs** | `docker compose logs -f` | `docker compose logs -f` | `make logs` | Registros en tiempo real de todos los servicios |
| **Logs del servidor** | `docker compose logs -f argilla` | `docker compose logs -f argilla` | `make logs-server` | Registros del backend Argilla |
| **Logs de Elasticsearch** | `docker compose logs -f elasticsearch` | `docker compose logs -f elasticsearch` | `make logs-es` | Registros de Elasticsearch |
| **Probar API REST** | `bash examples/quick_test.sh` | `Invoke-RestMethod ...` | `make test` | Prueba de endpoints |
| **Probar cliente Python**| `python3 examples/test_client.py` | `python examples\test_client.py` | `make test-python` | Validación con SDK Python |
| **Desinstalar (conservar datos)** | `./uninstall.sh` | `.\uninstall.ps1` | `make clean` | Elimina contenedores y redes |
| **Desinstalación total** | `./uninstall.sh --volumes --yes` | `.\uninstall.ps1 -Volumes -Yes` | `make clean-all` | Elimina contenedores y **volúmenes de datos** |

---

## 🧪 Pruebas y Validación

### 1. Prueba rápida de API (sin dependencias externas)
```bash
make test
```
Verifica la disponibilidad de `/api/v1/version`, el usuario autenticado `/api/v1/me` y los workspaces disponibles.

### 2. Uso mediante el SDK oficial de Argilla (Python)
Para interactuar con Argilla desde scripts o notebooks en Python:

```bash
pip install argilla
```

```python
import argilla as rg

# Inicialización del cliente en Argilla v2
client = rg.Argilla(api_url="http://localhost:6900", api_key="argilla.apikey")

# Listar espacios de trabajo
workspaces = list(client.workspaces)
print(f"Workspaces disponibles: {[ws.name for ws in workspaces]}")
```

Puede ejecutar el script de prueba incluido:
```bash
make test-python
```

---

## ❓ Solución de Problemas Frecuentes

### 1. Elasticsearch falla al iniciar en Linux (`max virtual memory areas vm.max_map_count [65530] is too low`)
Elasticsearch requiere un valor mínimo de `262144` para `vm.max_map_count`. El script `install.sh` intenta aplicarlo automáticamente. Si es necesario aplicarlo manualmente:
```bash
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.d/99-argilla.conf
```

### 2. El puerto 6900 ya está en uso
Cambie el puerto en el archivo `.env` o páselo como parámetro:
```bash
./install.sh -p 7000
```
Y acceda a través de `http://localhost:7000`.

### 3. El demonio de Docker no está activo
En macOS o Windows, inicie la aplicación Docker Desktop. En Linux:
```bash
sudo systemctl start docker
```

---

## 📄 Licencia

Este proyecto está bajo la licencia [MIT](LICENSE).
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

El instalador desatendido [install.ps1] está optimizado para entornos nativos de Microsoft Windows (PowerShell 5.1 y PowerShell 7+):
- **Parámetros no sensibles a mayúsculas/minúsculas:** Compatible con la convención de PowerShell (`-Port`, `-Password` / `-pwd` / `-pass`, `-ApiKey`, `-Workspace`, `-Clean`, etc.).
- **Gestión automática de Docker Desktop:** Comprueba el estado del demonio Docker y de Docker Compose sin requerir herramientas Unix externas.
- **Configuración diferencial:** Aplica el perfil de JVM adecuado para Windows/x86_64 evitando parámetros incompatibles de procesadores ARM.

Abra PowerShell en la carpeta del proyecto y ejecute:

```powershell
.\install.ps1
```

> [!TIP]
> Si la directiva de ejecución de PowerShell restringe la ejecución de scripts locales, ejecute:  
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

## 🔧 Gestión de Datasets y Operaciones con Cuadernos Jupyter

El proyecto utiliza **Jupyter Notebooks** interactivos para todas las tareas de gestión de datasets, carga de datos, exportación de anotaciones y administración de usuarios en Argilla.

### 1. Entorno Virtual y Dependencias

Para mantener el despliegue desacoplado y portable, **el instalador (`install.sh` / `install.ps1`) se enfoca exclusivamente en la orquestación del stack de contenedores Docker**.

La instalación de las librerías cliente (`argilla` y `requests`, definidas en [requirements.txt] se realiza de forma autónoma en la **primera celda de cada cuaderno Jupyter** mediante:

```python
%pip install -r requirements.txt
```

De esta manera, las dependencias se instalan directamente en el kernel o entorno virtual (`.venv` u otro) en el que decidas ejecutar los cuadernos, evitando interferencias con el sistema operativo host.

Si prefieres preparar un entorno virtual manualmente desde la terminal:

```bash
# 1. Crear el venv local
python3 -m venv .venv

# 2. Activar el entorno
# En macOS / Linux:
source .venv/bin/activate
# En Windows (PowerShell):
.\.venv\Scripts\Activate.ps1

# 3. Instalar dependencias
pip install -r requirements.txt
pip install jupyter datasets
```

---

### 2. Cuadernos Interactivos Disponibles (Carpeta `notebooks/`)

#### 📓 [notebooks/cargar-datos-jsonl.ipynb](notebooks/cargar-datos-jsonl.ipynb): Creación, Carga y Exportación desde JSONL
Cuaderno integral preparado para gestionar el ciclo de anotación local a partir del dataset multirareo (`train.jsonl`):
- **Celda 1:** Instalación de dependencias (`%pip install -r ../requirements.txt`).
- **Celda 2 (Creación del Dataset y Carga):**
  - Lee y valida el archivo `train-dataset1/train.jsonl`.
  - Descubre dinámicamente las etiquetas correspondientes a las tareas de tipo `choice`.
  - Construye el esquema del dataset en Argilla (`telco_multitask_evaluation_v3`) definiendo directrices, campos de texto (`text`, `task_instructions`, `criteria_guide`) y preguntas (`review_status`, `department`, `binary_confirmation`, `frustration_score`).
  - Envía los registros en lotes de 100 (*batches*) con sugerencias iniciales precargadas para acelerar el proceso de etiquetado.
- **Celda 3 (Exportación de Anotaciones Curadas):**
  - Extrae todos los registros que cuentan con respuestas enviadas por los anotadores (`with_responses=True`).
  - Genera y guarda el dataset resultante en formato estructurado dentro del archivo local `train-dataset1/annotated.jsonl`.

#### 📓 [notebooks/cargar-datos-hf.ipynb](notebooks/cargar-datos-hf.ipynb): Carga de Datasets Públicos de Hugging Face
Permite volcar registros desde cualquier dataset público alojado en [Hugging Face](https://huggingface.co/datasets) (por ejemplo, `FineEnvs/openai-math` u otros conjuntos de datos) hacia su contenedor correspondiente en Argilla.

**Flujo de trabajo:**
1. **Creación previa del contenedor en la UI:** Abra la interfaz web de Argilla (`http://localhost:6900`), inicie sesión y seleccione la opción **"Import from Hugging Face"**. Indique el identificador del repositorio para que Argilla configure automáticamente la plantilla y los campos.
2. **Carga y sincronización vía Notebook:** Abra el cuaderno y ejecute la celda. El código descarga el split deseado con `datasets.load_dataset(...)`, conecta con el servidor y añade masivamente los registros al dataset mediante `dataset.records.log(ds, mapping={})`.

#### 📓 [notebooks/comandos-varios.ipynb](notebooks/comandos-varios.ipynb): Administración de Usuarios y Workspaces
Cuaderno para operaciones administrativas y de control de acceso:
- **Creación de usuarios:** Permite registrar nuevos usuarios con credenciales y roles específicos (`annotator` o `admin`) mediante la clase `rg.User`.
- **Asignación a Espacios de Trabajo:** Vincula usuarios existentes a un espacio de trabajo determinado (por defecto, `default`) mediante `user.add_to_workspace(...)` para habilitar su acceso a los datasets correspondientes.



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
| `-P`, `--password` | `-Password` (alias: `-pwd`, `-pass`) | Contraseña del usuario administrador | `12345678` |
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
| **Iniciar** | `./scripts/start.sh` | `.\scripts\start.ps1` | `make start` | Inicia contenedores existentes |
| **Detener** | `./scripts/stop.sh` | `.\scripts\stop.ps1` | `make stop` | Pausa contenedores (los datos se conservan) |
| **Reiniciar** | `./scripts/restart.sh` | `.\scripts\restart.ps1` | `make restart` | Reinicia todos los servicios |
| **Consultar estado** | `./scripts/status.sh` | `.\scripts\status.ps1` | `make status` | Muestra estado de contenedores y salud del API |
| **Ver logs** | `docker compose logs -f` | `docker compose logs -f` | `make logs` | Registros en tiempo real de todos los servicios |
| **Logs del servidor** | `docker compose logs -f argilla` | `docker compose logs -f argilla` | `make logs-server` | Registros del backend Argilla |
| **Logs de Elasticsearch** | `docker compose logs -f elasticsearch` | `docker compose logs -f elasticsearch` | `make logs-es` | Registros de Elasticsearch |
| **Probar API REST** | `bash examples/quick_test.sh` | `Invoke-RestMethod ...` | `make test` | Prueba de endpoints |
| **Probar cliente Python**| `python3 examples/test_client.py` | `python examples\test_client.py` | `make test-python` | Validación con SDK Python |
| **Desinstalar (conservar datos)** | `./scripts/uninstall.sh` | `.\scripts\uninstall.ps1` | `make clean` | Elimina contenedores y redes |
| **Desinstalación total** | `./scripts/uninstall.sh --volumes --yes` | `.\scripts\uninstall.ps1 -Volumes -Yes` | `make clean-all` | Elimina contenedores y **volúmenes de datos** |

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
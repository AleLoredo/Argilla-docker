import json
import os
from pathlib import Path
import argilla as rg

# 1. Conexión con Argilla
client = rg.Argilla(
    api_url="http://localhost:6900",
    api_key="argilla.apikey"
)

dataset_name = "telco_multitask_evaluation"
jsonl_file = Path("train-dataset1") / "train.jsonl"

if not jsonl_file.is_file():
    raise FileNotFoundError(f"No se encontró el archivo: {jsonl_file.resolve()}")

# 2. Paso previo: descubrir dinámicamente todas las etiquetas posibles para 'choice'
dynamic_choice_labels = set()
with open(jsonl_file, "r", encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            data = json.loads(line)
        except json.JSONDecodeError:
            continue

        if data.get("primitive") == "choice":
            # Extraer claves de criteria si existen
            criteria = data.get("question", {}).get("criteria")
            if isinstance(criteria, dict):
                dynamic_choice_labels.update(criteria.keys())
            # Asegurar que el target también esté en las etiquetas
            target = data.get("target")
            if target:
                dynamic_choice_labels.add(str(target))

# Si no hubiera registros choice, dejamos una por defecto para no romper el schema
choice_labels = sorted(list(dynamic_choice_labels)) or ["general"]
print(f"Etiquetas detectadas para choice ({len(choice_labels)}): {choice_labels}")

# 3. Configuración del esquema en Argilla
settings = rg.Settings(
    fields=[
        rg.TextField(
            name="text",
            title="Mensaje del cliente",
            use_markdown=False
        ),
        rg.TextField(
            name="task_instructions",
            title="Instrucción de la Tarea",
            use_markdown=True,
            required=False
        ),
        rg.TextField(
            name="criteria_guide",
            title="Criterios / Rúbrica",
            use_markdown=True,
            required=False
        ),
    ],
    questions=[
        # Pregunta obligatoria general
        rg.LabelQuestion(
            name="status",
            title="Estado del registro:",
            labels=["valido", "descartar"],
            required=True
        ),
        # Tarea 1: choice (con todas las etiquetas descubiertas dinámicamente)
        rg.LabelQuestion(
            name="department",
            title="Derivación de Departamento:",
            labels=choice_labels,
            required=False
        ),
        # Tarea 2: noul (binario / validación de afirmación)
        rg.LabelQuestion(
            name="binary_confirmation",
            title="¿Cumple la condición planteada?",
            labels=["0", "1"],
            required=False
        ),
        # Tarea 3: score (escala de severidad 0, 1, 2)
        rg.RatingQuestion(
            name="frustration_score",
            title="Nivel de severidad / frustración:",
            values=[0, 1, 2],
            required=False
        ),
    ],
    metadata=[
        rg.TermsMetadataProperty(
            name="primitive",
            title="Tipo de Tarea"
        )
    ]
)

# 4. Recrear el dataset con el nuevo conjunto de labels
existing_dataset = client.datasets(name=dataset_name)
if existing_dataset is not None:
    print(f"Eliminando dataset anterior '{dataset_name}'...")
    existing_dataset.delete()

dataset = rg.Dataset(
    name=dataset_name,
    settings=settings,
    client=client
)
dataset.create()
print(f"Dataset '{dataset_name}' creado con éxito.")

# 5. Cargar y formatear registros
records = []
with open(jsonl_file, "r", encoding="utf-8") as f:
    for line_idx, line in enumerate(f, start=1):
        line = line.strip()
        if not line:
            continue
        try:
            data = json.loads(line)
        except json.JSONDecodeError as err:
            print(f"Línea {line_idx} omitida por JSON inválido: {err}")
            continue

        primitive = data.get("primitive", "")
        question_data = data.get("question", {})
        instructions = question_data.get("instructions", "")
        criteria = question_data.get("criteria")
        target = data.get("target")

        # Formatear rúbrica a Markdown
        markdown_criteria = ""
        if isinstance(criteria, dict):
            markdown_criteria = "\n".join([f"- **`{k}`**: {v}" for k, v in criteria.items()])
        elif isinstance(criteria, list):
            markdown_criteria = "\n".join([f"- **Nivel {i}**: {desc}" for i, desc in enumerate(criteria)])

        # Sugerencias
        suggestions = [
            rg.Suggestion(question_name="status", value="valido")
        ]

        if target is not None:
            if primitive == "choice":
                suggestions.append(rg.Suggestion(question_name="department", value=str(target)))
            elif primitive == "noul":
                suggestions.append(rg.Suggestion(question_name="binary_confirmation", value=str(target)))
            elif primitive == "score":
                suggestions.append(rg.Suggestion(question_name="frustration_score", value=int(target)))

        records.append(
            rg.Record(
                id=str(data.get("id")),
                fields={
                    "text": data.get("state", ""),
                    "task_instructions": instructions,
                    "criteria_guide": markdown_criteria
                },
                suggestions=suggestions,
                metadata={
                    "primitive": primitive
                }
            )
        )

# 6. Ingesta en batches de 100
BATCH_SIZE = 100
for i in range(0, len(records), BATCH_SIZE):
    batch = records[i:i + BATCH_SIZE]
    dataset.records.log(batch)

print(f"¡Carga completada exitosamente! Se subieron {len(records)} registros a '{dataset_name}'.")
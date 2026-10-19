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
dataset = client.datasets(name=dataset_name)

if dataset is None:
    raise ValueError(f"No se encontró el dataset '{dataset_name}'.")

# 2. Recorrer registros y procesar las respuestas
output_records = []

for record in dataset.records:
    record_id = record.id
    primitive = record.metadata.get("primitive", "")
    text = record.fields.get("text", "")
    instructions = record.fields.get("task_instructions", "")
    
    # Extraer las respuestas enviadas asociando question_name -> value
    submitted_values = {}
    for response in record.responses:
        q_name = getattr(response, "question_name", None)
        q_val = getattr(response, "value", None)
        
        # Compatibilidad si viniera empaquetado como dict o atributo plano
        if isinstance(q_val, dict):
            q_val = q_val.get("value")
            
        if q_name is not None and q_val is not None:
            submitted_values[q_name] = q_val

    # Mapear el target según la tarea (primitiva)
    final_target = None
    if primitive == "choice":
        final_target = submitted_values.get("department")
    elif primitive == "noul":
        raw_val = submitted_values.get("binary_confirmation")
        final_target = int(raw_val) if raw_val is not None else None
    elif primitive == "score":
        raw_val = submitted_values.get("frustration_score")
        final_target = int(raw_val) if raw_val is not None else None

    # Fallback a sugerencias si alguna respuesta no se persistió
    if final_target is None and record.suggestions:
        for sug in record.suggestions:
            if sug.question_name in ["department", "binary_confirmation", "frustration_score"]:
                val = sug.value
                if primitive in ["noul", "score"] and val is not None:
                    final_target = int(val)
                else:
                    final_target = val

    # Formato final limpio del registro
    exported_item = {
        "id": record_id,
        "primitive": primitive,
        "state": text,
        "question": {
            "type": primitive,
            "instructions": instructions
        },
        "target": final_target,
        "status": submitted_values.get("status", "valido")
    }
    output_records.append(exported_item)

# 3. Guardar el archivo JSONL
output_dir = Path("train-dataset1")
output_dir.mkdir(parents=True, exist_ok=True)
output_path = output_dir / "train_annotated.jsonl"

with open(output_path, "w", encoding="utf-8") as f:
    for item in output_records:
        f.write(json.dumps(item, ensure_ascii=False) + "\n")

print(f"Exportación exitosa: {len(output_records)} registros guardados en '{output_path}'.")
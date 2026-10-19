import argilla as rg

client = rg.Argilla(
    api_url="http://localhost:6900",
    api_key="argilla.apikey"
)

dataset = client.datasets("telco_multitask_evaluation")

submitted_count = 0
pending_count = 0
users_found = set()

for record in dataset.records:
    if record.responses:
        submitted_count += 1
        for resp in record.responses:
            users_found.add(getattr(resp, "user_id", "desconocido"))
    else:
        pending_count += 1

print(f"--- ESTADO EN BASE DE DATOS ---")
print(f"Registros con respuestas guardadas: {submitted_count}")
print(f"Registros sin respuestas: {pending_count}")
print(f"IDs de usuarios que enviaron respuestas: {users_found}")
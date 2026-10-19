#!/usr/bin/env python3
"""
Ejemplo de prueba de conexión y uso básico con Argilla (v2.x).
Puede ejecutarse con el SDK de Argilla ('pip install argilla')
o con la biblioteca estándar de Python como verificación HTTP.
"""

import os
import sys
import json
import urllib.request
import urllib.error

API_URL = os.getenv("ARGILLA_API_URL", "http://localhost:6900")
API_KEY = os.getenv("ARGILLA_API_KEY", "argilla.apikey")

print(f"Probando conexión con Argilla en: {API_URL}")

# 1. Comprobación vía HTTP REST directa
try:
    req = urllib.request.Request(
        f"{API_URL}/api/v1/me",
        headers={"X-Argilla-Api-Key": API_KEY}
    )
    with urllib.request.urlopen(req, timeout=10) as response:
        user_info = json.loads(response.read().decode())
        print(f" Conexión HTTP REST exitosa!")
        print(f"  - Usuario autenticado: {user_info.get('username')}")
        print(f"  - Rol: {user_info.get('role')}")
        print(f"  - ID: {user_info.get('id')}")
except Exception as e:
    print(f" Error de conexión HTTP REST: {e}")
    sys.exit(1)

# 2. Comprobación vía Argilla SDK (si está disponible)
try:
    import argilla as rg
    print("\nLibrería 'argilla' detectada en el entorno:")
    
    # Argilla v2 SDK
    if hasattr(rg, "Argilla"):
        client = rg.Argilla(api_url=API_URL, api_key=API_KEY)
        print(" Cliente Argilla v2 inicializado correctamente.")
        workspaces = list(client.workspaces)
        print(f"  - Espacios de trabajo encontrados ({len(workspaces)}): {[ws.name for ws in workspaces]}")
    # Argilla v1 SDK fallback
    elif hasattr(rg, "init"):
        rg.init(api_url=API_URL, api_key=API_KEY)
        print(" Cliente Argilla v1 inicializado correctamente.")
except ImportError:
    print("\nNota: Para interactuar programáticamente mediante el SDK oficial:")
    print("  pip install argilla")
    print("  python -c \"import argilla as rg; client = rg.Argilla(api_url='http://localhost:6900', api_key='argilla.apikey')\"")

print("\n¡Todo está listo y funcionando para tareas de anotación NLP!")

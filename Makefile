.PHONY: help install up start down stop restart status logs logs-server logs-es test test-python clean clean-all

# Comando docker compose por defecto
COMPOSE ?= docker compose

help: ## Muestra este menú de ayuda
	@echo "Comandos disponibles en Argilla-docker:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

install: ## Ejecuta la instalación desatendida completa
	@chmod +x install.sh start.sh stop.sh restart.sh status.sh uninstall.sh scripts/*.sh
	@./install.sh

start: ## Inicia los contenedores de Argilla
	@./start.sh

up: start ## Alias de start

stop: ## Detiene los contenedores sin borrar volúmenes
	@./stop.sh

down: stop ## Alias de stop

restart: ## Reinicia los contenedores de Argilla
	@./restart.sh

status: ## Consulta el estado de los contenedores y la salud del servicio
	@./status.sh

logs: ## Sigue los registros en tiempo real de todos los servicios
	@$(COMPOSE) logs -f

logs-server: ## Sigue los registros del servidor de Argilla
	@$(COMPOSE) logs -f argilla

logs-es: ## Sigue los registros de Elasticsearch
	@$(COMPOSE) logs -f elasticsearch

test: ## Ejecuta la prueba rápida de conectividad REST con curl
	@bash examples/quick_test.sh

test-python: ## Ejecuta la prueba de cliente en Python
	@python3 examples/test_client.py

clean: ## Detiene y elimina contenedores y redes (conserva datos)
	@./uninstall.sh

clean-all: ## Elimina contenedores, redes y VOLÚMENES PERSISTENTES (borra datos)
	@./uninstall.sh --volumes --yes

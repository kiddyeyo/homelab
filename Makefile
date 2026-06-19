# Makefile — entorno de desarrollo homelab
# Propósito: configurar LSPs y gestión de secrets. No opera infraestructura.

TF_ROOTS := \
	terraform/deploy-vms \
	terraform/setup-templates

SENSITIVE_FILES := \
	docker/homepage/.env \
	docker/immich/.env \
	docker/monitoring/dozzle_data/users.yml \
	docker/paperlessngx/.env \
	docker/semaphoreui/.env \
	docker/traefik/.env \
	docker/traefik/cf-token \
	docker/vaultwarden/.env \
	ansible/vars/secrets.yml

.DEFAULT_GOAL := help
.PHONY: galaxy-install tf-init encrypt-all decrypt-all rekey docs-serve docs-build setup help

setup: ## Instala lefthook git hooks (correr una vez después de clonar el repo)
	@command -v lefthook >/dev/null 2>&1 || \
		{ echo "Error: 'lefthook' no está instalado. Ver https://github.com/evilmartians/lefthook"; exit 1; }
	lefthook install -f
	@echo "Git hooks instalados correctamente."

galaxy-install: ## Instala las Ansible collections desde requirements.yml
	@command -v ansible-galaxy >/dev/null 2>&1 || \
		{ echo "Error: 'ansible-galaxy' no está instalado."; exit 1; }
	ansible-galaxy collection install -r ansible/requirements.yml
	@echo ""
	ansible-galaxy collection list

tf-init: ## Inicializa cada root module de terraform/ para que terraform-ls funcione en el editor
	@command -v terraform >/dev/null 2>&1 || \
		{ echo "Error: 'terraform' no está instalado. Ver https://developer.hashicorp.com/terraform/install"; exit 1; }
	@for dir in $(TF_ROOTS); do \
		echo ""; \
		echo "terraform init -> $$dir"; \
		terraform -chdir=$$dir init; \
	done

encrypt-all: ## Encripta todos los archivos sensibles del repo con sops (in-place)
	@command -v sops >/dev/null 2>&1 || \
		{ echo "Error: 'sops' no está instalado. Ver https://github.com/getsops/sops"; exit 1; }
	@echo "Encriptando archivos sensibles"
	@for f in $(SENSITIVE_FILES); do \
		if [ -f "$$f" ]; then \
			sops --encrypt --in-place "$$f" && echo "  ✓ $$f"; \
		else \
			echo "  — Saltando $$f (no existe)"; \
		fi; \
	done

decrypt-all: ## Desencripta todos los archivos sensibles del repo con sops (in-place)
	@command -v sops >/dev/null 2>&1 || \
		{ echo "Error: 'sops' no está instalado. Ver https://github.com/getsops/sops"; exit 1; }
	@echo "Desencriptando archivos sensibles"
	@for f in $(SENSITIVE_FILES); do \
		if [ -f "$$f" ]; then \
			sops --decrypt --in-place "$$f" && echo "  ✓ $$f"; \
		else \
			echo "  — Saltando $$f (no existe)"; \
		fi; \
	done

rekey: ## Actualiza recipients de todos los archivos SOPS encriptados (correr tras editar .sops.yaml)
	@command -v sops >/dev/null 2>&1 || \
		{ echo "Error: 'sops' no está instalado."; exit 1; }
	@echo "Actualizando recipients en archivos  encriptados"
	@for f in $(SENSITIVE_FILES); do \
		if [ -f "$$f" ]; then \
			echo "  → $$f"; \
			sops updatekeys --yes "$$f"; \
		else \
			echo "  — Saltando $$f (no existe)"; \
		fi; \
	done

docs-serve: ## Lanza mkdocs serve con el mkdocs.yml de la raíz del repo
	@command -v mkdocs >/dev/null 2>&1 || \
		{ echo "Error: 'mkdocs' no instalado. Corre: uv tool install mkdocs"; exit 1; }
	mkdocs serve

docs-build: ## Genera el sitio estático de MkDocs en site/
	@command -v mkdocs >/dev/null 2>&1 || \
		{ echo "Error: 'mkdocs' no instalado. Corre: uv tool install mkdocs"; exit 1; }
	mkdocs build

help: ## Muestra esta ayuda
	@printf "\nUso: make <target>\n\nTargets disponibles:\n\n"
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@printf "\n"

# Evita "No rule to make target" cuando se pasan argumentos extra (e.g. make edit archivo)
%:
	@:

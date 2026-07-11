# Makefile — entorno de desarrollo homelab
# Propósito: configurar LSPs y gestión de secrets. No opera infraestructura.

TF_ROOTS := $(patsubst %/terraform.tf,%,$(wildcard terraform/*/terraform.tf))

SENSITIVE_FILES := $(shell find docker ansible terraform \
	\( -name ".env" \
	-o -name "users.yml" \
	-o -name "secrets.yml" \
	-o -name "*.tfvars" \
	-o -name "*.ini" \) \
	! -path "*/.terraform/*" \
	| sort)

.DEFAULT_GOAL := help
.PHONY: setup fmt lint yaml-lint yaml-fmt encrypt-all decrypt-all rekey galaxy-install ansible-lint compose-lint tf-init tf-fmt tf-validate serve build help

# ─── Global ──────────────────────────────────────────────────────────────────

setup: ## Configura el entorno de desarrollo completo (hooks, terraform, ansible)
	@command -v lefthook >/dev/null 2>&1 || \
		{ echo "Error: 'lefthook' no está instalado. Ver https://github.com/evilmartians/lefthook"; exit 1; }
	@command -v uv >/dev/null 2>&1 || \
		{ echo "Error: 'uv' no está instalado. Ver https://docs.astral.sh/uv/getting-started/installation/"; exit 1; }
	@command -v pnpm >/dev/null 2>&1 || \
		{ echo "Error: 'pnpm' no está instalado. Ver https://pnpm.io/installation"; exit 1; }
	lefthook install -f
	@echo "Git hooks instalados correctamente."
	uv sync
	pnpm install
	@$(MAKE) tf-init
	@$(MAKE) galaxy-install

fmt: ## Formatea todos los archivos del repo (YAML + HCL)
	@$(MAKE) yaml-fmt
	@$(MAKE) tf-fmt

lint: ## Corre todos los linters y validaciones (YAML, Ansible, Docker, Terraform)
	@$(MAKE) yaml-lint
	@$(MAKE) ansible-lint
	@$(MAKE) compose-lint
	@$(MAKE) tf-validate

yaml-lint: ## Lint de archivos YAML: playbooks de Ansible, Docker Compose y YAMLs sueltos
	uv run yamllint -c .yamllint ansible/ docker/ $(wildcard *.yml *.yaml .*.yaml)
	pnpm exec prettier --check "ansible/**/*.{yml,yaml}" "docker/**/*.{yml,yaml}" ".github/**/*.{yml,yaml}" "*.yml"

yaml-fmt: ## Formatea archivos YAML con prettier (aplica cambios)
	pnpm exec prettier --write "ansible/**/*.{yml,yaml}" "docker/**/*.{yml,yaml}" ".github/**/*.{yml,yaml}" "*{.yml,.yaml}"

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

decrypt-all: ## (No se recomienda) Desencripta todos los archivos sensibles del repo con sops (in-place)
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

# ─── Ansible ─────────────────────────────────────────────────────────────────

galaxy-install: ## Instala las Ansible collections desde requirements.yml
	uv run ansible-galaxy collection install -r requirements.yml
	@echo ""
	uv run ansible-galaxy collection list

ansible-lint: ## Lint de playbooks y roles de Ansible en ansible/
	ANSIBLE_CONFIG=ansible/ansible.cfg uv run ansible-lint ansible/

# ─── Docker ──────────────────────────────────────────────────────────────────

compose-lint: ## Valida todos los docker-compose.yml en docker/ con 'docker compose config'
	@command -v docker >/dev/null 2>&1 || \
		{ echo "Error: 'docker' no está instalado."; exit 1; }
	@FAILED=0; \
	for dir in $(wildcard docker/*/); do \
		if [ -f "$$dir/docker-compose.yml" ]; then \
			echo ""; \
			echo "docker compose config -> $$dir"; \
			docker compose -f "$$dir/docker-compose.yml" config --quiet --no-interpolate || FAILED=1; \
		fi; \
	done; \
	if [ "$$FAILED" -eq 1 ]; then \
		echo ""; \
		echo "Error: docker compose config falló en uno o más servicios."; \
		exit 1; \
	fi

# ─── Terraform ───────────────────────────────────────────────────────────────

tf-init: ## Inicializa cada root module de terraform/ para que terraform-ls funcione en el editor
	@command -v terraform >/dev/null 2>&1 || \
		{ echo "Error: 'terraform' no está instalado. Ver https://developer.hashicorp.com/terraform/install"; exit 1; }
	@for dir in $(TF_ROOTS); do \
		echo ""; \
		echo "terraform init -> $$dir"; \
		terraform -chdir=$$dir init; \
	done

tf-fmt: ## Formatea todos los archivos HCL en terraform/ (aplica cambios)
	@command -v terraform >/dev/null 2>&1 || \
		{ echo "Error: 'terraform' no está instalado. Ver https://developer.hashicorp.com/terraform/install"; exit 1; }
	terraform fmt -recursive terraform/

tf-validate: ## Valida la configuración de todos los root modules de terraform/
	@command -v terraform >/dev/null 2>&1 || \
		{ echo "Error: 'terraform' no está instalado. Ver https://developer.hashicorp.com/terraform/install"; exit 1; }
	@for dir in $(TF_ROOTS); do \
		echo ""; \
		echo "terraform validate -> $$dir"; \
		terraform -chdir=$$dir validate || exit 1; \
	done

# ─── Docs ────────────────────────────────────────────────────────────────────

serve: ## Lanza mkdocs serve con el mkdocs.yml de la raíz del repo
	uv run zensical serve

build: ## Genera el sitio estático de MkDocs en site/
	uv run zensical build

# ─── Meta ────────────────────────────────────────────────────────────────────

help: ## Muestra esta ayuda
	@printf "\nUso: make <target>\n\nTargets disponibles:\n\n"
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@printf "\n"

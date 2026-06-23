# Contributing

Guía de trabajo para este repositorio: qué instalar, cómo correr las herramientas, y qué convenciones seguir. Si es la primera vez que clonas el repo, sigue las secciones en orden.

## Prerequisitos

Instalar antes de tocar el repo:

| Herramienta | Para qué | Instalación |
|---|---|---|
| [Docker](https://docs.docker.com/engine/install/) | runtime de servicios (ver [ADR-001](docs/decisions/001-docker-vs-kubernetes-baremetal.md)) | según tu OS |
| [Terraform](https://developer.hashicorp.com/terraform/install) u [OpenTofu](https://opentofu.org/docs/intro/install/) | provisioning de VMs | según tu OS — la versión exacta la obliga `required_version` en cada root module |
| [uv](https://docs.astral.sh/uv/getting-started/installation/) | gestor de entornos/paquetes Python (ansible-core, ansible-lint, mkdocs, yamllint) | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| [pnpm](https://pnpm.io/installation) | gestor de paquetes Node.js (prettier) | `npm install -g pnpm` o `corepack enable pnpm` |
| [SOPS](https://github.com/getsops/sops) | cifrado de secretos (ver [ADR-003](docs/decisions/003-sops-secrets-management.md)) | binario desde releases de GitHub |
| [age](https://github.com/FiloSottile/age) | backend de cifrado de SOPS | binario desde releases de GitHub, o `apt`/`brew` |
| [lefthook](https://github.com/evilmartians/lefthook) | git hooks (pre-commit) | `go install github.com/evilmartians/lefthook@latest`, o binario desde releases |

No se fija versión de Terraform vía herramienta externa (tipo `tenv`): el bloque `terraform { required_version = "..." }` en cada root module ya obliga a usar la versión correcta — si no calza, `terraform init` falla con un mensaje explícito.

Las herramientas Python (`ansible-core`, `ansible-lint`, `mkdocs`, `yamllint`) están **pineadas** en `pyproject.toml` y se instalan automáticamente con `uv sync`. No uses `pip install` directamente.

## Setup inicial (una sola vez tras clonar)

```bash
make setup
```

Esto hace todo de una vez:
1. Instala los git hooks de `lefthook`
2. Crea el entorno virtual `.venv` e instala las dependencias Python con `uv sync`
3. Instala las dependencias Node.js con `pnpm install` (prettier)
4. Inicializa cada root module de `terraform/` para el editor
5. Instala las collections de Ansible desde `requirements.yml`

**No continúes sin correr esto** — los hooks de pre-commit son la primera línea de defensa contra commitear secretos sin cifrar o archivos mal formateados.

## Linting y formateo

El repo tiene un pipeline completo de calidad de código. Puedes correr todo de una vez o en partes:

```bash
make lint      # todos los linters: YAML + Ansible + Docker Compose + Terraform
make fmt       # todos los formateadores: YAML (prettier) + HCL (terraform fmt)
```

### Por capa

```bash
make yaml-lint      # yamllint (reglas en .yamllint) + prettier --check sobre YAML
make yaml-fmt       # aplica prettier sobre archivos YAML (modifica en disco)
make ansible-lint   # ansible-lint en ansible/
make compose-lint   # docker compose config --quiet en cada docker-compose.yml de docker/
make tf-fmt         # terraform fmt -recursive en terraform/
make tf-validate    # terraform validate en cada root module
```

La configuración de yamllint está en `.yamllint` (raíz del repo). Reglas destacadas: longitud máxima de línea 120 (warning, no error), `document-start` deshabilitado (Homepage y Traefik no usan `---`), valores booleanos `on`/`off` permitidos (Traefik), y los archivos cifrados (`secrets.yml`, `users.yml`) están en el `ignore:` de yamllint porque SOPS genera YAML que no pasa lint.

### Pre-commit hooks

Los hooks de `lefthook` (instalados vía `make setup`) corren automáticamente en cada `git commit`. Lo que verifican:

| Hook | Disparador | Qué bloquea |
|---|---|---|
| `check-sops-encrypted` | cualquier commit | archivos sensibles (`.env`, `secrets.yml`, `users.yml`, `*.tfvars`) sin marca `ENC[AES256` |
| `yaml-lint` | `**/*.{yml,yaml}` staged | errores de yamllint y de formato prettier |
| `ansible-lint` | `ansible/**/*.{yml,yaml}` staged | problemas en playbooks/roles de Ansible |
| `compose-lint` | `docker/**/docker-compose.yml` staged | errores de sintaxis en Docker Compose |
| `terraform-fmt` | `terraform/**/*.tf` staged | archivos HCL sin formatear |
| `terraform-validate` | `terraform/**/*.tf` staged | configuración de Terraform inválida |

Si un hook falla, el commit no se realiza. Corrige el problema y vuelve a intentar. Si `terraform-validate` falla porque los providers no están descargados, corre `make tf-init` primero.

## Ansible

`ansible-core` y sus dependencias están pineadas en `pyproject.toml` y se instalan via `uv`. No instales `ansible-core` manualmente con `pip`.

Las collections están pineadas en `requirements.yml`:
- `community.docker` 5.2.1
- `community.general` 13.1.0

Para instalarlas o reinstalarlas:

```bash
make galaxy-install
```

No corras `ansible-galaxy install` a mano fuera de este target — el Makefile usa `uv run ansible-galaxy` para asegurar que se usa la versión correcta de ansible desde `.venv`.

## SOPS — cómo manejar archivos cifrados

Regla central: **nunca desencriptes el repo completo como flujo normal de trabajo.** El target `decrypt-all` existe en el Makefile, pero está marcado explícitamente como "no recomendado" — es una herramienta de emergencia/migración, no un paso de tu día a día. Además, usar `decrypt-all` + `encrypt-all` arruina los diffs de git: SOPS regenera el ciphertext de **todos** los valores al re-encriptar, aunque solo hayas modificado uno. Usa siempre `sops edit` archivo por archivo.

### Flujo normal: archivo por archivo

**Ver el contenido de un archivo cifrado**, sin modificarlo en disco:

```bash
sops -d ruta/al/archivo.sops.yaml
```

Esto imprime el contenido desencriptado a stdout. El archivo en disco sigue cifrado.

**Editar un archivo cifrado**:

```bash
sops edit ruta/al/archivo.sops.yaml
```

`sops edit` desencripta en memoria, abre tu `$EDITOR`, y vuelve a cifrar automáticamente al guardar y cerrar.

**Cifrar un archivo nuevo** que todavía no está cifrado:

```bash
sops -e -i ruta/al/archivo.yaml
```

(`-i` = in-place; sin `-i`, SOPS imprime el resultado cifrado a stdout en vez de sobrescribir el archivo.)

### Rekey

Si modificas `.sops.yaml` (por ejemplo, agregas o quitas un recipient):

```bash
make rekey
```

Esto reescribe los recipients de **todos** los archivos cifrados del repo para que coincidan con la configuración actual de `.sops.yaml`.

### Quién tiene acceso a qué

El control de acceso se resuelve en `.sops.yaml`: ahí está la lista de claves públicas de age (`age1...`) con permiso de descifrar cada grupo de archivos.

## Versiones pineadas

| Herramienta | Dónde se pinea | Versión |
|---|---|---|
| ansible-core | `pyproject.toml` | 2.21.1 |
| ansible-lint | `pyproject.toml` | 26.4.0 |
| mkdocs | `pyproject.toml` | 1.6.1 |
| yamllint | `pyproject.toml` | 1.38.0 |
| prettier | `package.json` | ^3.8.4 |
| community.docker | `requirements.yml` | 5.2.1 |
| community.general | `requirements.yml` | 13.1.0 |

Para actualizar una herramienta Python: edita `pyproject.toml` y corre `uv lock && uv sync`. Para Ansible collections: edita `requirements.yml` y corre `make galaxy-install`.

## Comandos del Makefile (referencia completa)

```
make setup            # setup completo: hooks + uv sync + pnpm install + tf-init + galaxy-install
make tf-init          # inicializa cada root module de terraform/ para el editor

# Linting y formateo
make lint             # todos los linters (YAML + Ansible + Docker Compose + Terraform)
make fmt              # todos los formateadores (YAML + HCL)
make yaml-lint        # yamllint + prettier --check sobre YAML
make yaml-fmt         # aplica prettier sobre archivos YAML
make ansible-lint     # ansible-lint en ansible/
make compose-lint     # docker compose config en todos los docker-compose.yml
make tf-fmt           # terraform fmt -recursive en terraform/
make tf-validate      # terraform validate en cada root module

# Ansible
make galaxy-install   # instala collections de Ansible desde requirements.yml

# Secretos
make encrypt-all      # (no recomendado) cifra todos los archivos sensibles in-place
make decrypt-all      # (no recomendado) descifra todos los archivos sensibles in-place
make rekey            # actualiza recipients de todos los archivos SOPS

# Docs
make serve            # lanza mkdocs serve con el mkdocs.yml de la raíz
make build            # genera el sitio estático de MkDocs en site/
make help             # muestra esta lista
```

## Antes de hacer commit

Los hooks de `lefthook` verifican todo automáticamente, pero como checklist manual:

1. Los archivos sensibles (`.env`, `secrets.yml`, `users.yml`, `*.tfvars`) deben estar cifrados. En caso de duda: `make encrypt-all`.
2. Si modificaste YAML, corre `make yaml-lint` para ver errores y `make yaml-fmt` para formatear.
3. Si modificaste playbooks o roles de Ansible, corre `make ansible-lint`.
4. Si modificaste un `docker-compose.yml`, corre `make compose-lint`.
5. Si modificaste HCL de Terraform, corre `make tf-fmt` y luego `make tf-validate` (requiere `make tf-init` previo).

## Decisiones de arquitectura

El razonamiento detrás de las decisiones técnicas de este repo vive en [`docs/decisions/`](docs/decisions/), no aquí. Este documento es solo el "cómo operar el repo día a día"; el "por qué se construyó así" está en los ADRs.

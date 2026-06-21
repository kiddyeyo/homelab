# Contributing

Guía de trabajo para este repositorio: qué instalar, cómo correr las herramientas, y qué convenciones seguir. Si es la primera vez que clonas el repo, sigue las secciones en orden.

## Prerequisitos

Instalar antes de tocar el repo:

| Herramienta | Para qué | Instalación |
|---|---|---|
| [Docker](https://docs.docker.com/engine/install/) | runtime de servicios (ver [ADR-0001](docs/adr/0001-docker-sobre-kubernetes-y-baremetal.md)) | según tu OS |
| [Terraform](https://developer.hashicorp.com/terraform/install) u [OpenTofu](https://opentofu.org/docs/intro/install/) | provisioning de VMs | según tu OS — la versión exacta requerida la valida el propio `terraform init` contra `required_version` en cada root module, no hace falta gestor de versiones aparte |
| [uv](https://docs.astral.sh/uv/getting-started/installation/) | gestor de entornos/paquetes Python | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| `ansible-core` | configuración de VMs | ver sección [Ansible](#ansible) abajo — instalación manual, sin pin de versión por ahora |
| [SOPS](https://github.com/getsops/sops) | cifrado de secretos (ver [ADR-0003](docs/adr/0003-sops-age-sobre-doppler-infisical-vault.md)) | binario desde releases de GitHub |
| [age](https://github.com/FiloSottile/age) | backend de cifrado de SOPS | binario desde releases de GitHub, o `apt`/`brew` |
| `lefthook` | git hooks (pre-commit) | `go install github.com/evilmartians/lefthook@latest`, o binario desde releases |

No se fija versión de Terraform vía herramienta externa (tipo `tenv`): el bloque `terraform { required_version = "..." }` en cada root module ya obliga a usar la versión correcta — si no calza, `terraform init` falla con un mensaje explícito. No se necesita nada adicional.

## Setup inicial (una sola vez tras clonar)

```bash
make setup
```

Esto instala los git hooks de `lefthook`. **No continúes sin correr esto** — los hooks son la primera línea de defensa contra commitear un secreto sin cifrar.

Después, para que `terraform-ls` funcione correctamente en el editor (autocompletado, validación inline):

```bash
make tf-init
```

Inicializa cada root module de `terraform/` (actualmente `deploy-vms/` y `setup-templates/`).

## Ansible

Instalar `ansible-core` manualmente (sin pin de versión por ahora — esto es una decisión pendiente, no un descuido; cuando se fije, esta sección se actualiza).

Una vez instalado `ansible-core`, instalar las collections/roles declarados en `requirements.yml`:

```bash
make galaxy-install
```

No corras `ansible-galaxy install` a mano fuera de este target — el Makefile asegura que se lea siempre el mismo `requirements.yml` del repo, sin variaciones de invocación entre máquinas.

## SOPS — cómo manejar archivos cifrados

Regla central: **nunca desencriptes el repo completo como flujo normal de trabajo.** El target `decrypt-all` existe en el Makefile, pero está marcado explícitamente como "no recomendado" — es una herramienta de emergencia/migración (por ejemplo, para auditar todo el contenido cifrado de una sola vez, o tras un `rekey` masivo), no un paso de tu día a día. Si lo corres, asegúrate de no dejar los archivos desencriptados sin volver a cifrar antes de salir del repo, y nunca los commitees en texto plano.

Además, usar `decrypt-all` + `encrypt-all` arruina los diffs de git: SOPS regenera el ciphertext de **todos** los valores al re-encriptar, aunque solo hayas modificado uno. El commit muestra todos los campos como cambiados, haciendo imposible saber qué secreto se tocó realmente. Usa siempre `sops edit` archivo por archivo.

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

`sops edit` desencripta en memoria, abre tu `$EDITOR`, y vuelve a cifrar automáticamente al guardar y cerrar. Es la única forma correcta de modificar un archivo cifrado — nunca desencriptes a mano, edites, y vuelvas a encriptar como pasos separados.

**Cifrar un archivo nuevo** que todavía no está cifrado:

```bash
sops -e -i ruta/al/archivo.yaml
```

(`-i` = in-place; sin `-i`, SOPS imprime el resultado cifrado a stdout en vez de sobrescribir el archivo.)

### Rekey

Si modificas `.sops.yaml` (por ejemplo, agregas o quitas un recipient — alguien gana o pierde acceso a los secretos):

```bash
make rekey
```

Esto reescribe los recipients de **todos** los archivos cifrados del repo para que coincidan con la configuración actual de `.sops.yaml`. Es necesario correrlo después de cualquier cambio a esa configuración, o los archivos seguirán cifrados para la lista de recipients anterior.

### Quién tiene acceso a qué

El control de acceso se resuelve completo en `.sops.yaml`: ahí está la lista de claves públicas de age (`age1...`) con permiso de descifrar cada grupo de archivos. No hay ningún secreto cargado como variable de entorno en Semaphore ni en GitHub Actions más allá de la clave privada de age necesaria para desencriptar — el resto se resuelve leyendo `.sops.yaml` + el archivo cifrado correspondiente en tiempo de ejecución.

## Comandos del Makefile (referencia completa)

```
make setup            # instala git hooks de lefthook (correr una vez tras clonar)
make tf-init           # inicializa cada root module de terraform/ para el editor
make galaxy-install    # instala collections de Ansible desde requirements.yml
make encrypt-all       # (no recomendado) cifra todos los archivos sensibles in-place
make decrypt-all       # (no recomendado) descifra todos los archivos sensibles in-place
make rekey             # actualiza recipients de todos los archivos SOPS (correr tras editar .sops.yaml)
make docs-build        # genera el sitio estático de MkDocs en site/
make docs-serve        # lanza mkdocs serve con el mkdocs.yml de la raíz
make help              # muestra esta lista
```

## Antes de hacer commit

Los hooks de `lefthook` (instalados vía `make setup`) corren automáticamente, pero como verificación manual:

1. Ningún archivo que debería estar cifrado se commitea en texto plano. Si tienes dudas sobre si algo debería estar cifrado, revisa `.sops.yaml` para ver qué patrones de archivo están cubiertos.
2. Si modificaste un root module de Terraform, corre `terraform fmt` y `terraform validate` dentro de ese módulo antes de commitear.
3. Si modificaste un playbook o rol de Ansible, valida con `ansible-lint` antes de commitear.

## Decisiones de arquitectura

El razonamiento detrás de las decisiones técnicas de este repo (por qué Docker y no Kubernetes, por qué SOPS+age y no Vault, por qué la arquitectura dual de Semaphore + GitHub Actions, etc.) vive en [`docs/adr/`](docs/adr/README.md), no aquí. Este documento es solo el "cómo operar el repo día a día"; el "por qué se construyó así" está en los ADRs.

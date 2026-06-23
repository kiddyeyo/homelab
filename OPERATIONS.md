# OPERATIONS.md — Reglas operativas críticas

Invariantes operativas del homelab. Estas reglas existen porque ya se identificó un modo de fallo concreto — no son convenciones de estilo. Léelas antes de cualquier operación de infraestructura.

---

## No corras `terraform apply` ni playbooks desde tu entorno de desarrollo

**Solo Semaphore UI o GitHub Actions runner.** `plan` y `--check` locales están bien.

Correr apply localmente puede corromper el `tfstate` compartido en PostgreSQL y generar drift entre lo que los sistemas centralizados creen que existe y lo que la infraestructura real tiene. Semaphore está disponible vía NetBird desde cualquier dispositivo.

→ ADR-008, ADR-006, ADR-007

---

## No corras `make decrypt-all` como flujo normal

Cuando SOPS re-encripta el repo completo, regenera el ciphertext de **todos** los valores aunque solo hayas cambiado uno. El diff del commit muestra todos los campos como modificados, haciendo imposible auditar qué secreto cambió realmente. Usa `sops edit` archivo por archivo para que el diff solo muestre el archivo afectado.

`decrypt-all` además deja todos los secretos en texto plano en disco. Úsalo solo si tienes una razón específica, y vuelve a encriptar inmediatamente con `make encrypt-all`. El pre-commit hook bloquea commits con secretos en claro, pero el riesgo no es solo el commit — es tener secretos expuestos en el filesystem mientras el archivo está desencriptado.

→ ADR-003

---

## No commitees archivos sensibles sin encriptar

El hook `check-sops-encrypted` de lefthook (`make setup`) bloquea commits con archivos que no tienen la marca `ENC[AES256`. Si el hook no está instalado o se evita, el secreto queda en el historial de git permanentemente. Correr `make setup` una vez después de clonar instala la protección.

Los patrones cubiertos por la detección automática (Makefile + hook) son: `.env`, `secrets.yml`, `users.yml`, `*.tfvars`. Si agregas un nuevo tipo de archivo sensible, actualiza la variable `SENSITIVE_FILES` en el `Makefile` y el comando `find` en `lefthook.yml`.

→ ADR-003

---

## No bypasees los hooks de pre-commit

Los hooks de lefthook no son solo para SOPS — también verifican formato YAML, lint de Ansible, validación de Docker Compose y formato HCL de Terraform. Si un hook falla, el commit está bloqueado por una razón. No uses `git commit --no-verify` para saltarlos.

Si el hook de `terraform-validate` falla porque los providers no están descargados, la solución correcta es correr `make tf-init`, no saltar el hook.

Si el hook de `yaml-lint` falla, usa `make yaml-fmt` para formatear con prettier y `make yaml-lint` para ver qué reglas de yamllint no se cumplen.

---

## No instales herramientas Python con pip directamente

Las herramientas Python del repo (`ansible-core`, `ansible-lint`, `mkdocs`, `yamllint`) están pineadas en `pyproject.toml` y se instalan vía `uv`. Instalarlas con `pip install` directamente puede generar conflictos de versiones entre herramientas y desincronizar el lockfile (`uv.lock`).

Usa siempre `uv run <herramienta>` para invocarlas, o deja que el `Makefile` lo haga. El `Makefile` usa `uv run` en todos sus targets.

# OPERATIONS.md — Reglas operativas críticas

Invariantes operativas del homelab. Estas reglas existen porque ya se identificó un modo de fallo concreto — no son convenciones de estilo. Léelas antes de cualquier operación de infraestructura.

---

## No corras `terraform apply` ni playbooks desde tu laptop

**Solo Semaphore UI o GitHub Actions runner.** `plan` y `--check` locales están bien.

Correr apply localmente puede corromper el `tfstate` compartido en PostgreSQL y generar drift entre lo que los sistemas centralizados creen que existe y lo que la infraestructura real tiene. Semaphore está disponible vía Tailscale desde cualquier dispositivo.

→ ADR-0008, ADR-0006, ADR-0007

---

## No corras `make decrypt-all` como flujo normal

Cuando SOPS re-encripta el repo completo, regenera el ciphertext de **todos** los valores aunque solo hayas cambiado uno. El diff del commit muestra todos los campos como modificados, haciendo imposible auditar qué secreto cambió realmente. Usa `sops edit` archivo por archivo para que el diff solo muestre el archivo afectado.

`decrypt-all` además deja todos los secretos en texto plano en disco. Úsalo solo si tienes una razón específica, y vuelve a encriptar inmediatamente con `make encrypt-all`. El pre-commit hook bloquea commits con secretos en claro, pero el riesgo no es solo el commit — es tener secretos expuestos en el filesystem mientras el archivo está desencriptado.

→ ADR-0003

---

## No commitees archivos sensibles sin encriptar

El hook de lefthook (`make setup`) bloquea commits con archivos que no tienen la marca `ENC[AES256`. Si el hook no está instalado o se evita, el secreto queda en el historial de git permanentemente. Correr `make setup` una vez después de clonar instala la protección.

→ ADR-0003

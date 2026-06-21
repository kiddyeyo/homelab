# ADR-0008: Ejecución de Terraform y Ansible centralizada — ejecución local prohibida

## Status
Accepted

## Context
Con dos puntos de ejecución centralizados establecidos (ADR-0006) y un backend de Terraform compartido en PostgreSQL (ADR-0007), existe un tercer modo posible que ninguno de esos ADRs prohíbe explícitamente: correr `terraform apply` o un playbook de Ansible directamente desde la laptop del operador.

Esta posibilidad no es teórica — es el flujo más natural cuando algo no funciona a las 11pm y se quiere "hacer un apply rápido para probar". El problema es que ese apply ocurre en un contexto donde:

- El `tfstate` que lee la laptop puede estar desincronizado si hubo una ejecución previa desde Semaphore o GitHub Actions que la laptop no tiene.
- El locking de PostgreSQL (ADR-0007) previene ejecuciones *concurrentes*, pero no previene ejecuciones *secuenciales* desde contextos distintos donde el operador no consultó el estado más reciente antes de ejecutar.
- Ansible ejecutado localmente puede usar versiones de colecciones, rutas de archivos, o variables de entorno distintas a las que usa Semaphore, introduciendo drift de configuración invisible.

## Decision
**Toda ejecución de `terraform apply`, `terraform destroy`, y playbooks de Ansible contra infraestructura real ocurre exclusivamente a través de Semaphore UI (ejecución manual) o GitHub Actions self-hosted runner (ejecución automática).** La ejecución local está prohibida como flujo operativo.

`terraform plan` y `ansible-playbook --check` desde local siguen siendo válidos para validación — solo `apply`/`destroy` y ejecuciones reales están prohibidas.

## Alternatives Considered

### Ejecución local con disciplina manual
- Requiere que el operador corra `terraform refresh` antes de cada apply, use exactamente la misma versión de Terraform que Semaphore, y tenga las mismas variables cargadas.
- Rechazado: la disciplina manual falla bajo presión. El riesgo real no es la ejecución normal — es la ejecución de emergencia a las 11pm, que es exactamente cuando menos probable es seguir el protocolo correcto.

### Permitir ejecución local solo para módulos específicos
- Más granular, pero introduce ambigüedad: ¿cuáles módulos están permitidos?, ¿cómo lo sabe el operador en el momento de ejecutar? Rechazado por introducir complejidad sin beneficio real — si el backend compartido existe (ADR-0007), cualquier apply local puede interferir con el estado compartido.

## Consequences
- (+) El `tfstate` en PostgreSQL refleja exclusivamente ejecuciones que pasaron por los puntos de ejecución centralizados — sin drift introducido por contextos locales distintos.
- (+) Toda ejecución queda registrada (logs de Semaphore o GitHub Actions) — trazabilidad completa sin depender de que el operador haya guardado la terminal.
- (+) Versiones de Terraform/Ansible y variables son consistentes entre ejecuciones — no hay "funcionó en mi máquina".
- (-) No es posible hacer un apply rápido localmente en una emergencia — mitigado porque Semaphore es accesible vía Tailscale desde cualquier dispositivo, incluyendo móvil.
- (-) La disponibilidad de Semaphore o el runner se vuelve parte del path crítico para cualquier operación de apply.

## Related
- ADR-0006 (Semaphore + GitHub Actions como únicos puntos de ejecución autorizados — esta regla es el corolario operativo de esa decisión)
- ADR-0007 (Backend PostgreSQL compartido — el recurso que una ejecución local comprometería)

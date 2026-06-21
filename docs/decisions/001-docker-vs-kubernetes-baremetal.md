# ADR-0001: Docker Compose como runtime de servicios, sobre Kubernetes y baremetal

## Status
Accepted

## Context
Cada servicio del homelab (Immich, Vaultwarden, Paperless-NGX, Traefik, Technitium DNS, Semaphore UI) necesita un runtime de aplicación dentro de su VM correspondiente. Las opciones evaluadas fueron:

1. **Kubernetes** (k3s/k8s completo) como orquestador de contenedores.
2. **Baremetal** — instalar cada servicio directamente sobre el OS de la VM (paquetes del sistema, systemd units, dependencias nativas).
3. **Docker / Docker Compose** — un contenedor (o stack pequeño) por servicio, definido vía `docker-compose.yml`.

El contexto operativo es relevante: un solo operador, sin necesidad de auto-scaling, sin múltiples nodos de cómputo que requieran scheduling dinámico de cargas, y con el objetivo explícito de que la infraestructura sea reproducible vía IaC (Terraform + Ansible) en vez de configurada a mano.

## Decision
Se usa **Docker Compose**, un stack por servicio, corriendo dentro de su propia VM (ver ADR-0002 para la decisión de VM vs LXC). Ansible se encarga de instalar Docker Engine y desplegar el `docker-compose.yml` correspondiente en cada VM.

## Alternatives Considered

### Kubernetes (k3s u otro)
- Rechazado por complejidad operacional desproporcionada al caso de uso. Kubernetes resuelve problemas de scheduling multi-nodo, auto-healing, scaling horizontal y service mesh — ninguno de los cuales aplica a un homelab de un solo operador con servicios de carga predecible y estática.
- El costo de mantenimiento (control plane, etcd, actualizaciones de versión, CNI, manejo de PersistentVolumes) no se justifica frente al beneficio real obtenido.
- Curva de aprendizaje y superficie de troubleshooting mucho mayor sin retorno proporcional para este contexto.

### Baremetal (instalación directa sobre el OS)
- Rechazado principalmente por **reproducibilidad**. Una instalación baremetal acumula estado implícito en el sistema (paquetes instalados manualmente, archivos de configuración modificados in-place, versiones de dependencias del sistema) que es difícil de capturar completamente en Ansible sin reinventar lo que un container ya resuelve de forma nativa.
- Dificulta el aislamiento entre servicios: dependencias de un servicio pueden chocar con las de otro en el mismo OS.
- Reconstruir una VM baremetal desde cero exige idempotencia perfecta del playbook de Ansible; con contenedores, la imagen ya es el artefacto reproducible y el playbook se reduce a "instala Docker + aplica el compose file".

### Docker / Docker Compose (elegido)
- Reproducibilidad alta: la definición del servicio vive en `docker-compose.yml`, versionado en Git, sin estado oculto en el host.
- Curva de aprendizaje y superficie operativa mínimas comparadas con Kubernetes — no hay control plane que mantener.
- Aislamiento de dependencias entre servicios sin el overhead de gestionar un cluster.
- Encaja naturalmente con el patrón "un VM por stack de servicio" (ver ADR-0002 y la decisión relacionada de no exponer el Docker socket entre VMs).

## Consequences
- (+) Cada servicio es reproducible mediante `docker-compose.yml` + Ansible, sin estado implícito en el host.
- (+) Sin overhead de control plane ni de gestión de cluster.
- (+) Troubleshooting más simple: `docker compose logs`, `docker compose ps`, sin capas adicionales de abstracción de Kubernetes.
- (-) Sin auto-scaling ni auto-healing nativo — aceptable porque la carga es predecible y el operador es único; un restart manual o vía Ansible es suficiente.
- (-) Si en el futuro el número de servicios o la necesidad de orquestación dinámica crece sustancialmente, esta decisión debe revisarse (candidato a ADR de superseding).

## Related
- ADR-0002 (VMs sobre LXC)
- Decisión relacionada: un VM por stack de servicio, sin exposición de Docker socket entre VMs.

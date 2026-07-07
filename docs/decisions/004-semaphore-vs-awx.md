# ADR-004: Semaphore UI sobre AWX y otros orquestadores de IaC

!!! success "Aceptada · 2026-06-20"

## Contexto
El homelab requiere una capa de orquestación que ejecute Terraform y Ansible de forma centralizada, sin depender de que la máquina local del operador esté disponible o conectada, y sin exponer la infraestructura a modelos de ejecución que requieran abrir puertos públicos.

Las opciones evaluadas:

1. **Atlantis** — orquestador de Terraform centrado en flujos de PR (comentarios `plan`/`apply` en pull requests).
2. **AWX** — versión upstream open-source de Red Hat Ansible Automation Platform, UI completa sobre Ansible.
3. **GitOps push-based** (ej. CI/CD tradicional vía GitHub Actions triggereando despliegues hacia el homelab).
4. **GitOps pull-based** genérico (el propio nodo jala cambios, patrón tipo Flux/ArgoCD pero aplicado fuera de Kubernetes).
5. **Semaphore UI** — orquestador ligero de Ansible/Terraform/OpenTofu con UI propia, modelo de ejecución configurable.

## Decisión
Se usa **Semaphore UI** como capa de orquestación, en modelo **pull-based** (polling sobre el repositorio Git), corriendo en la VM de edge/management junto con Traefik.

## Alternativas consideradas

### Atlantis
- Orientado casi exclusivamente a Terraform, con un flujo de trabajo centrado en comentarios sobre pull requests de GitHub/GitLab (`atlantis plan`, `atlantis apply`).
- No tiene soporte nativo para orquestar Ansible — el homelab necesita ambos (Terraform para provisioning de VMs, Ansible para configuración dentro de ellas) bajo una sola herramienta de orquestación.
- Requiere un webhook entrante desde el proveedor Git, lo cual implica exponer un endpoint público o depender de un servicio de túnel — fricción adicional frente al modelo pull-based ya decidido como preferencia de red (ver decisión relacionada de Tailscale, sin exposición pública).

### AWX
- Funcionalmente el más completo de los evaluados (inventarios dinámicos, RBAC granular, scheduling avanzado), pero su costo operacional es desproporcionado al contexto de un solo operador.
- El despliegue de referencia de AWX asume un cluster de Kubernetes (k3s como mínimo) para correr sus propios componentes (task execution, receptor, PostgreSQL, Redis). Esto reintroduce exactamente el overhead que se descartó en la decisión de no usar Kubernetes para el resto del homelab (ver ADR-001) — sería inconsistente adoptarlo aquí solo para la capa de orquestación.
- Curva de aprendizaje alta y superficie de troubleshooting amplia para un beneficio que, en este contexto, no se materializa (no hay equipo, no hay necesidad de RBAC multi-usuario).

### GitOps push-based (CI/CD tradicional)
- Requiere que el runner de CI/CD (ej. GitHub Actions) tenga conectividad de red hacia el homelab para aplicar cambios — esto implica exponer un endpoint de la red interna hacia internet, o mantener un runner self-hosted con conectividad saliente activa permanentemente.
- Modelo push-based: el control de cuándo y qué se ejecuta vive fuera de la red del homelab. Esto es una superficie de ataque adicional y un punto de control externo que se prefiere evitar.

### GitOps pull-based genérico
- Conceptualmente correcto (el nodo decide cuándo jalar cambios, sin exponer nada), pero las herramientas maduras de este patrón (Flux, ArgoCD) están diseñadas específicamente para reconciliar estado de Kubernetes, no para ejecutar Terraform/Ansible sobre VMs. Adaptarlas fuera de su dominio nativo añade más complejidad que el problema que resuelven.

### Semaphore UI (elegido)
- Soporta Terraform, OpenTofu y Ansible de forma nativa bajo una sola UI — cubre ambas herramientas que el monorepo ya usa, sin necesidad de dos orquestadores distintos.
- Modelo de ejecución configurable que permite polling pull-based sobre el repo, sin necesidad de exponer webhooks entrantes ni puertos públicos — consistente con la decisión de red basada en Tailscale.
- Despliegue ligero: corre como contenedor Docker individual (más su base de datos), sin requerir un cluster de Kubernetes ni componentes adicionales — consistente con ADR-001 (Docker sobre K8s).
- Gestión de credenciales propia (Key Store para SSH keys, Variable Groups para secretos como `SOPS_AGE_KEY` y `PROXMOX_VE_API_TOKEN`), suficiente para las necesidades de un solo operador sin la complejidad de un sistema de secretos de grado empresarial.
- Curva de aprendizaje proporcional al problema: UI simple, conceptos limitados (Projects, Templates, Key Store, Variable Groups, Environments), sin el peso operacional de AWX.

## Consecuencias
- (+) Una sola herramienta de orquestación para Terraform y Ansible.
- (+) Sin exposición de puertos públicos ni webhooks entrantes — modelo pull-based consistente con la arquitectura de red basada en Tailscale.
- (+) Despliegue ligero (contenedor Docker), sin dependencia de Kubernetes.
- (+) Gestión de credenciales suficiente para el contexto, sin necesidad de un sistema de secretos externo adicional para la capa de orquestación (aunque SOPS+age sigue siendo el mecanismo de cifrado en reposo — ver ADR-003).
- (-) Menor madurez de ecosistema y comunidad comparado con AWX — aceptable dado que las funcionalidades core (ejecución de templates, Key Store, Variable Groups) ya cubren el caso de uso real.
- (-) Sin RBAC granular multi-usuario de nivel empresarial — irrelevante para un solo operador.
- (-) Single point of failure en la VM de edge si Semaphore cae — mitigado porque su disponibilidad solo es necesaria para *desplegar o modificar* infraestructura, no para que los servicios ya desplegados sigan operando.

## Relacionado
- ADR-001 (Docker sobre Kubernetes — consistencia de la decisión)
- ADR-003 (SOPS+age — mecanismo de secretos consumido por Semaphore vía Variable Groups)
- Decisión de red: Tailscale, sin exposición pública de servicios.

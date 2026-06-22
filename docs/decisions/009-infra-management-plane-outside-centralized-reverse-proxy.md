# ADR-009: Componentes de gestión de infraestructura fuera del reverse proxy centralizado

## Status

Accepted

## Context

El homelab usa Traefik como reverse proxy centralizado, corriendo en una VM dedicada (edge/management), con terminación TLS vía Cloudflare DNS-01 y un wildcard certificate. Este patrón es correcto y deseable para todos los servicios de aplicación (VM-per-service).

Sin embargo, existen tres componentes que en principio podrían enrutarse a través de ese mismo Traefik, pero que tienen una relación distinta con la infraestructura subyacente:

- **Proxmox VE (host)**: el hipervisor que aloja todas las VMs, incluyendo la VM de Traefik.
- **TrueNAS**: backend de almacenamiento (NFS/iSCSI), usado para backups, ISOs y/o discos de VM.
- **Semaphore**: herramienta de CI/CD para provisionar VMs vía Terraform/Ansible, corriendo dentro de una VM en Proxmox.

El problema identificado es una **dependencia circular de bootstrap**, que aparece en dos niveles distintos:

1. **Nivel host**: si Traefik vive en una VM dentro de Proxmox, y Proxmox falla (kernel panic, storage corrupto, fallo de host), no es posible levantar la VM de Traefik para enrutar el acceso al propio Proxmox que se necesita reparar. El mismo razonamiento aplica a TrueNAS si su acceso (UI, gestión de certificados) dependiera del Traefik centralizado.

2. **Nivel artefacto gestionado**: Semaphore no es solo un consumidor pasivo de la red que Traefik expone — es la herramienta que **provisiona y gestiona la propia VM de Traefik** vía Terraform/Ansible. Si Semaphore estuviera detrás de Traefik, y Traefik fuera el componente roto (corrupción de la VM, error en un cambio de Terraform, migración fallida), no habría forma de llegar a Semaphore para recrear o repararlo. Es la misma dependencia circular que el caso de Proxmox, pero un nivel más arriba en la pila: la herramienta de recuperación queda atrapada detrás de lo que necesita recuperar.

La excepción real es: para tareas que *no* involucran recrear o reparar Traefik —provisionar una VM nueva, correr un playbook sobre un servicio existente—, Semaphore sí depende de que Proxmox esté arriba, y eso es inevitable e independiente del reverse proxy. Pero ese no es el caso que define dónde debe vivir el acceso a Semaphore; el caso que lo define es la recuperación de Traefik mismo.

## Decision

Se clasifican los tres componentes en dos categorías según su rol respecto al plano de recuperación de la infraestructura:

### 1. Plano de recuperación (break-glass path) — fuera de Traefik

**Proxmox (host), TrueNAS y Semaphore** se acceden directamente por IP, sin pasar por el Traefik centralizado, usando mecanismos nativos de TLS:

- **TrueNAS**: ACME nativo vía DNS-01 con Cloudflare (Credentials → Certificates → ACME DNS-Authenticator con API token con permiso `Zone.DNS:Edit`). El certificado se renueva automáticamente sin intervención de Traefik ni de ningún componente que dependa de Proxmox.
- **Proxmox**: acceso directo por IP:8006. TLS vía ACME DNS-01 nativo de Proxmox (`pvenode acme`) si el proveedor lo soporta, o certificado autofirmado con bypass del warning del navegador como fallback aceptable. Lo prioritario es disponibilidad, no estética del certificado.
- **Semaphore**: acceso directo por IP:3000. TLS vía ACME DNS-01 si Semaphore expone esa opción nativamente, o autofirmado como fallback. La razón de incluirlo aquí no es su dependencia de Proxmox (que es inevitable en cualquier escenario), sino que **Semaphore es la herramienta que provisiona y repara la propia VM de Traefik**. Si Traefik se rompe, Semaphore debe seguir siendo alcanzable para recrearlo — de lo contrario el sistema queda sin ruta de recuperación.

Regla general: **el plano de gestión de la infraestructura que sostiene los servicios nunca se enruta a través de la infraestructura que gestiona — y esto incluye a las herramientas que provisionan piezas del propio reverse proxy, no solo al hipervisor.** Mismo principio que el uso de NICs dedicadas para IPMI/iDRAC/iLO en hardware físico, independientes del resto del tráfico de red.

### 2. Sin componentes en esta categoría por ahora

Ningún componente de gestión de infraestructura permanece detrás del Traefik centralizado bajo este ADR. Servicios de aplicación (VM-per-service) siguen enrutándose normalmente a través de Traefik; esta categoría queda reservada para casos futuros donde un componente sea estrictamente consumidor de la infraestructura sin participar en su propia recuperación.

## Consequences

**Positivas:**
- Existe una ruta de acceso a Proxmox, TrueNAS y Semaphore independiente del estado de la VM de Traefik — incluyendo el caso específico de que Traefik mismo necesite ser recreado o reparado.
- TrueNAS y Proxmox usan el mismo dominio/proveedor (Cloudflare) que el resto del homelab, sin introducir un mecanismo de gestión de certificados adicional.
- Se elimina la dependencia circular en la que la herramienta de recuperación de Traefik dependería de que Traefik estuviera operativo.

**Negativas / trade-offs:**
- Tres puntos de configuración ACME adicionales (TrueNAS, Proxmox, Semaphore) fuera del `dynamic.yml` de Traefik, que deben mantenerse y renovarse de forma independiente (aunque son automáticos una vez configurados).
- Acceso directo a Proxmox/TrueNAS/Semaphore implica exponer sus puertos de gestión (8006, 443, 3000) en la red interna sin la capa de middleware/autenticación centralizada que Traefik podría aplicar a otros servicios. Mitigado por estar en red interna/LAN, no expuesto a internet.
- Semaphore pierde cualquier beneficio operativo que tuviera por estar detrás de Traefik (URL unificada bajo el mismo dominio, middlewares compartidos como auth centralizada). Se considera un costo aceptable frente al riesgo de quedar sin ruta de recuperación para Traefik.

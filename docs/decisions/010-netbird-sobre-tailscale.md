# ADR-010: NetBird (Cloud, gestionado) sobre Tailscale para acceso remoto de administración

!!! success "Aceptada · 2026-06-21/22"

## Contexto

El homelab requiere una solución de overlay network (mesh VPN) para que el operador acceda remotamente a la infraestructura de administración (Proxmox, TrueNAS, Semaphore — ver ADR-009) y a las VMs de servicio, sin exponer puertos públicamente ni depender de un firewall perimetral como único control de acceso.

Tailscale ya estaba en uso como solución de acceso remoto. Durante una evaluación práctica de NetBird (instalación de prueba, no solo revisión de documentación) surgieron tres factores que motivaron reconsiderar la elección:

1. **Apertura del control plane.** Tailscale es cliente open-source con coordination server propietario y cerrado — no existe versión oficial self-hosteable (Headscale es una reimplementación de terceros, no soportada por Tailscale Inc., con rezago de features). NetBird publica el código completo de su control plane (Management, Signal, Relay) bajo AGPLv3, con la opción real de self-hostear con el mismo binario que usa su Cloud — sin reimplementación de terceros de por medio.

2. **Experiencia de configuración.** El dashboard de NetBird expone de forma más directa e intuitiva la creación de grupos, políticas de acceso (ACLs) y rutas de red, reduciendo la fricción para expresar reglas de acceso granular. Tailscale esconde esa complejidad detrás de un archivo de políticas en sintaxis HuJSON propia, más simple en su superficie inicial pero más opaco al momento de configurar reglas avanzadas.

3. **Consolidación de herramientas.** Existía un plan tentativo de usar Tailscale para acceso directo a infraestructura de administración y Twingate para acceso a servicios expuestos por las VMs, bajo la premisa de que Twingate permite acceso a recursos sin instalar agente en la máquina destino. Al evaluar el caso de uso real, esa ventaja de Twingate no aplica: el operador controla cada VM del homelab y puede instalar un agente sin fricción adicional vía Ansible. El modelo de grupos y políticas de NetBird cubre ambos casos (acceso administrativo completo y acceso granular por servicio) desde una sola plataforma, eliminando la necesidad de una segunda herramienta.

Se evaluó también el costo operativo de self-hostear el control plane completo de NetBird (Management + Signal + Relay + Dashboard + un Identity Provider OIDC como prerequisito). Aunque la infraestructura ya disponible (Traefik con Cloudflare DNS-01, PostgreSQL) reduce significativamente ese costo, se determinó que no se justifica en esta etapa: el control plane es un componente en la ruta crítica para *establecer* o *renegociar* acceso remoto, y autohostearlo sin alta disponibilidad introduce un punto único de falla adicional sobre el ya existente en el nodo Proxmox, sin beneficio proporcional al esfuerzo dado el tamaño actual del homelab (single-node).

## Decisión

Migrar de Tailscale a **NetBird Cloud** (oferta SaaS gratuita de NetBird) como solución de acceso remoto, para administración de infraestructura y acceso a servicios de VMs, usando su modelo de grupos y políticas de acceso (ACLs) en lugar de mantener Tailscale y/o sumar Twingate como herramienta separada.

El control plane (Management, Signal, Relay) permanece gestionado por NetBird Cloud, no self-hosteado, en esta etapa.

## Alternativas consideradas

- **Mantener Tailscale.** Más maduro, mayor tiempo en producción a escala, mejor soporte de plataformas periféricas (routers, NAS). Rechazado como única solución por: control plane cerrado (no alineado con la preferencia de garantías técnicas de privacidad sobre promesas contractuales), y mayor fricción para expresar políticas de acceso avanzadas comparado con la experiencia evaluada en NetBird.

- **Tailscale + Twingate (dos herramientas en capas).** Plan original: Tailscale para acceso directo a máquinas de administración, Twingate para servicios expuestos por VMs. Rechazado porque la ventaja diferencial de Twingate (acceso a recursos sin agente en la máquina destino) no aplica cuando se controla cada VM, y mantener dos plataformas de identidad y políticas separadas añade costo operativo sin beneficio real para este caso de uso.

- **NetBird self-hosteado (Management + Signal + Relay propios).** Evaluado y descartado para esta etapa. Requiere un Identity Provider OIDC (Authentik/Keycloak) como prerequisito no resuelto aún, además de exponer el rango UDP de TURN/Coturn en el gateway si se autohostea también el Relay. El control plane sin alta disponibilidad en un homelab de un solo nodo no mejora la resiliencia respecto a depender de NetBird Cloud, y sí añade superficie de mantenimiento. Queda como opción de migración futura: el protocolo, cliente y binarios de servidor son los mismos entre Cloud y self-hosted, por lo que la puerta de salida permanece abierta sin costo de reescritura si se decide migrar después.

- **Cloudflare Tunnel / Cloudflare Access.** Resuelve un problema distinto (exposición selectiva de servicios HTTP(S) hacia terceros mediante proxy inverso de salida, sin overlay network entre dispositivos propios) y no es sustituto de una mesh VPN para acceso administrativo. Se mantiene como herramienta complementaria, no evaluada como alternativa directa en esta decisión.

## Consecuencias

- (+) Control plane open-source (AGPLv3), con código auditable y opción real de self-hosting futuro sin cambio de protocolo ni de cliente.
- (+) Una sola plataforma de identidad y políticas de acceso para administración de infraestructura y acceso a servicios de VMs, en lugar de dos herramientas separadas (Tailscale + Twingate).
- (+) Soporte de Terraform provider oficial de NetBird, permitiendo declarar setup keys, grupos, políticas y rutas como código, consistente con la filosofía de IaC del resto del monorepo.
- (+) Configuración de ACLs y grupos más directa que el archivo de políticas HuJSON de Tailscale, reduciendo fricción para reglas de acceso granular.
- (-) Control plane gestionado por terceros (NetBird Cloud) en esta etapa, no self-hosteado — la garantía de privacidad técnica completa (control total sobre Management/Signal/Relay) queda diferida, no resuelta. Se acepta este trade-off por menor costo operativo inmediato; mitigado por la posibilidad de migrar a self-hosted sin reescritura.
- (-) Menor madurez relativa frente a Tailscale en años de producción a escala y soporte de plataformas periféricas. Mitigado mediante validación práctica previa a la migración completa (roaming entre redes, recuperación tras reinicio, comportamiento de NAT traversal/relay, paridad de ACLs) antes de retirar Tailscale de cada dispositivo.
- (-) Migración debe hacerse dispositivo por dispositivo, manteniendo Tailscale en paralelo hasta confirmar paridad de reglas de acceso, para evitar pérdida de acceso administrativo durante la transición.

## Relacionado

- ADR-009 (break-glass path: Proxmox, TrueNAS y Semaphore accesibles directo por IP, sin pasar por Traefik — el acceso remoto vía NetBird es una capa adicional sobre, no un sustituto de, esa decisión)
- Decisión pendiente (no formalizada como ADR aún): self-hosting del control plane de NetBird, condicionado a contar con un Identity Provider OIDC propio en el homelab.

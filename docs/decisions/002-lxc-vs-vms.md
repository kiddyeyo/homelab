# ADR-002: VMs sobre contenedores LXC como unidad de aislamiento en Proxmox

!!! success "Aceptada · 2026-06-20"

## Contexto
Proxmox VE soporta de forma nativa dos unidades de virtualización: VMs (KVM/QEMU, virtualización completa) y LXC (contenedores de sistema, virtualización a nivel de kernel compartido con el host). Ambas son opciones válidas para alojar los servicios del homelab y ambas tienen soporte de primera clase en el provider `bpg/proxmox` de Terraform.

La pregunta es a qué nivel se aísla cada servicio: ¿VM dedicada por stack, o LXC dedicado por stack?

## Decisión
Se usa **VM (KVM/QEMU)** como unidad de aislamiento por servicio/stack, no LXC. Cada servicio (Traefik+Semaphore en edge, Immich, Vaultwarden, Paperless-NGX, Technitium DNS) corre en su propia VM, y dentro de la VM, los servicios corren en Docker (ver ADR-001).

## Alternativas consideradas

### LXC
- Más liviano en uso de recursos (sin overhead de kernel completo ni de virtualización de hardware), arranque más rápido.
- Rechazado por tres razones concretas:

  1. **Seguridad**: LXC comparte el kernel del host. Un escape de contenedor en LXC tiene una superficie de impacto mayor sobre el hypervisor que un escape de VM, que está contenido por la capa de virtualización de hardware (Intel VT-x/AMD-V). Para servicios que manejan datos sensibles (Vaultwarden = credenciales, Paperless-NGX = documentos personales), el aislamiento a nivel de kernel es preferible.

  2. **Fricción de herramientas**: varias herramientas e imágenes oficiales (especialmente las que ya vienen empaquetadas como contenedores Docker — Immich, Vaultwarden, Paperless-NGX) asumen un kernel propio y un Docker Engine corriendo de forma estándar. Ejecutar Docker *dentro* de un LXC (Docker-in-LXC) es técnicamente posible pero requiere contenedores privilegiados o configuración adicional de nesting, lo que reintroduce buena parte del riesgo de seguridad que se buscaba evitar al usar LXC en primer lugar.

  3. **Integración con Terraform**: el soporte de `bpg/proxmox` para VMs (`proxmox_virtual_environment_vm`) es más maduro y directo para el flujo de trabajo elegido (cloud-init, templates, clonación) que el de LXC (`proxmox_virtual_environment_container`). El pipeline de template → clone vía cloud-init que ya se definió para las VMs no tiene un equivalente igualmente directo en LXC.

### VM (elegido)
- Aislamiento real a nivel de hypervisor, kernel independiente por VM.
- Cloud-init nativo para provisioning inicial (hostname, SSH keys, red), lo cual encaja directamente con el flujo de templates de Terraform ya decidido.
- Es el modelo que la industria asume por default para cargas de trabajo que se despliegan vía Docker/Kubernetes — la gran mayoría de documentación, guías de hardening y patrones de IaC asumen "VM o baremetal" como la unidad base, no LXC. Esto reduce la fricción al buscar referencias o solucionar problemas.

## Consecuencias
- (+) Aislamiento de seguridad más fuerte entre servicios — relevante dado que varios manejan datos sensibles (passwords, documentos, fotos personales).
- (+) Compatibilidad directa y sin fricción con Docker Engine estándar, sin necesidad de nesting ni contenedores privilegiados.
- (+) Soporte de Terraform más maduro y alineado con el flujo de template/clone ya adoptado.
- (-) Mayor consumo de recursos (RAM, disco) por VM comparado con LXC, dado el overhead de un kernel completo por servicio. Aceptable en el contexto de los recursos disponibles en `pve2`.
- (-) Arranque más lento que LXC — irrelevante para servicios de larga duración que no se reinician con frecuencia.

## Relacionado
- ADR-001 (Docker como runtime de servicios)
- Decisión relacionada: un VM por stack de servicio, sin Docker socket expuesto entre VMs.

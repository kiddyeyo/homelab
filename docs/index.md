---
hide:
  - navigation
  - footer
---
# Documentación de Infraestructura Homelab

## Sobre el Proyecto

Este sitio centraliza la documentación técnica del homelab, un ecosistema de servidores diseñado para el auto-alojamiento de servicios, la gestión de datos personales y la automatización de infraestructura. El objetivo es mantener un entorno controlado, seguro y reproducible vía Infraestructura como Código (IaC), donde nada se configura a mano salvo el bootstrap inicial de cada nodo.

## Arquitectura de Hardware

La infraestructura se apoya en dos nodos físicos principales, segmentando las tareas de computación y almacenamiento de datos:

- **Nodo de Cómputo (`pve2`):** Mini PC Beelink con procesador AMD Ryzen 7 6800U (8C/16T) y 32 GB de RAM, ejecutando Proxmox VE 8.4 sobre ZFS. Es el hipervisor principal y aloja todas las máquinas virtuales de la infraestructura.
- **Nodo de Almacenamiento (`truenas`):** Hardware dedicado con procesador Intel Core i3-8100 y 16 GB de RAM, ejecutando TrueNAS SCALE. Provee almacenamiento persistente sobre ZFS (con la mayor parte de la RAM dedicada al ARC) y exporta recursos vía NFS/SMB al resto de la infraestructura.

## Pilares de la Infraestructura

El funcionamiento del laboratorio se basa en los siguientes componentes fundamentales:

1. **Virtualización y Orquestación:** Proxmox VE gestiona los recursos físicos. Cada servicio se aísla en su **propia VM (KVM/QEMU)** —no en contenedores LXC— y dentro de la VM corre como un stack de **Docker Compose** (ver [ADR-001](decisions/001-docker-vs-kubernetes-baremetal.md) y [ADR-002](decisions/002-lxc-vs-vms.md)).
2. **Automatización (IaC):** **Terraform** (provider `bpg/proxmox`) aprovisiona las VMs y **Ansible** despliega los servicios. Toda ejecución real es centralizada mediante **Semaphore UI** (manual) y un **GitHub Actions self-hosted runner** (automático y granular); la ejecución local de `apply`/`destroy` está prohibida. El estado de Terraform vive en un backend **PostgreSQL** compartido (ver [ADR-004](decisions/004-semaphore-vs-awx.md), [ADR-006](decisions/006-semaphore-github-actions-dual-vs-gitlab-jenkins.md), [ADR-007](decisions/007-terraform-backend-postgresql.md) y [ADR-008](decisions/008-ejecucion-centralizada-terraform-ansible.md)).
3. **Red y Seguridad:** **Traefik** actúa como reverse proxy centralizado, terminando TLS para todos los servicios mediante certificados wildcard vía Cloudflare DNS-01, configurado por File Provider. **NetBird** provee la red overlay (mesh VPN) para el acceso remoto de administración y el control de acceso granular por servicio, y **Technitium DNS** resuelve los nombres internos con zona autoritativa propia. Los planos de gestión (Proxmox, TrueNAS, Semaphore) se mantienen fuera del reverse proxy centralizado para evitar dependencias circulares de bootstrap (ver [ADR-005](decisions/005-traefik-vs-caddy-nginx.md), [ADR-009](decisions/009-infra-management-plane-outside-centralized-reverse-proxy.md), [ADR-010](decisions/010-netbird-sobre-tailscale.md), [ADR-011](decisions/011-netbird-resources-granularidad.md) y [ADR-012](decisions/012-technitium-sobre-pihole.md)).
4. **Gestión de Secretos:** Los secretos se cifran con **SOPS + age** y se versionan junto al código; la clave privada se inyecta en tiempo de ejecución en los puntos de ejecución centralizados (ver [ADR-003](decisions/003-sops-secrets-management.md)).

## Servicios Desplegados

El homelab integra diversas soluciones de software, cada una en su propia VM:

- **Gestión de Medios:** Immich para la organización y respaldo de fotografías.
- **Gestión Documental:** Paperless-NGX para el procesamiento y archivo digital de documentos mediante OCR.
- **Seguridad:** Vaultwarden para la gestión centralizada de credenciales.

## Organización de la Documentación

El contenido de esta wiki está estructurado para facilitar la consulta técnica:

- **Infraestructura:** Configuración de bootstrap manual de los nodos base —[Proxmox VE](infrastructure/proxmox.md) y [TrueNAS SCALE](infrastructure/truenas.md)—, cubriendo hardware, red física y almacenamiento. El aprovisionamiento de VMs es declarativo y su fuente de verdad es el código en `terraform/` y `ansible/`.
- **Registro de Decisiones (ADRs):** Architecture Decision Records que documentan el *porqué* de cada elección técnica del stack —runtime, virtualización, secretos, orquestación, reverse proxy, red overlay, DNS y tooling—, con las alternativas evaluadas y descartadas.

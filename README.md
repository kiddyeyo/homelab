# Homelab Monorepo

Repositorio centralizado que contiene toda la infraestructura como código, automatización y documentación del homelab. El entorno ejecuta servicios auto-alojados sobre Proxmox VE, Docker Compose y almacenamiento NFS desde TrueNAS.

## Hardware

| Nodo | Hardware | Rol |
| :--- | :--- | :--- |
| **pve2** | Beelink Mini PC — AMD Ryzen 7 6800U, 32 GB RAM | Hipervisor Proxmox VE, ejecuta todos los LXC/VMs |
| **truenas** | Intel Core i3-8100, 16 GB RAM | Almacenamiento NFS/SMB con TrueNAS SCALE |

## Estructura del Repositorio

```
homelab/
├── ansible/        # Automatización: aprovisionamiento de LXC, despliegue de servicios
├── docker/         # Stacks de Docker Compose por servicio
├── terraform/      # Provisión de VMs en Proxmox vía IaC
└── docs/           # Wiki técnica en Markdown servida con MkDocs
```

## Servicios

| Servicio | Función |
| :--- | :--- |
| Traefik | Proxy inverso + TLS (Let's Encrypt) |
| Vaultwarden | Gestor de contraseñas (API Bitwarden) |
| Immich | Gestión de fotografías con IA |
| Paperless-ngx | Gestión documental con OCR |
| Homepage | Dashboard de servicios |
| Monitoring | Observabilidad de logs (Dozzle) |
| Semaphore UI | Interfaz web para ejecutar playbooks de Ansible |

## Stack Tecnológico

| Capa | Tecnología |
| :--- | :--- |
| Hipervisor | Proxmox VE 8.4 |
| Red / Firewall | OPNsense |
| DNS | Technitium DNS |
| Proxy inverso | Traefik v3 |
| VPN mesh | NetBird |
| Orquestación | Docker Compose |
| IaC | Terraform (`bpg/proxmox` provider) |
| Automatización | Ansible |
| Gestión de secretos | SOPS + age |

## Documentación

- Para contribuir al repo (setup, linting, secretos): [CONTRIBUTING.md](CONTRIBUTING.md)
- Para operar la infraestructura (reglas críticas): [OPERATIONS.md](OPERATIONS.md)
- Wiki técnica detallada: `make serve`
- Decisiones de arquitectura: [`docs/decisions/`](docs/decisions/)

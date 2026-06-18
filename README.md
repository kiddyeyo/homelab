# Homelab Monorepo

Repositorio centralizado que contiene toda la infraestructura como código, automatización y documentación del homelab personal. El entorno ejecuta servicios auto-alojados sobre Proxmox VE con contenedores LXC, Docker Compose y almacenamiento NFS desde TrueNAS.

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
├── terraform/      # Provisión de VMs y templates en Proxmox vía IaC
└── docs/           # Wiki técnica en Markdown servida con MkDocs
```

## Módulos

### [`ansible/`](ansible/README.md)
Playbooks y roles para la configuración base de los nodos (SSH, UFW, Tailscale, Docker CE) y el despliegue de cada servicio. Los secretos se gestionan con SOPS + age.

### [`docker/`](docker/README.md)
Un directorio por servicio, cada uno con su `docker-compose.yml` y `.env` cifrado. Traefik actúa como proxy inverso con TLS vía Cloudflare DNS-01.

| Servicio | Función |
| :--- | :--- |
| Traefik | Proxy inverso + TLS (Let's Encrypt) |
| Vaultwarden | Gestor de contraseñas (API Bitwarden) |
| Immich | Gestión de fotografías con IA |
| Paperless-ngx | Gestión documental con OCR |
| Homepage | Dashboard de servicios |
| Open WebUI | Interfaz web para LLMs locales |
| LiteLLM | Proxy/gateway unificado para modelos de IA |
| Monitoring | Observabilidad de logs (Dozzle) |
| Pi-hole | Filtrado DNS a nivel de red |

### [`terraform/`](terraform/README.md)
Dos workspaces independientes: `setup-templates/` descarga la imagen cloud y crea el template en Proxmox; `deploy-vms/` clona el template y provisiona VMs con cloud-init. Usa el provider `bpg/proxmox`.

### [`docs/`](docs/README.md)
Documentación técnica detallada en formato "As-Built", organizada por capa (infraestructura, red, aplicaciones). Servida localmente con MkDocs.

```bash
cd docs && mkdocs serve
```

## Stack Tecnológico

| Capa | Tecnología |
| :--- | :--- |
| Hipervisor | Proxmox VE 8.4 |
| Red / Firewall | OPNsense |
| DNS | Pi-hole (`192.168.100.23`) |
| Proxy inverso | Traefik v3 |
| VPN mesh | Tailscale |
| Orquestación | Docker Compose |
| IaC | Terraform (`bpg/proxmox` provider) |
| Automatización | Ansible |
| Gestión de secretos | SOPS + age |
| Dominio público | `infra.sintaq.net` |

## Gestión de Secretos

Los secretos nunca se almacenan en texto plano. Se usa SOPS con una clave age para cifrar archivos `.env` y `vars/secrets.yml`. La clave privada (`key.txt`, `*.age`) está en `.gitignore`.

```bash
# Ver secreto descifrado
sops -d ansible/vars/secrets.yml

# Editar secreto cifrado
sops ansible/vars/secrets.yml
```

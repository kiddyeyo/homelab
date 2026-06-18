# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Monorepo Overview

Homelab infrastructure-as-code for a Proxmox VE environment. Services run as Docker Compose stacks inside individual LXC containers, provisioned by Ansible and (optionally) by Terraform.

```
homelab/
├── ansible/    # Provisioning + service deployment automation
├── docker/     # Docker Compose stacks (one directory per service)
├── terraform/  # VM templates and VM provisioning on Proxmox
└── docs/       # MkDocs wiki (Spanish, As-Built format)
```

**Domain:** `infra.sintaq.net` — all services are subdomains.
**LXC IP range:** `192.168.100.25–.31` on `pve2` (`192.168.100.21`).

---

## Ansible (`ansible/`)

Manages LXC containers on Proxmox. `vars/secrets.yml` is SOPS-encrypted and gitignored — must exist locally before running any playbook.

```bash
# Install collections (first time)
ansible-galaxy collection install -r requirements.yml -p ./collections

# Full site run (maintenance → docker update → deploy all)
ansible-playbook playbooks/site.yml

# Deploy all services
ansible-playbook playbooks/deploy_all.yml

# Deploy a single service
ansible-playbook playbooks/deploy/deploy_traefik.yml

# Provision/re-provision LXC containers
ansible-playbook playbooks/provision/setup_lxcs.yml

# Target a specific host
ansible-playbook playbooks/deploy_all.yml --limit vaultwarden

# Dry run
ansible-playbook playbooks/deploy_all.yml --check
```

### Inventory groups
- `proxmox_host` — bare-metal Proxmox node
- `lxcs` — all LXC containers (pihole, vaultwarden, homepage, monitoring, immich, paperlessngx, traefik, openwebui, litellm)
- `docker_hosts` — all LXCs except pihole (pihole is not Docker-managed)

### Playbook hierarchy
```
playbooks/
  site.yml              # entry point: maintenance → update_docker → deploy_all
  deploy_all.yml        # imports all deploy/* in order (traefik first)
  maintenance/
    update_systems.yml  # apt dist-upgrade + conditional reboot
    update_docker.yml   # pull images, recreate, prune (serial: 1)
  provision/
    setup_lxcs.yml      # SSH keys, UFW, Tailscale, Docker CE
  deploy/
    deploy_<service>.yml
```

### Deploy playbook pattern (per service)
1. Create directories on remote host
2. `sops -d` on localhost → write plaintext to remote
3. Copy `docker-compose.yml` and config files from `compose_files_path` → `{{ base_path }}/<service>/`
4. `docker compose up -d --force-recreate --remove-orphans`

### Key variables
- `inventory/group_vars/all.yml` — non-secret defaults: `ansible_user`, SSH key path, `compose_files_path`
- `compose_files_path` — defaults to `../../compose-files`; in this monorepo it resolves to `../docker`
- `vars/secrets.yml` — `user`, `user_password`, `base_path`, `ssh_key`, `tailscale_auth_key`

---

## Docker (`docker/`)

One directory per service, each with `docker-compose.yml` and a SOPS-encrypted `.env`.

| Directory | Service | LXC |
|-----------|---------|-----|
| `traefik/` | Reverse proxy + TLS (Cloudflare DNS-01) | traefik |
| `vaultwarden/` | Bitwarden-compatible password manager | vaultwarden |
| `immich/` | Photo management with AI | immich |
| `paperlessngx/` | Document management + OCR | paperlessngx |
| `homepage/` | Service dashboard | homepage |
| `openwebui/` | LLM web interface | openwebui |
| `litellm/` | LLM proxy/gateway | litellm |
| `monitoring/` | Log viewer (Dozzle) | monitoring |

Traefik handles all ingress via Docker labels. Tailscale + UFW restrict access to Tailscale IPs and local LAN. Never commit plaintext `.env` files.

---

## Terraform (`terraform/`)

Provider: `bpg/proxmox` v0.80.0. Two independent workspaces — run commands from inside each workspace directory.

```bash
terraform init
terraform plan
terraform apply
terraform destroy
```

### Workspaces
- **`setup-templates/`** — downloads a cloud image to Proxmox and creates a stopped VM template. Run before `deploy-vms/`. Uses `modules/template`. The image download has `prevent_destroy = true`.
- **`deploy-vms/`** — clones the template into running VMs with cloud-init (static IP, SSH keys, DNS). Uses `modules/instance`.

### Authentication
Requires API token auth **and** SSH agent (`ssh-agent` must be running):
- `api_token` format: `user@realm!token-name=uuid`
- `insecure = true` (self-signed cert on PVE)

Credentials in `terraform.tfvars` (gitignored). Known issue: SSH key changes on `modules/instance` force VM replacement (upstream bpg/proxmox#373) — mitigated with `ignore_changes` on `initialization["user_account"]`.

### Defaults
| Setting | Value |
|---------|-------|
| Storage | `local-zfs` |
| Network bridge | `vmbr0` |
| DNS | `192.168.100.23` |
| DNS domain | `infra.sintaq.net` |
| Gateway | `192.168.100.1` |
| CPU type | `x86-64-v2-AES` |
| BIOS | `seabios` |

---

## Docs (`docs/`)

MkDocs wiki in Markdown. No build system or test suite — pure documentation source.

```bash
cd docs && mkdocs serve   # preview at http://127.0.0.1:8000
```

Structure: `docs/infrastructure/`, `docs/network/`, `docs/apps/`. All content written in **Spanish**. Documents follow an **As-Built** template: Document Control block at the top, numbered sections, tables for specs and containers. API keys and passwords are never in Markdown — referenced by placeholder name only.

---

## Secrets Management (SOPS + age)

```bash
# View decrypted
sops -d ansible/vars/secrets.yml

# Edit encrypted
sops ansible/vars/secrets.yml
```

The age public key is in `.sops.yaml` (gitignored). Private key files (`*.age`, `key.txt`) are also gitignored and must be present locally.

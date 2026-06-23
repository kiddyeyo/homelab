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

**Domain:** `infra.sintaq.net` — all services are subdomains. **LXC IP range:** `192.168.100.25–.31` on `pve2` (`192.168.100.21`).

**Hardware:**
- **pve2** — Beelink Mini PC (AMD Ryzen 7 6800U, 32 GB RAM) — Proxmox VE hypervisor, runs all LXC/VMs
- **truenas** — Intel Core i3-8100, 16 GB RAM — NFS/SMB storage with TrueNAS SCALE

---

## Makefile (primary dev interface)

The `Makefile` is the main entrypoint for local development tasks. It does **not** operate infrastructure directly.

```bash
# Setup
make setup          # Full dev environment setup: lefthook + uv sync + pnpm install + tf-init + galaxy-install
make galaxy-install # Install Ansible collections from requirements.yml (repo root)
make tf-init        # Run `terraform init` in all Terraform roots (for LSP support)

# Linting & formatting
make lint           # Run all linters: yaml-lint + ansible-lint + compose-lint + tf-validate
make fmt            # Format all files: yaml-fmt + tf-fmt
make yaml-lint      # yamllint + prettier --check on all YAML files
make yaml-fmt       # Format YAML files with prettier (applies changes)
make ansible-lint   # ansible-lint on ansible/
make compose-lint   # docker compose config --quiet on all docker-compose.yml files
make tf-fmt         # terraform fmt -recursive on terraform/
make tf-validate    # terraform validate on all root modules

# Secrets
make encrypt-all    # SOPS-encrypt all sensitive files in-place
make decrypt-all    # SOPS-decrypt all sensitive files in-place (not recommended — see CONTRIBUTING)
make rekey          # Update SOPS recipients on all encrypted files (run after editing .sops.yaml)

# Docs
make serve          # Launch MkDocs dev server (mkdocs.yml is at repo root)
make build          # Build static MkDocs site to site/
make help           # List all targets with descriptions
```

### Python tooling (uv)

Python tools (`ansible-core`, `ansible-lint`, `mkdocs`, `yamllint`) are pinned in `pyproject.toml` and managed via `uv`. All Python commands in the Makefile use `uv run <tool>`. Run `uv sync` once (included in `make setup`) to install them into `.venv`.

### Node.js tooling (pnpm)

`prettier` (YAML formatting) is managed via `pnpm` and `package.json`. Run `pnpm install` once (included in `make setup`). Invoked as `pnpm exec prettier`.

---

## Ansible (`ansible/`)

Manages LXC containers on Proxmox. `vars/secrets.yml` is SOPS-encrypted and gitignored — must exist locally before running any playbook.

```bash
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
- `lxcs` — all LXC containers (pihole, vaultwarden, homepage, monitoring, immich, paperlessngx, traefik)
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

### Ansible collections (pinned)
Declared in `requirements.yml` at repo root. Install with `make galaxy-install`.
- `community.docker` 5.2.1
- `community.general` 13.1.0

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
| `monitoring/` | Log viewer (Dozzle) | monitoring |
| `semaphoreui/` | Ansible Semaphore web UI | — |

Traefik handles all ingress via Docker labels. Tailscale + UFW restrict access to Tailscale IPs and local LAN. Never commit plaintext `.env` files.

---

## Terraform (`terraform/`)

Provider: `bpg/proxmox` v0.80.0. Two independent workspaces — run commands from inside each workspace directory. `setup-templates/` also uses the `carlpett/sops` provider to read secrets directly from SOPS-encrypted `.tfvars` files.

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

MkDocs wiki in Markdown. `mkdocs.yml` lives at the **repo root** (not inside `docs/`).

```bash
make docs-serve   # or: mkdocs serve
make docs-build   # or: mkdocs build
```

Structure: `docs/infrastructure/`, `docs/network/`, `docs/apps/`. All content written in **Spanish**. Documents follow an **As-Built** template: Document Control block at the top, numbered sections, tables for specs and containers. API keys and passwords are never in Markdown — referenced by placeholder name only.

---

## Secrets Management (SOPS + age)

```bash
# View decrypted
sops -d ansible/vars/secrets.yml

# Edit encrypted
sops ansible/vars/secrets.yml

# Bulk encrypt/decrypt all sensitive files
make encrypt-all
make decrypt-all

# Update recipients after editing .sops.yaml
make rekey
```

The age public key is in `.sops.yaml` (at repo root). Private key files (`*.age`, `key.txt`) are gitignored and must be present locally.

**Pre-commit hooks (lefthook):** five checks run automatically on every commit:
1. `check-sops-encrypted` — blocks commits with plaintext sensitive files (no `ENC[AES256` marker)
2. `yaml-lint` — runs `yamllint` + `prettier --check` on staged YAML files
3. `ansible-lint` — runs `ansible-lint` on staged Ansible files
4. `compose-lint` — runs `docker compose config` on staged `docker-compose.yml` files
5. `terraform-fmt` / `terraform-validate` — checks HCL formatting and validates staged `.tf` files

Run `make setup` once after cloning to install all hooks. Run `make encrypt-all` before committing if you edited secrets.

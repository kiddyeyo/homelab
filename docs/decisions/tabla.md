---
hide:
  - toc
---
# Registro de Decisiones (ADRs)

Cada **Architecture Decision Record (ADR)** documenta el *porqué* de una elección técnica del homelab: el contexto que la motivó, la decisión tomada y las alternativas que se evaluaron y descartaron. Son la fuente de verdad del razonamiento detrás del stack — no el *cómo* (eso vive en el código).

## Resumen

| # | Decisión | Sobre qué elige | Estado |
|---|----------|-----------------|--------|
| [001](001-docker-vs-kubernetes-baremetal.md) | **Docker Compose** como runtime de servicios | vs. Kubernetes / baremetal | :material-check-circle:{ .adr-ok } Aceptada |
| [002](002-lxc-vs-vms.md) | **VMs (KVM/QEMU)** como unidad de aislamiento | vs. contenedores LXC | :material-check-circle:{ .adr-ok } Aceptada |
| [003](003-sops-secrets-management.md) | **SOPS + age** para gestión de secretos | vs. Doppler / Infisical / Vault / Ansible Vault | :material-check-circle:{ .adr-ok } Aceptada |
| [004](004-semaphore-vs-awx.md) | **Semaphore UI** como orquestador de IaC | vs. AWX / Atlantis / GitOps | :material-check-circle:{ .adr-ok } Aceptada |
| [005](005-traefik-vs-caddy-nginx.md) | **Traefik** como reverse proxy | vs. Caddy / Nginx | :material-check-circle:{ .adr-ok } Aceptada |
| [006](006-semaphore-github-actions-dual-vs-gitlab-jenkins.md) | **Semaphore + GitHub Actions runner** (dual) | vs. GitLab CI / Jenkins / Drone | :material-check-circle:{ .adr-ok } Aceptada |
| [007](007-terraform-backend-postgresql.md) | **PostgreSQL** como backend de `tfstate` | vs. local / Consul / MinIO | :material-check-circle:{ .adr-ok } Aceptada |
| [008](008-ejecucion-centralizada-terraform-ansible.md) | **Ejecución centralizada** (local prohibida) | Semaphore / GH Actions únicamente | :material-check-circle:{ .adr-ok } Aceptada |
| [009](009-infra-management-plane-outside-centralized-reverse-proxy.md) | **Gestión fuera del reverse proxy central** | evitar dependencia circular de bootstrap | :material-check-circle:{ .adr-ok } Aceptada |
| [010](010-netbird-sobre-tailscale.md) | **NetBird** para acceso remoto | vs. Tailscale | :material-check-circle:{ .adr-ok } Aceptada |
| [011](011-netbird-resources-granularidad.md) | **NetBird Resources** para acceso granular | vs. ForwardAuth / mTLS / IPAllowList | :material-check-circle:{ .adr-ok } Aceptada |
| [012](012-technitium-sobre-pihole.md) | **Technitium DNS** con zona autoritativa | vs. Pi-hole | :material-check-circle:{ .adr-ok } Aceptada |
| [013](013-formatters-y-linters-del-monorepo.md) | **Stack de formatters y linters** del monorepo | criterio por tipo de archivo y etapa | :material-check-circle:{ .adr-ok } Aceptada |
| [014](014-pinning-versiones-uv-pnpm.md) | **Pinning de versiones** con uv + pnpm | lockfiles por proyecto, no global | :material-check-circle:{ .adr-ok } Aceptada |

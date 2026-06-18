# As-Built Documentation: Proxmox VE Hypervisor

## Document Control

* **Hostname:** `pve2`
* **Cluster:** `pve-cluster`
* **Role:** Compute Node / Hypervisor
* **Management IP:** `192.168.100.21`
* **OS:** Proxmox VE 8.4.0 (Kernel: `6.8.12-20-pve`)

## 1. Hardware Specifications & Infrastructure Base

El nodo opera sobre hardware compacto (Mini PC Beelink).

| Componente | Especificación | Detalles / Estado |
| :--- | :--- | :--- |
| **CPU** | AMD Ryzen 7 6800U | 8 Cores / 16 Threads (2.7GHz - 4.7GHz) + iGPU AMD Radeon 680M |
| **RAM** | 32 GB (4x 8 GB Micron) | 6000 MHz (~28 GB / 27843.6 MiB utilizables por OS) |
| **Storage** | 512 GB SSD NVMe | ADATA LEGEND 900 |
| **Network (LAN)** | 2x Realtek Gigabit | Interfaces a 1 Gbps |
| **Network (WLAN)** | Intel Wi-Fi 6 AX200 | **Deshabilitada** (Operación estricta por cable) |
| **Bluetooth** | Intel AX200 | Integrado |
| **Boot System** | UEFI sobre ZFS | `rpool/ROOT/pve-1` |

---

## 2. Identity and Access Management (IAM)

El control de acceso está segmentado mediante separación de privilegios, autenticación por llaves y tokens API aislados, preparando el entorno para gestión automatizada y observabilidad externa sin comprometer la seguridad.

### 2.1 Usuarios y Grupos (Roles base)

| Usuario | Realm | Grupo | Estado | Notas de Acceso |
| :--- | :--- | :--- | :--- | :--- |
| `root` | `pam` | `admin` | **Deshabilitado** | Acceso directo bloqueado por seguridad. |
| `erickcastillo` | `pam`, `pve` | `admin` | Activo | Cuenta administrativa principal (Superuser). |
| `homepage_api` | `pam` | `api-ro-users` | Activo | Acceso de solo lectura (`pve-auditor`). |

### 2.2 API Tokens

| Token (Usuario) | Nombre de Token | Separación de Privilegios | Expira | Propósito |
| :--- | :--- | :--- | :--- | :--- |
| `homepage_api@pam` | `homepage` | **Sí** | Nunca | Integración con dashboard (Systems Activity). |
| `root@pam` | `root` | No | Nunca | Acceso API a nivel sistema (Uso restringido). |

*(Nota: Los permisos están propagados de manera global `/` para el rol de `administrator` en el grupo admin y `pve-auditor` para la cuenta de servicio de Homepage).*

---

## 3. Network Architecture

Configuración de red híbrida que combina segmentación física/virtual en Capa 2 y conectividad mallada (Mesh VPN) en Capa 3.

| Interfaz / Bridge | Estado | Dirección IP | Gateway | Propósito |
| :--- | :--- | :--- | :--- | :--- |
| `enp2s0` (Física) | UP | N/A | N/A | Puerto esclavo asignado a `vmbr0`. |
| `eno1` (Física) | UP | N/A | N/A | Puerto esclavo asignado a `vmbr1`. |
| **`vmbr0`** (Bridge) | UP | `192.168.100.21/24` | `192.168.100.1` | **LAN Principal** / Management de Proxmox. |
| **`vmbr1`** (Bridge) | UP | N/A | N/A | Bridge aislado para segmentación (uso por OPNsense). |
| `tailscale0` (Tun) | UP | `100.111.121.78/32` | N/A | Conexión remota administrativa. Ruteo configurado con MASQUERADE en POSTROUTING. |

---

## 4. Storage Subsystem

El hipervisor administra almacenamiento de bloques local mediante ZFS para alto rendimiento y monta volúmenes de red (SMB/CIFS) para datos de aplicaciones pesadas, independizando el cómputo del almacenamiento masivo.

### 4.1 Almacenamiento Local (ZFS)

* **`local` (Directorio):** Montado en `/var/lib/vz`. Uso exclusivo para imágenes ISO, plantillas de contenedores (CT Templates) y respaldos. No compartido.
* **`local-zfs` (Pool ZFS):** Montado en `rpool/data`. Uso para discos de máquinas virtuales (VMs) y rootfs de contenedores. Aprovisionamiento dinámico (*Thin Provisioning / Sparse: 1*).

### 4.2 Almacenamiento de Red (NAS SMB - IP `192.168.100.22`)

* **`/mnt/immich-nas`:** Destino `//192.168.100.22/Media`. Consumido por el LXC de Immich.
* **`/mnt/paperless-nas`:** Destino `//192.168.100.22/Documents`. Consumido por el LXC de Paperless.

---

## 5. Compute Workloads

### 5.1 Máquinas Virtuales (QEMU/KVM)

| VM ID | Hostname | CPU / RAM | Red | Almacenamiento | Estado | Notas |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `100` | `opnsense` | 2 Core / 4 GB | `vmbr0`, `vmbr1` | 32 GB (`local-zfs`) | **Running** | Edge Gateway. *Snapshot "Base" guardado.* |
| `102` | `proxy-server` | 1 Core / 1 GB | `vmbr0` (`.24`) | 32 GB (`local-zfs`) | **Running** | Reverse Proxy. |
| `9000` | `ubuntu-cloud-minimal` | 1 Core / 1 GB | `vmbr0` | 32 GB (`local-zfs`) | **Stopped** | **Template Base** para clonación rápida. |

### 5.2 Contenedores (LXC - Unprivileged)

Todos los contenedores operan en modo **Unprivileged** (`unprivileged: 1`), mapeando al usuario root del contenedor hacia el UID `100000` del host (pve2) aislando los recursos del sistema base. Utilizan `192.168.100.23` (Pi-hole local) como DNS primario.

| CT ID | Hostname | IP Local (`.100.x`) | CPU / RAM | Disco | Notas Adicionales |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `101` | `pihole-dns` | `192.168.100.23` | 1 Core / 512 MB | 10 GB | Servidor DNS e interceptación local. |
| `103` | `vaultwarden` | `192.168.100.25` | 1 Core / 512 MB | 16 GB | Gestor de credenciales. |
| `104` | `homepage` | `192.168.100.30` | 1 Core / 512 MB | 8 GB | Tablero de identidades / Landing. |
| `105` | `monitoring` | `192.168.100.31` | 1 Core / 512 MB | 8 GB | Agente Netdata para observabilidad. |
| `106` | `immich` | `192.168.100.28` | 6 Core / 6 GB | 32 GB | Hardware Passthrough (`/dev/dri/renderD128`) para iGPU transcode. Montaje NAS. |
| `107` | `paperless` | `192.168.100.29` | 4 Core / 3 GB | 20 GB | Gestión documental. Montaje NAS. |

---

## 6. Provisioning & Configuration Management

La infraestructura se diseña bajo un modelo declarativo para facilitar el despliegue automático.

* **Imágenes Base:** Las máquinas virtuales (como la VM `102` y plantilla `9000`) se inicializan vía Cloud-Init utilizando una unidad dedicada en el hardware virtual (`scsi1: local-zfs:vm-X-cloudinit`).
* **Credenciales Inyectadas:** Las contraseñas por defecto (`ciuser: erickcastillo`) se inyectan como hashes criptográficos cerrados.
* **Autenticación Delegada (SSH):** El servidor proxy (`102`) y la plantilla base cuentan con llaves SSH pre-cargadas (`ssh-ed25519` de `windowslaptop` y `desktopc`) garantizando autenticación passwordless, preparando los nodos para despliegues inmutables de configuración.

---

## 7. Security Policies (Proxmox Firewall)

El firewall nativo a nivel de clúster se encuentra en estado **Activado** (`enable: 1`).

1. **Intra-Cluster Comms:** Tráfico total permitido (PASS) entre los nodos hipervisores (`192.168.100.21` y `192.168.100.20`).
2. **Management Access Control:**
   * Regla de permiso estricta a la GUI de Proxmox (Puertos 8006/TCP, 22/TCP) exclusivamente para el Host Bastión / Proxy (`192.168.100.24`) y la red de Tailscale.
   * Regla Catch-All: Todo intento de conexión hacia la interfaz de administración del hipervisor desde el resto de la subred `192.168.100.0/24` es rechazado explícitamente (REJECT).

---

## 8. Package Management & Repositories

La paquetería base de Debian y los módulos de Proxmox están saneados para operar sin suscripción comercial (Evitando errores `401 Unauthorized` en `apt update`).

* **Repositorios Habilitados:**
  * Debian Base (`Bookworm`): Main, Contrib, Updates, Security.
  * Proxmox Community (`pve-no-subscription`).
  * Tailscale Stable (`pkgs.tailscale.com`).
  * Netdata Edge (`repository.netdata.cloud`).
* **Repositorios Deshabilitados (Comentados):**
  * Proxmox Enterprise (`pve-enterprise.list`).
  * Ceph Enterprise (`ceph.list`).

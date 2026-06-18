# As-Built Documentation: Vaultwarden (Credential Management) Node

## Document Control

* **System:** Vaultwarden (Bitwarden compatible server) + Docker Stack
* **OS Version:** Ubuntu 24.04.4 LTS (Noble Numbat) / Kernel: `6.8.12-20-pve`
* **Hostname:** `vaultwarden`
* **Management IP:** `192.168.100.25`
* **Domain:** `infra.sintaq.net`
* **Role:** Password Manager & Secure Credential Vault

## 1. Container Provisioning & Compute (Proxmox LXC)

El nodo opera como un contenedor Linux (LXC) aislado. Se han configurado directivas específicas de seguridad y mapeo de dispositivos para permitir la ejecución de contenedores Docker (Nesting) y túneles VPN (TUN).

### 1.1 Virtual Hardware Allocation

* **LXC ID:** `103` (Node: `pve2`)
* **Privilege Level:** Unprivileged (`unprivileged: 1`)
* **CPU:** 1 vCore (AMD Ryzen 7 6800U architecture)
* **Memory (RAM):** 512 MB
* **Swap:** 512 MB
* **Boot Policy:** Start on boot (`onboot: 1`)

### 1.2 Storage & Filesystem

* **Storage Pool:** `local-zfs`
* **Volume:** `subvol-103-disk-0`
* **Allocated Size:** 16 GB
* **Mount Point:** `/` (Uso base actual: ~7% / 1.2GB)

### 1.3 Advanced Features (LXC Config)

* **Nesting:** Enabled (`nesting=1`). Requerido para el demonio de Docker nativo.
* **Keyctl:** Enabled (`keyctl=1`).
* **Device Passthrough:** `dev0: /dev/net/tun`. Requerido para la creación de interfaces virtuales por parte de Tailscale dentro del contenedor.

---

## 2. Network Interface Configuration

| Interfaz Lógica | Estado | MAC Address / Dirección IP | Gateway IPv4 | Propósito |
| :--- | :--- | :--- | :--- | :--- |
| **`eth0`** | UP | `BC:24:11:87:A0:44` `192.168.100.25/24` | `192.168.100.1` | LAN Primaria (`vmbr0`). |
| **`tailscale0`** | UP | `100.105.134.20/32` | N/A | Conexión Mesh VPN de gestión. |
| **`docker0`** | DOWN | `172.17.0.1/16` | N/A | Bridge default de Docker (inactivo). |
| **`br-0714b8774ac5`** | UP | `172.18.0.1/16` | N/A | Bridge activo para el stack `vaultwarden_default`. |

* **Resolución DNS:** Delegada estáticamente al servidor Pi-hole local (`192.168.100.23`).

---

## 3. Application Workloads (Docker Stack)

Los servicios están orquestados mediante Docker Compose en el directorio del usuario administrativo (`~/homelab/vaultwarden/docker-compose.yml`).

### 3.1 Servicios Activos

| Contenedor | Imagen | Estado | Puertos Expuestos | Propósito |
| :--- | :--- | :--- | :--- | :--- |
| `vaultwarden` | `vaultwarden/server:latest` | Running (Healthy) | `80:80` | Backend principal de gestión de contraseñas. |
| `dozzle_agent_vw` | `amir20/dozzle:latest` | Running | `7007:7007` | Agente remoto para recolección de logs (Grupo: **Seguridad**). |

### 3.2 Configuraciones y Variables de Entorno Clave

**A. Vaultwarden:**

* **Dominio Base:** `https://vaultwarden.infra.sintaq.net` (El backend espera tráfico proveniente de un proxy inverso).
* **Token de Administración:** Protegido mediante archivo de secretos e inyectado vía `.env`.
* **Persistencia:** Directorio local `./vaultwarden_data` montado en `/data`.

---

## 4. Data Persistance & Storage Hierarchy

Los datos sensibles de la aplicación están almacenados localmente utilizando SQLite. No se requiere un contenedor de base de datos externo (ej. PostgreSQL/MariaDB) dado el perfil de rendimiento configurado.

**Ruta de Datos:** `/home/erickcastillo/homelab/vaultwarden/vaultwarden_data/`

* `db.sqlite3`: Base de datos principal cifrada con los vaults de los usuarios.
* `db.sqlite3-wal` / `db.sqlite3-shm`: Archivos temporales de Write-Ahead Logging (rendimiento SQLite).
* `rsa_key.pem`: Llave criptográfica autogenerada por Vaultwarden para tokens JWT y comunicaciones.
* `icon_cache/`: Directorio poblado con los favicons en caché de los sitios web guardados en las bóvedas (ej. `github.com.png`, `accounts.google.com.png`).
* `attachments/` & `sends/`: Directorios reservados para archivos adjuntos y la función *Bitwarden Send* (actualmente vacíos).

---

## 5. Security & Access Control

* **Administración del Host (SSH):** Expuesto en TCP `22` por defecto.
* **Firewall Externo (UFW):** No se detecta firewall local activo en el contenedor; la seguridad de capa de red recae en el Edge Gateway (OPNsense) y la falta de reglas de ruteo directo desde Internet.
* **Tailscale:** Ejecutado nativamente en el host LXC. Escucha en UDP/TCP `41641` para encriptación punto a punto, permitiendo el acceso de gestión incluso si el proxy principal de la red falla.

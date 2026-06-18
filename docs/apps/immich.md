# As-Built Documentation: Immich (Media Management) Node

## Document Control

* **System:** Immich (Self-hosted Photo & Video Backup) + Docker Stack
* **OS Version:** Ubuntu (LXC) / Kernel: `6.8.12-20-pve`
* **Hostname:** `immich`
* **Management IP:** `192.168.100.28`
* **Domain:** `infra.sintaq.net`
* **Role:** Centralized Media Storage, Machine Learning Analysis & Transcoding
* **Timezone:** `America/Hermosillo` *(Heredada de variables de entorno)*

---

## 1. Container Provisioning & Compute (Proxmox LXC)

El nodo opera como un contenedor Linux (LXC) aislado. Se le han asignado recursos sustanciales de CPU y RAM para soportar inferencia de Machine Learning (ML) y compresión de video.

### 1.1 Virtual Hardware Allocation

* **LXC ID:** `106` (Node: `pve2`)
* **Privilege Level:** Unprivileged (`unprivileged: 1`)
* **CPU:** 6 vCores (AMD Ryzen 7 6800U architecture)
* **Memory (RAM):** 6144 MB (6 GB)
* **Swap:** 1024 MB (1 GB)
* **Boot Policy:** Start on boot (`onboot: 1`)

### 1.2 Advanced Features & Device Passthrough (LXC Config)

Para habilitar la aceleración por hardware (Transcoding) y el aislamiento de red, se han mapeado dispositivos físicos directamente al contenedor:

* **Nesting & Keyctl:** Enabled (`nesting=1`, `keyctl=1`) para la ejecución de Docker.
* **Hardware Video Acceleration:** `dev1: /dev/dri/renderD128,mode=0666`. Passthrough directo de la iGPU (AMD Radeon 680M) para codificación/decodificación por hardware nativa.
* **VPN Mesh:** `dev0: /dev/net/tun`. Requerido para la interfaz virtual de Tailscale.

---

## 2. Storage & Filesystem Hierarchy

El sistema de almacenamiento está desacoplado: el sistema operativo y la base de datos residen en almacenamiento ultrarrápido (NVMe/ZFS), mientras que el almacenamiento masivo de medios (imágenes/videos) se delega a un NAS externo.

### 2.1 Almacenamiento Local (OS & Databases)

* **RootFS (`/`):** Pool ZFS `local-zfs:subvol-106-disk-0`.
* **Tamaño Asignado:** 32 GB (Opciones: `discard` habilitado para TRIM).
* **Uso Actual:** ~18% (5.5 GB). Contiene los datos de PostgreSQL y la caché de modelos de Machine Learning.

### 2.2 Almacenamiento Masivo en Red (NAS Mount)

* **Punto de Montaje (LXC):** `mp0: /mnt/immich-nas,mp=/mnt/nas`
* **Destino Real:** Recurso compartido CIFS/SMB desde TrueNAS (`//192.168.100.22/Media`).
* **Propósito:** Persistencia de la librería multimedia (Directorio mapeado a la variable `${UPLOAD_LOCATION}` del stack de Docker).

---

## 3. Network Interface Configuration

| Interfaz Lógica | Estado | MAC Address / Dirección IP | Gateway IPv4 | Propósito |
| :--- | :--- | :--- | :--- | :--- |
| **`eth0`** | UP | `BC:24:11:9F:04:1F` `192.168.100.28/24` | `192.168.100.1` | LAN Primaria (`vmbr0`). |
| **`tailscale0`** | UP | `100.127.227.79/32` | N/A | Red Mesh VPN de gestión. |
| **`br-83fafc70dfdb`** | UP | `172.18.0.1/16` | N/A | Bridge activo para el stack `immich_default`. |

* **Resolución DNS:** Delegada al servidor Pi-hole local (`192.168.100.23`).
* **LXC Firewall:** Activado en la interfaz de red (`firewall=1` en `net0`).

---

## 4. Application Workloads (Docker Stack)

La plataforma Immich está orquestada en `/home/erickcastillo/homelab/immich/` basada en microservicios interconectados.

### 4.1 Microservicios Activos

| Contenedor | Imagen | Estado | Puertos Expuestos | Propósito |
| :--- | :--- | :--- | :--- | :--- |
| `immich_server` | `ghcr.io/immich-app/immich-server:v2` | Running (Healthy) | `2283:2283` | API Principal, Web UI y orquestación. |
| `immich_machine_learning` | `ghcr.io/immich-app/immich-machine-learning:v2` | Running (Healthy) | Interno | Reconocimiento facial, clasificación de objetos (Smart Search). Utiliza volumen `model-cache`. |
| `immich_postgres` | `ghcr.io/immich-app/postgres:14-vectorchord...` | Running (Healthy) | Interno (`5432`) | Base de datos relacional con extensiones `pgvector` para Machine Learning. |
| `immich_redis` | `valkey/valkey:9` | Running (Healthy) | Interno (`6379`) | Caché en memoria y cola de tareas en segundo plano. |
| `dozzle_agent_imm` | `amir20/dozzle:latest` | Running | `7007:7007` | Telemetría remota de logs (Grupo: **Media**). |

### 4.2 Hardware Acceleration Tuning (`hwaccel.transcoding.yml`)

El servicio de servidor (`immich_server`) se extiende para utilizar la API de aceleración de video (VA-API).

* **Mapeo de Dispositivo:** `/dev/dri:/dev/dri` (iGPU de AMD).
* **Controlador (Driver):** `LIBVA_DRIVER_NAME: radeonsi`
* **Beneficio:** Descarga la compresión/transcodificación de videos de la CPU hacia los núcleos gráficos, reduciendo radicalmente el consumo energético y el tiempo de procesamiento en tareas intensivas (ej. generación de thumbnails de video).

---

## 5. Security & Access Control

* **Gestión de Secretos:** Credenciales de bases de datos (`DB_PASSWORD`, `DB_USERNAME`) y claves del sistema residen exclusivamente en el archivo oculto `.env`.
* **Exposición Web:** El panel escucha en TCP `2283`, pero el acceso principal está planificado para ser ruteado de forma segura vía HTTPS a través del Proxy Inverso (Traefik) en `immich.infra.sintaq.net`.
* **Aislamiento Interno:** La base de datos y la caché (Postgres y Valkey) no exponen puertos al host `0.0.0.0`, comunicándose exclusivamente a través de la red aislada de Docker (`immich_default`).

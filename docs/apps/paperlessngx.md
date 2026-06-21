# As-Built Documentation: Paperless-ngx (Document Management) Node

## Document Control

* **System:** Paperless-ngx (Document Management System) + Docker Stack
* **OS Version:** Ubuntu (LXC) / Kernel: `6.8.12-20-pve`
* **Hostname:** `paperless`
* **Management IP:** `192.168.100.29`
* **Domain:** `infra.sintaq.net`
* **Role:** Centralized OCR, Archiving, and Document Management
* **Timezone:** `America/Hermosillo` *(Heredada de variables de entorno globales)*

---

## 1. Container Provisioning & Compute (Proxmox LXC)

El nodo opera como un contenedor Linux (LXC) sin privilegios. Se han asignado recursos moderados-altos de CPU y RAM debido a la carga de trabajo intensiva del procesamiento OCR (Tika/Gotenberg) y la base de datos relacional.

### 1.1 Virtual Hardware Allocation

* **LXC ID:** `107` (Node: `pve2`)
* **Privilege Level:** Unprivileged (`unprivileged: 1`)
* **CPU:** 4 vCores (AMD Ryzen 7 6800U architecture)
* **Memory (RAM):** 3072 MB (3 GB)
* **Swap:** 1024 MB (1 GB)
* **Boot Policy:** Start on boot (`onboot: 1`)

### 1.2 Advanced Features (LXC Config)

* **Nesting:** Enabled (`nesting=1`). Habilita la ejecución nativa de Docker.
* **Keyctl:** Enabled (`keyctl=1`).
* **Device Passthrough:** `dev0: /dev/net/tun`. Requerido para el enrutamiento de la red Mesh (Tailscale).

---

## 2. Storage & Filesystem Hierarchy

La arquitectura de almacenamiento está dividida para maximizar el rendimiento de las bases de datos locales y garantizar la persistencia externa y redundancia de los documentos digitalizados.

### 2.1 Almacenamiento Local (Bases de Datos y Caché)

* **RootFS (`/`):** Pool ZFS `local-zfs:subvol-107-disk-0`.
* **Tamaño Asignado:** 20 GB (Opciones: `discard` habilitado para soporte TRIM).
* **Uso Actual:** ~26% (5.1 GB).

### 2.2 Almacenamiento Masivo en Red (NAS Mount)

* **Punto de Montaje (LXC):** `mp0: /mnt/paperless-nas,mp=/mnt/nas`
* **Destino Real:** Recurso compartido CIFS/SMB desde el nodo TrueNAS (`//192.168.100.22/Documents`).
* **Propósito:** Almacenamiento maestro de los archivos PDF, medios originales, carpetas de exportación y la bandeja de entrada (*consume*).

---

## 3. Network Interface Configuration

| Interfaz Lógica | Estado | MAC Address / Dirección IP | Gateway IPv4 | Propósito |
| :--- | :--- | :--- | :--- | :--- |
| **`eth0`** | UP | `BC:24:11:69:61:76` `192.168.100.29/24` | `192.168.100.1` | LAN Primaria (`vmbr0`). |
| **`tailscale0`** | UP | `100.75.207.75/32` | N/A | Red Mesh VPN administrativa. |
| **`br-bfe4e410116a`** | UP | `172.18.0.1/16` | N/A | Bridge activo para la red `paperless_default` (Docker). |

* **Resolución DNS:** Delegada estáticamente al servidor Pi-hole local (`192.168.100.23`).

---

## 4. Application Workloads (Docker Stack)

El ecosistema de Paperless-ngx consta de múltiples microservicios interdependientes, orquestados en `/home/erickcastillo/homelab/paperlessngx/`.

### 4.1 Microservicios Activos

| Contenedor | Imagen | Estado | Puertos Expuestos | Función |
| :--- | :--- | :--- | :--- | :--- |
| `paperless-webserver-1` | `ghcr.io/paperless-ngx/paperless-ngx:latest` | Running (Healthy) | `8000:8000` | Backend/Frontend de la aplicación. |
| `paperless-db-1` | `postgres:18` | Running | Interno (`5432`) | Base de datos relacional transaccional. |
| `paperless-broker-1` | `redis:8` | Running | Interno (`6379`) | Message broker y caché de tareas en segundo plano (Celery). |
| `paperless-gotenberg-1` | `gotenberg/gotenberg:latest` | Running | Interno (`3000`) | Motor de conversión de documentos (ej. Office/Email a PDF). |
| `paperless-tika-1` | `apache/tika:latest` | Running | Interno (`9998`) | Motor de extracción de texto y metadatos (OCR). |
| `dozzle_agent_pp` | `amir20/dozzle:latest` | Running | `7007:7007` | Agente de telemetría de logs centralizados (Grupo: **Documentos**). |

### 4.2 Mapeo de Volúmenes (Persistencia de Datos)

El diseño de directorios asegura que los datos críticos de Docker sobrevivan a reinicios y actualizaciones:

* **Base de Datos (`pgdata/`):** Mapeado a `/var/lib/postgresql`.
* **Redis (`redisdata/`):** Mapeado a `/data` (contiene `dump.rdb`).
* **Datos Internos Paperless (`data/`):** Contiene índices de búsqueda, lock files de migraciones y bitácoras de tareas (`celerybeat-schedule.db`, `index/`, `log/`).
* **NAS Integration:** Los directorios críticos de usuario apuntan directamente al montaje de red:
  * `media/` -> `/mnt/nas/paperless/media`
  * `export/` -> `/mnt/nas/paperless/export`
  * `consume/` -> `/mnt/nas/paperless/consume`

### 4.3 Políticas de Seguridad L7 y Hardening

**A. Hardening de Gotenberg:** El contenedor de Gotenberg opera con directivas de seguridad estrictas para evitar ejecución de código malicioso al renderizar archivos (ej. `.eml`):

* `--chromium-disable-javascript=true`
* `--chromium-allow-list=file:///tmp/.*`

**B. Proxies de Confianza y CSRF:** El contenedor web está protegido para interactuar exclusivamente detrás de la infraestructura Traefik.

* `PAPERLESS_TRUSTED_PROXIES: 192.168.100.24` (IP del nodo proxy).
* `PAPERLESS_CSRF_TRUSTED_ORIGINS: https://paperless.infra.sintaq.net`
* `PAPERLESS_ALLOWED_HOSTS: paperless.infra.sintaq.net,192.168.100.29`

---

## 5. Security & Access Control

* **Administración del Host (SSH):** TCP `22` por defecto.
* **Exposición Web:** Expuesto en TCP `8000`. Diseñado para ser alcanzado únicamente vía Traefik mediante TLS.
* **Integración Tailscale:** Permite el acceso directo a los servicios locales (`TCP 8000`, `TCP 22`, `TCP 7007`) de manera segura y encriptada (escucha en `UDP 41641`) independientemente del estado del gateway principal.

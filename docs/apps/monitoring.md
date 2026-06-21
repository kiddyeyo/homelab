# As-Built Documentation: Monitoring & Observability Node

## Document Control

* **System:** Dozzle (Log Aggregation & Monitoring) + Docker Stack
* **OS Version:** Ubuntu 24.04 LTS / Kernel: `6.8.12-20-pve`
* **Hostname:** `monitoring`
* **Management IP:** `192.168.100.31`
* **Domain:** `infra.sintaq.net`
* **Role:** Centralized Container Log Aggregation Server
* **Timezone:** `America/Hermosillo` *(Heredada)*

## 1. Container Provisioning & Compute (Proxmox LXC)

El nodo opera como un contenedor Linux (LXC) aislado. Está configurado para ejecutar el motor de Docker nativamente y operar servicios de red mallada (VPN).

### 1.1 Virtual Hardware Allocation

* **LXC ID:** `105` (Node: `pve2`)
* **Privilege Level:** Unprivileged (`unprivileged: 1`)
* **CPU:** 1 vCore (AMD Ryzen 7 6800U architecture)
* **Memory (RAM):** 512 MB
* **Swap:** 512 MB
* **Boot Policy:** Start on boot (`onboot: 1`)

### 1.2 Storage & Filesystem

* **Storage Pool:** `local-zfs`
* **Volume:** `subvol-105-disk-0`
* **Allocated Size:** 8 GB
* **Mount Point:** `/` (Uso base: ~10% / 815MB)

### 1.3 Advanced Features (LXC Config)

* **Nesting:** Enabled (`nesting=1`). Permite el aislamiento de namespaces para el demonio de Docker.
* **Keyctl:** Enabled (`keyctl=1`).
* **Device Passthrough:** `dev0: /dev/net/tun`. Requerido para la interfaz virtual de Tailscale.

---

## 2. Network Interface Configuration

| Interfaz Lógica | Estado | MAC Address / Dirección IP | Gateway IPv4 | Propósito |
| :--- | :--- | :--- | :--- | :--- |
| **`eth0`** | UP | `BC:24:11:BF:1D:AC` `192.168.100.31/24` | `192.168.100.1` | LAN Primaria (`vmbr0`). |
| **`tailscale0`** | UP | `100.102.91.75/32` | N/A | Red Mesh VPN de gestión directa. |
| **`br-5e3048ce9dd5`** | UP | `172.18.0.1/16` | N/A | Bridge activo para el stack `monitoring_default`. |

* **Resolución DNS:** Delegada estáticamente al servidor Pi-hole local (`192.168.100.23`).

---

## 3. Application Workloads (Docker Stack)

El servidor central de recolección de logs (Dozzle Webserver) se despliega de forma declarativa vía Docker Compose en `/home/erickcastillo/homelab/monitoring/`.

### 3.1 Servicios Activos

| Contenedor | Imagen | Estado | Puertos Expuestos | Propósito |
| :--- | :--- | :--- | :--- | :--- |
| `dozzle_webserver` | `amir20/dozzle:latest` | Running | `8080:8080` | Interfaz web unificada para visualización de logs de contenedores. |

### 3.2 Parámetros de Entorno y Configuración Distribuida

Dozzle está configurado en una arquitectura **Agente/Maestro**. Este nodo actúa como el maestro (Webserver) que agrega los flujos de logs de los agentes distribuidos en los demás hosts de la infraestructura.

* **Configuración del Webserver (Master):**
  * `DOZZLE_HOSTNAME: monitoring`
  * `DOZZLE_AUTH_PROVIDER: simple` (Autenticación requerida basada en el archivo `users.yml`).
  * `DOZZLE_FILTER: "name!=dozzle_agent_.*"`: Filtro global aplicado para ocultar los logs de los propios agentes de Dozzle en la interfaz, manteniendo la vista limpia.
  * Montaje de Seguridad: El socket local (`/var/run/docker.sock`) se monta en modo estricto de **Solo Lectura (`ro`)**.
* **Agrupación de Servicios (Labels):** Se utiliza el label `dev.dozzle.group` en los composes de toda la infraestructura para organizar los logs visualmente:
  * **Infraestructura**: Traefik, Homepage.
  * **Media**: Immich Stack (Server, ML, Redis, DB).
  * **Documentos**: Paperless-ngx Stack (Webserver, Broker, DB, etc.).
  * **Seguridad**: Vaultwarden.
  * **Observabilidad**: Dozzle Webserver.
* **Agentes Remotos Configurados (`DOZZLE_REMOTE_AGENT`):** El sistema se conecta a los agentes de infraestructura mediante resolución de DNS interna (Pi-hole) en el puerto `7007`:
  * `traefik:7007`
  * `vaultwarden:7007`
  * `immich:7007`
  * `paperlessngx:7007`
  * `homepage:7007`

---

## 4. Persistencia de Datos

Dozzle no requiere una base de datos pesada ya que los logs se leen en tiempo real de la API de Docker. La persistencia se limita estrictamente a la base de usuarios para el control de acceso de la interfaz web.

**Ruta de Datos:** `/home/erickcastillo/homelab/monitoring/dozzle_data/`

* `users.yml`: Archivo de configuración que contiene las credenciales (`DOZZLE_AUTH_PROVIDER: simple`) para acceder al visualizador.

---

## 5. Security & Access Control

* **Administración del Host (SSH):** Expuesto en TCP `22` por defecto.
* **Acceso Web:** Expuesto internamente en TCP `8080`, diseñado para ser ruteado vía el Edge Gateway/Proxy Inverso (`traefik`).
* **Tailscale:** Ejecutado nativamente en el host LXC. Escucha en UDP/TCP `41641` para encriptación punto a punto, permitiendo el acceso administrativo directo a los logs incluso si el ruteo interno o el proxy fallan.

# As-Built Documentation: Homepage (Infrastructure Dashboard) Node

## Document Control

* **System:** Homepage (Dashboard) + Docker Stack
* **OS Version:** Ubuntu 24.04 LTS / Kernel: `6.8.12-20-pve`
* **Hostname:** `homepage`
* **Management IP:** `192.168.100.30`
* **Domain:** `infra.sintaq.net`
* **Role:** Centralized Infrastructure Dashboard & Landing Page
* **Timezone:** `America/Hermosillo`

---

## 1. Container Provisioning & Compute (Proxmox LXC)

El nodo opera como un contenedor Linux (LXC) aislado. Está configurado para ejecutar Docker nativamente y operar servicios de red mallada (VPN).

### 1.1 Virtual Hardware Allocation

* **LXC ID:** `104` (Node: `pve2`)
* **Privilege Level:** Unprivileged (`unprivileged: 1`)
* **CPU:** 1 vCore (AMD Ryzen 7 6800U architecture)
* **Memory (RAM):** 512 MB
* **Swap:** 512 MB
* **Boot Policy:** Start on boot (`onboot: 1`)

### 1.2 Storage & Filesystem

* **Storage Pool:** `local-zfs`
* **Volume:** `subvol-104-disk-0`
* **Allocated Size:** 8 GB
* **Mount Options:** `discard` (TRIM habilitado para optimización de ZFS).
* **Mount Point:** `/` (Uso base: ~14% / 1.1GB)

### 1.3 Advanced Features (LXC Config)

* **Nesting:** Enabled (`nesting=1`). Permite el aislamiento de namespaces para el demonio de Docker.
* **Keyctl:** Enabled (`keyctl=1`).
* **Device Passthrough:** `dev0: /dev/net/tun`. Requerido para la interfaz virtual de Tailscale.

---

## 2. Network Interface Configuration

| Interfaz Lógica | Estado | MAC Address / Dirección IP | Gateway IPv4 | Propósito |
| :--- | :--- | :--- | :--- | :--- |
| **`eth0`** | UP | `BC:24:11:D3:8E:BB` `192.168.100.30/24` | `192.168.100.1` | LAN Primaria (`vmbr0`). |
| **`tailscale0`** | UP | `100.79.55.121/32` | N/A | Red Mesh VPN de gestión directa. |
| **`br-ce7b9e8163ce`** | UP | `172.18.0.1/16` | N/A | Bridge activo para el stack `homepage_default`. |

* **Resolución DNS:** Delegada estáticamente al servidor Pi-hole local (`192.168.100.23`).

---

## 3. Application Workloads (Docker Stack)

La plataforma se despliega de forma declarativa vía Docker Compose en `/home/erickcastillo/homelab/homepage/`.

### 3.1 Servicios Activos

| Contenedor | Imagen | Estado | Puertos Expuestos | Propósito |
| :--- | :--- | :--- | :--- | :--- |
| `homepage` | `ghcr.io/gethomepage/homepage:latest` | Running (Healthy) | `3000:3000` | Frontend/Backend del tablero principal. |
| `dozzle_agent_hp` | `amir20/dozzle:latest` | Running | `7007:7007` | Agente remoto para telemetría de logs. |

### 3.2 Parámetros de Entorno (Environment)

* **URL Pública:** `https://homepage.infra.sintaq.net`
* **Proxy de Confianza:** `HOMEPAGE_TRUSTED_PROXIES: traefik` (Asegura la correcta lectura de IPs origen y mitigación CORS/CSRF).
* **Control de Identidad:** `PUID` y `PGID` mapeados vía archivo `.env` para control estricto de permisos sobre los archivos de configuración.
* **Simplificación de Rutas:** Se ha eliminado la subcarpeta `config/`. El contenedor monta la raíz del servicio (`./`) directamente en `/app/config`, permitiendo una gestión más directa de los archivos YAML.
* **Seguridad Dozzle:** Montaje de `/var/run/docker.sock` en modo **Solo Lectura (`ro`)**.

---

## 4. Dashboard Configuration (Homepage)

El sistema de Homepage funciona con archivos YAML estáticos ubicados en la raíz del directorio del servicio. Está diseñado bajo un enfoque minimalista e integración de APIs (Widgets) con la infraestructura existente.

### 4.1 UI & Layout (`settings.yaml`)

* **Theme:** Dark (Color: `slate`, Brightness: 50%).
* **Style:** `clean` (Header), `fullWidth: true`.
* **Organización de Columnas:**
  1. `Infrastructure` (2 Columnas)
  2. `Network Services` (3 Columnas)
  3. `App Services` (3 Columnas)

### 4.2 Widgets Globales (`widgets.yaml` & `bookmarks.yaml`)

* **Búsqueda:** DuckDuckGo (Target `_blank`, Focus: true).
* **Clima (Open-Meteo API):** * Hermosillo (`29.07297`, `-110.95592`)
  * Monterrey (`25.6866`, `-100.3161`)
* **Enlaces Rápidos (Bookmarks):** Accesos directos a la consola de Tailscale, GitHub y Cloudflare.

### 4.3 Service API Integrations (`services.yaml`)

El dashboard interroga el estado y métricas de los servicios mediante sus APIs. Los secretos **no están en texto plano**, sino que se inyectan a través del motor de variables de entorno de Homepage (`{{HOMEPAGE_VAR_*}}`).

| Categoría | Servicio | Endpoint de Integración API | Autenticación / API Key |
| :--- | :--- | :--- | :--- |
| **Infrastructure** | Proxmox | `https://proxmox.infra.sintaq.net` (Node: `pve2`) | User/Password (`_PROXMOX_USERNAME`) |
| **Infrastructure** | TrueNAS | `https://truenas.infra.sintaq.net` (v2 Scale) | API Key (`_TRUENAS_KEY`) |
| **Network** | OPNsense | `https://opnsense.infra.sintaq.net` | User/Password (`_OPNSENSE_USERNAME`) |
| **Network** | Pi-hole | `https://pihole.infra.sintaq.net` (v6) | App Password (`_PIHOLE_KEY`) |
| **Network** | Traefik | `https://proxy.infra.sintaq.net` | Basic Auth |
| **App Services** | Paperless-ngx | `https://paperless.infra.sintaq.net` | API Key (`_PAPERLESS_KEY`) |
| **App Services** | Immich | `https://immich.infra.sintaq.net` (v2) | API Key (`_IMMICH_KEY`) |
| **App Services** | Vaultwarden | Integración vía socket/contenedor local | N/A (Docker Socket) |

---

## 5. Security & Access Control

* **Gestión de Secretos:** Todos los tokens de API están resguardados en el archivo oculto `.env` a nivel host.
* **Aislamiento de Permisos:** El usuario de ejecución del servicio Homepage no es root, se define paramétricamente para empatar con los permisos locales de `/home/erickcastillo/homelab/homepage/config`.
* **Firewall Externo:** La seguridad de borde recae en Traefik (Proxy) y OPNsense, el servicio escucha nativamente en `http://192.168.100.30:3000` pero está pensado para servirse a través del proxy inverso TLS.

# As-Built Documentation: LiteLLM (AI Proxy) Node

## Document Control

* **System:** LiteLLM (LLM Proxy) + Docker Stack
* **OS Version:** Ubuntu (LXC) / Kernel: `6.8.12-20-pve`
* **Hostname:** `litellm`
* **Management IP:** `192.168.100.33`
* **Domain:** `infra.sintaq.net`
* **Role:** Proxy para modelos de lenguaje (LLMs) con soporte para múltiples proveedores.
* **Timezone:** `America/Hermosillo`

---

## 1. Container Provisioning & Compute (Proxmox LXC)

El nodo opera como un contenedor Linux (LXC) sin privilegios.

### 1.1 Virtual Hardware Allocation

* **LXC ID:** `109` (Estimado)
* **Privilege Level:** Unprivileged (`unprivileged: 1`)
* **CPU:** 1 vCore
* **Memory (RAM):** 512 MB
* **Swap:** 512 MB
* **Boot Policy:** Start on boot (`onboot: 1`)

---

## 2. Network Interface Configuration

| Interfaz Lógica | Estado | Dirección IP | Gateway IPv4 | Propósito |
| :--- | :--- | :--- | :--- | :--- |
| **`eth0`** | UP | `192.168.100.33/24` | `192.168.100.1` | LAN Primaria (`vmbr0`). |

---

## 3. Application Workloads (Docker Stack)

El stack se despliega vía Docker Compose en `/home/erickcastillo/homelab/litellm/`.

### 3.1 Servicios Activos

| Contenedor | Imagen | Estado | Puertos Expuestos | Función |
| :--- | :--- | :--- | :--- | :--- |
| `litellm` | `ghcr.io/berriai/litellm:main-latest` | Running | `4000:4000` | Proxy de LLMs. |
| `litellm-db` | `postgres:16` | Running | Interno | Base de datos de configuración y logs. |
| `litellm-redis` | `redis:7-alpine` | Running | Interno | Caché y gestión de límites. |
| `dozzle-agent` | `amir20/dozzle:latest` | Running | `7007:7007` | Agente de logs (Grupo: **AI**). |

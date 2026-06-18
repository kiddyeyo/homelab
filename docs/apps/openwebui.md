# As-Built Documentation: Open WebUI (AI Interface) Node

## Document Control

* **System:** Open WebUI (AI Frontend) + Docker Stack
* **OS Version:** Ubuntu (LXC) / Kernel: `6.8.12-20-pve`
* **Hostname:** `openwebui`
* **Management IP:** `192.168.100.32`
* **Domain:** `infra.sintaq.net`
* **Role:** Interfaz de usuario para interactuar con LLMs.
* **Timezone:** `America/Hermosillo`

---

## 1. Container Provisioning & Compute (Proxmox LXC)

El nodo opera como un contenedor Linux (LXC) sin privilegios.

### 1.1 Virtual Hardware Allocation

* **LXC ID:** `108` (Estimado)
* **Privilege Level:** Unprivileged (`unprivileged: 1`)
* **CPU:** 2 vCores
* **Memory (RAM):** 2048 MB (2 GB)
* **Swap:** 1024 MB (1 GB)
* **Boot Policy:** Start on boot (`onboot: 1`)

---

## 2. Network Interface Configuration

| Interfaz Lógica | Estado | Dirección IP | Gateway IPv4 | Propósito |
| :--- | :--- | :--- | :--- | :--- |
| **`eth0`** | UP | `192.168.100.32/24` | `192.168.100.1` | LAN Primaria (`vmbr0`). |

---

## 3. Application Workloads (Docker Stack)

El stack se despliega vía Docker Compose en `/home/erickcastillo/homelab/openwebui/`.

### 3.1 Servicios Activos

| Contenedor | Imagen | Estado | Puertos Expuestos | Función |
| :--- | :--- | :--- | :--- | :--- |
| `open-webui` | `ghcr.io/open-webui/open-webui:main` | Running | `3005:8080` | Interfaz web de chat. |
| `dozzle-agent` | `amir20/dozzle:latest` | Running | `7007:7007` | Agente de logs (Grupo: **AI**). |

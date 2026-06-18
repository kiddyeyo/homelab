# As-Built Documentation: Reverse Proxy & Edge Gateway Node

## Document Control

* **System:** Reverse Proxy Server (Docker + Traefik v3)
* **OS Version:** Ubuntu 24.04.4 LTS (Noble Numbat)
* **Kernel:** `6.8.0-110-generic`
* **Hostname:** `proxy-server`
* **Management IP:** `192.168.100.24`
* **Domain:** `infra.sintaq.net`
* **Role:** Edge Gateway, TLS Termination, Reverse Proxy

---

## 1. Virtual Machine Provisioning (Proxmox KVM)

El servidor proxy se ejecuta como una máquina virtual (VM) ligera, provisionada de forma declarativa mediante Cloud-Init para garantizar la inmutabilidad de la configuración base.

### 1.1 Compute & Architecture

* **VM ID:** `102` (Node: `pve2`)
* **Machine Type:** `q35` (Modern PCIe architecture)
* **BIOS:** OVMF (UEFI) con Secure Boot capabilities (`efitype=4m,pre-enrolled-keys=1`).
* **CPU:** 1 vCore (`cpu: host` para passthrough de instrucciones AMD-V y aceleración criptográfica AES).
* **Memory:** 1024 MB (Ballooning habilitado).
* **Boot Order:** `scsi0`
* **QEMU Agent:** Enabled (`agent: 1`).

### 1.2 Storage

* **OS Disk:** `scsi0` (`local-zfs:base-9000-disk-1/vm-102-disk-1`).
  * **Size:** 32 GB
  * **Features:** `discard=on` (TRIM), `iothread=1` (Asynchronous I/O), `ssd=1`.
* **Cloud-Init Disk:** `scsi1` (`local-zfs:vm-102-cloudinit`).

### 1.3 Identity, Provisioning & SSH (Cloud-Init)

El acceso administrativo está automatizado; la autenticación por contraseña está abstraída en favor de llaves criptográficas.

* **Default User:** `erickcastillo`
* **Password:** Inyectada como hash (`cipassword: **********`).
* **Authorized SSH Keys:**
  * `ssh-ed25519 [...] windowslaptop`
  * `ssh-ed25519 [...] desktopc`

---

## 2. Network Interface Configuration

| Interfaz Lógica | Hardware / Tipo | MAC Address / Dirección IP | Propósito |
| :--- | :--- | :--- | :--- |
| **`eth0`** | `virtio` (Bridge: `vmbr0`) | `BC:24:11:6D:E4:B6` `192.168.100.24/24` | Interfaz LAN Primaria. Gateway: `192.168.100.1`. DNS: `192.168.100.23`. |
| **`tailscale0`** | `fq_codel` (VPN Tun) | `100.92.217.120/32` | Conexión Mesh (Tailscale) directa al servidor. |
| **`br-fc988ca31a18`** | Virtual Bridge | `172.18.0.1/16` | Red local de Docker (`proxy`). |
| **`docker0`** | Virtual Bridge | `172.17.0.1/16` | Red default de Docker (inactiva). |

---

## 3. Security & Firewall (UFW)

El host expone y escucha explícitamente en puertos requeridos para servicios web y de gestión de contenedores, según el mapeo de sockets de Docker.

**Puertos a la escucha (Listening Ports):**

* `TCP 22` (SSH)
* `TCP 80` (HTTP - Redirección Traefik)
* `TCP 443` (HTTPS - Traefik TLS Termination)
* `TCP 7007` (Dozzle Agent)
* `UDP 41641` (Tailscale)

*(Nota Operativa de Firewall: Los logs de UFW muestran bloqueos activos (UFW BLOCK) descartando tráfico UDP de descubrimiento [puertos efímeros y NetBIOS] proveniente de las IPs .219, .122, y .157 de la LAN hacia el proxy).*

---

## 4. Container Workloads (Docker Stack)

El orquestador local de servicios web. Reside en `/home/erickcastillo/homelab/traefik/`.

### 4.1 Docker Networks

* **`proxy`** (`fc988ca31a18`): Red de tipo bridge, declarada como externa en los composes, utilizada para interconectar Traefik con otros contenedores futuros si se despliegan en el mismo host.

### 4.2 Stack de Traefik (docker-compose.yml)

El proxy gestiona la entrada unificada, terminación TLS (Let's Encrypt + Cloudflare DNS-01) y enrutamiento hacia la infraestructura interna.

| Contenedor | Imagen | Estado | Puertos Expuestos | Propósito |
| :--- | :--- | :--- | :--- | :--- |
| `traefik` | `traefik:v3` | Running | `80:80`, `443:443` | Proxy Inverso principal. Monta `docker.sock` en Read-Only. |
| `dozzle_agent_tfk` | `amir20/dozzle:latest` | Running | `7007:7007` | Agente remoto de visualización de logs para integrarse a una UI centralizada. |

---

## 5. Traefik Reverse Proxy Configuration

Traefik actúa como el único punto de entrada HTTP/HTTPS para la red interna. La configuración se ha simplificado eliminando subcarpetas `config/` innecesarias.

### 5.1 Static Configuration (`traefik.yml`)

* **Log Level:** `DEBUG`
* **API Dashboard:** Habilitado (Ruteado de forma segura vía reglas dinámicas).
* **Entrypoints:**
  * `web` (Puerto `80`): Aplica redirección HTTP a HTTPS (`websecure`) global y permanente.
  * `websecure` (Puerto `443`): Terminación TLS.
* **Certificate Generation (ACME):**
  * **Provider:** Cloudflare DNS-01 Challenge.
  * **Resolvers:** `1.1.1.1:53`, `1.0.0.1:53` (Delay de 10s para propagación).
  * **Target Domains:** Genera un certificado wildcard automático para `infra.sintaq.net` y `*.infra.sintaq.net`.
* **Providers:** Docker (Network `proxy`) y **Directorio Dinámico** (`/etc/traefik/dynamic`).

### 5.2 Dynamic Routing & Security Policies (`dynamic/`)

La configuración dinámica se encuentra segmentada en el directorio `dynamic/` para facilitar la gestión individual de cada servicio.

#### A. Middlewares & Transport (`middlewares.yml`, `tls.yml`)

* **`middlewares.yml`**: Define la política `secure-headers` (HSTS, CSP, CORS, etc.).
* **`tls.yml`**: Configura `insecureTransport` para permitir conexiones a backends con certificados autofirmados (Proxmox, OPNsense, TrueNAS).

#### B. Servicios de Destino (Archivos individuales .yml)

Cada servicio cuenta con su propio archivo de configuración (ej. `opnsense.yml`, `proxmox.yml`) que define su Router y Service.

| Archivo de Configuración | Host / Regla | Endpoint del Servicio Local (Backend) | Tipo de Transporte |
| :--- | :--- | :--- | :--- |
| `opnsense.yml` | `opnsense.infra.sintaq.net` | `https://192.168.100.1` | **Insecure HTTPS** |
| `truenas.yml` | `truenas.infra.sintaq.net` | `https://192.168.100.22` | **Insecure HTTPS** |
| `proxmox.yml` | `proxmox.infra.sintaq.net` | `https://192.168.100.21:8006` | **Insecure HTTPS** |
| `pihole.yml` | `pihole.infra.sintaq.net` | `http://192.168.100.23:80` | Plain HTTP |
| `vaultwarden.yml` | `vaultwarden.infra.sintaq.net` | `http://192.168.100.25:80` | Plain HTTP |
| `immich.yml` | `immich.infra.sintaq.net` | `http://192.168.100.28:2283` | Plain HTTP |
| `paperless.yml` | `paperless.infra.sintaq.net` | `http://192.168.100.29:8000` | Plain HTTP |
| `homepage.yml` | `homepage.infra.sintaq.net` | `http://192.168.100.30:3000` | Plain HTTP |
| `dozzle.yml` | `dozzle.infra.sintaq.net` | `http://192.168.100.31:8080` | Plain HTTP |

*(Nota: "Insecure HTTPS" indica el uso de la directiva `insecureSkipVerify: true` en Traefik para evitar errores de validación con los certificados autofirmados que las plataformas OPNsense, TrueNAS y Proxmox generan por defecto de manera interna).*

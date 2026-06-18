# As-Built Documentation: OPNsense Edge Gateway

## Document Control

* **System:** OPNsense
* **Role:** Edge Firewall & Infrastructure Gateway
* **Hostname:** `opnsense.infra.sintaq.net`
* **Domain:** `infra.sintaq.net`
* **Timezone:** `America/Hermosillo`
* **Environment:** Proxmox VE (Virtual Machine)

## 1. Virtual Machine Provisioning (Proxmox VE)

El firewall opera como una máquina virtual (VM) en Proxmox.

### 1.1 Compute & Architecture

* **VM ID:** `100`
* **Memory:** `4 GiB` (Ballooning desactivado: `balloon=0`).
* **Processors:** `2 vCPU` (CPU Flag: `+aes`).
* **BIOS:** Default (`SeaBIOS`)
* **Machine Type:** Default (`i440fx`)
* **Display:** Default

### 1.2 Storage

* **SCSI Controller:** VirtIO SCSI Single
* **Hard Disk (OS):** `scsi0`
  * **Storage Pool:** `local-zfs` (Volume: `vm-100-disk0`)
  * **Size:** `32 GB`
  * **Features:** `discard=on` (TRIM), `iothread=1` (I/O asíncrono), `ssd=1`
* **CD/DVD Drive:** `ide2` (Mounted ISO: `OPNsense-25.1-dvd-amd64.iso`, media=cdrom)

### 1.3 Virtual Networking

| V-Device | Bridge | MAC Address | VirtIO Queues | OPNsense Assignment |
| :--- | :--- | :--- | :--- | :--- |
| `net0` | `vmbr1` | `bc:24:11:1e:8d:8a` | `2` | WAN (`vtnet0`) |
| `net1` | `vmbr0` | `bc:24:11:57:15:ec` | `2` | LAN (`vtnet1`) |

---

## 2. System Administration & Access Control

El acceso administrativo está segmentado bajo el principio de mínimo privilegio y restringido a las interfaces de gestión internas.

### 2.1 Web GUI Configuration

* **Protocol:** HTTPS Only
* **Certificate:** Automatic TLS Certificate (Frontend proxy vía Traefik con certificado de Cloudflare).
* **Listen Interfaces:** LAN, Tailscale

### 2.2 SSH Services

* **Service Status:** Enabled
* **Port:** TCP `22`
* **Listen Interfaces:** LAN, Tailscale

### 2.3 User Accounts & Roles

| Username | Role/Groups | Web GUI Access | SSH Access | Notes & Privileges |
| :--- | :--- | :--- | :--- | :--- |
| `root` | `admin` | Disabled | Disabled | Default administrator account. Disabled for security. |
| `erickcastillo` | `admin` | Enabled | Enabled | Passwordless SSH (Pubkey). Passwordless `sudo` enabled. |
| `homepage` | Custom | Limited | Disabled | Privileges restricted to: *Systems activity*, *Reporting traffic*. |

---

## 3. Network Interface Configuration (L2/L3)

| Logical Name | Hardware Device | Type | IPv4 Configuration | IPv4 Gateway |
| :--- | :--- | :--- | :--- | :--- |
| **WAN** | `vtnet0` | Physical / Static | `192.168.1.253/24` | `wan-gw` (`192.168.1.254`) |
| **LAN** | `vtnet1` | Physical / Static | `192.168.100.1/24` | None |
| **Tailscale** | `tailscale0` | Virtual / VPN | `100.113.219.118/32` | None (Identifier: `opt1`) |

---

## 4. Routing & DNS (Global Services)

### 4.1 DNS Servers

1. `1.1.1.1` (Cloudflare)
2. `1.0.0.1` (Cloudflare)
3. `192.168.100.254` (Internal Gateway / WAN GW)

### 4.2 Routing Table Base

* **Default Route (`0.0.0.0/0`):** Vía WAN Gateway (`192.168.1.254`) para alcanzar `1.1.1.1`, `1.0.0.1` y la red `192.168.1.0/24`.
* **LAN Route:** Enrutamiento directo a `192.168.100.0/24` a través de la interfaz `vtnet1`.

---

## 5. NAT configuration (Outbound)

Políticas de traducción de direcciones para la salida de tráfico. Se aplican reglas manuales para mantener puertos estáticos (`Static Port: Yes`) en protocolos que requieren mapeo directo (ej. STUN, VPNs).

| Interface | Source Network | Source Port | Destination | Dest. Port | NAT Address | NAT Port | Static Port |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| WAN | `192.168.100.0/24` | `UDP / 41641` | `*` | `UDP / *` | Interface | `*` | **Yes** |
| WAN | `192.168.100.0/24` | `UDP / *` | `*` | `UDP / 3478` | Interface | `*` | **Yes** |
| WAN | `192.168.100.0/24` | `UDP / *` | `*` | `UDP / 443` | Interface | `*` | **Yes** |
| WAN | `192.168.100.0/24` | `UDP / *` | `*` | `UDP / 80` | Interface | `*` | **Yes** |

---

## 6. Firewall Rules (Inbound Access Control)

Reglas de control de acceso aplicadas a la interfaz local (LAN) evaluadas mediante política de *First Match*.

| Action | Protocol | Source Address | Src Port | Destination Address | Dst Port | Log | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Pass** | IPv4 TCP | `192.168.100.24/32` | `*` | `192.168.100.1/32` | `443` (HTTPS) | Disabled | Allow Bastion/Admin Host |
| **Block** | IPv4 TCP | `*` (Any) | `*` | `192.168.100.1/32` | `443` (HTTPS) | Disabled | Block all other LAN nodes |

> **Nota de Seguridad:** La Web GUI de OPNsense está aislada lógicamente dentro de la misma LAN. Solo el nodo administrativo `192.168.100.24` (traefik) tiene autorización para alcanzar el puerto 443 del gateway.

---

## 7. Integrated Services & Packages (Informative)

* **Tailscale (Mesh VPN):** Instalado vía os-tailscale plugin / CLI. Interfaz registrada y asignada como `opt1` para permitir la aplicación de reglas de firewall y ruteo interno desde redes remotas al entorno de OPNsense.
* **Traefik Reverse Proxy:** El manejo del certificado de dominio (`infra.sintaq.net`) es gestionado por un contenedor/instancia de Traefik ubicado frente al OPNsense, utilizando el resolver de DNS de Cloudflare.

---

## 8. Maintenance & Backup Protocol (Informative)

* **Proxmox Level:** Respaldos del estado de la VM (Snapshot/VZDump) gestionados por Proxmox (PBS o almacenamiento local) previo a actualizaciones mayores del sistema operativo (OS Upgrades).
* **OPNsense Level:** Descarga manual (o vía Nextcloud/Git plugin si aplica) del archivo `config.xml` antes de modificar reglas de enrutamiento o NAT complejas.

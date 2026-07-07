# Proxmox VE Hypervisor

## Document Control

* **Hostname:** `pve2`
* **Cluster:** `pve-cluster`
* **Role:** Compute Node / Hypervisor
* **OS:** Proxmox VE 8.4.0

> **Alcance:** Este documento cubre únicamente la capa **física y de bootstrap** del hipervisor (lo que se configura manualmente sobre el host). El aprovisionamiento de VMs y LXCs (CPU, RAM, disco, red, cloud-init) es declarativo y vive en `terraform/` y `ansible/` — la fuente de verdad de esos recursos es el código, no esta página.

## 1. Hardware Specifications & Infrastructure Base

El nodo opera sobre hardware compacto (Mini PC Beelink).

| Componente | Especificación | Detalles / Estado |
| :--- | :--- | :--- |
| **CPU** | AMD Ryzen 7 6800U | 8 Cores / 16 Threads (2.7GHz - 4.7GHz) + iGPU AMD Radeon 680M |
| **RAM** | 32 GB (4x 8 GB Micron) | 6000 MHz (~28 GB utilizables por OS) |
| **Storage** | 512 GB SSD NVMe | ADATA LEGEND 900 |
| **Network (LAN)** | 2x Realtek Gigabit | Interfaces a 1 Gbps |
| **Network (WLAN)** | Intel Wi-Fi 6 AX200 | **Deshabilitada** (Operación estricta por cable) |
| **Boot System** | UEFI sobre ZFS | `rpool/ROOT/pve-1` |

---

## 3. Network Architecture (Host Bridges)

Configuración de red a nivel del host (Capa 2). Los bridges se definen manualmente sobre el hipervisor; las interfaces de las VMs/LXCs que cuelgan de ellos son declarativas (Terraform).

| Interfaz / Bridge | Tipo | Propósito |
| :--- | :--- | :--- |
| `nic0` (Física) | Puerto esclavo | Asignado a `vmbr0`. |
| `nic1` (Física) | Puerto esclavo | Asignado a `vmbr1`. |
| **`vmbr0`** (Bridge) | LAN principal | Management de Proxmox y red primaria de las cargas de trabajo. |
| **`vmbr1`** (Bridge) | Bridge aislado | Segmentación de red (uso por el firewall perimetral). |

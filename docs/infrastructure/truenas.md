# As-Built Documentation: TrueNAS SCALE Storage Node

## Document Control

* **System:** TrueNAS SCALE
* **OS Version:** 25.04.2.6
* **Hostname:** `truenas.infra.sintaq.net`
* **Domain:** `infra.sintaq.net`
* **Timezone:** `America/Hermosillo`
* **NTP Servers:** Debian Pool (`0.debian.pool.ntp.org`, `1.debian.pool.ntp.org`, `2.debian.pool.ntp.org`)

## 1. Hardware & Resource Allocation

El sistema opera sobre hardware bare-metal con una asignación de memoria fuertemente sesgada hacia la caché de lectura de ZFS (ARC), garantizando un rendimiento óptimo de I/O.

| Componente | Especificación | Detalles / Estado |
| :--- | :--- | :--- |
| **CPU** | Intel(R) Core(TM) i3-8100 | 4 Cores @ 3.60GHz |
| **RAM Total** | 16 GiB (15.4 GiB Usables) | Asignación ZFS ARC: `13.1 GiB` / Servicios: `1.8 GiB` |
| **Storage (Data)** | 1x SSD NVMe (~1 TB) | `nvme0n1` |

---

## 2. Network Architecture & Security

El servidor está expuesto únicamente a segmentos de red internos y de gestión, utilizando el servidor DNS local para resolución.

### 2.1 Interface & IP Configuration

| Interfaz | Estado | Dirección IP | Gateway IPv4 | DNS Primario | Protocolos Activos |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `eno1` | UP | `192.168.100.22/24` | `192.168.100.1` | `192.168.100.23` | mDNS, WSD, NetBIOS |

### 2.2 Access Control (GUI & API)

El panel de administración web y la API operan bajo estrictas políticas de filtrado de IPs (Allowlist).

* **Web GUI Port:** HTTPS `443` (Redirección HTTP a HTTPS habilitada).
* **TLS Protocol:** TLSv1.3 (Certificado: `truenas_default`, SAN: `localhost`).
* **Session Timeout:** 6 horas.
* **Allowed IP Addresses:** `192.168.100.24/32` (Proxy/Bastión) y `100.64.0.0/10` (Red Tailscale).

---

## 3. Identity and Access Management (IAM)

Las credenciales locales y permisos están distribuidos para soportar autenticación de servicios (Samba) y administración del sistema.

### 3.1 Usuarios y Grupos

| Username | UID | GID | Acceso Shell | Samba Auth | Roles Adicionales |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `root` | `0` | `0` | `zsh` | No | Full Admin |
| `truenas_admin` | `950` | `950` | `zsh` | No | Full Admin |
| `erickcastillo` | `3000` | `3000` | `nologin` | **Sí** | Full Admin (Sudo: Sí) |
| `bcorella` | `3002` | `3001` | `nologin` | **Sí** | Estándar (Sudo: No) |

---

## 4. Storage Subsystem & ZFS ACLs (Security)

La topología de almacenamiento utiliza un disco NVMe (Stripe) con encriptación nativa **AES-256-GCM** aplicada en la raíz del pool. La gestión de permisos utiliza un esquema híbrido (POSIX para compatibilidad básica/legado y NFSv4 para granularidad en recursos compartidos de Windows/SMB).

### 4.1 Zpool Dataset Hierarchy

* **Pool Name:** `zpool`
* **Capacity:** ~928 GiB (Asignado: `308.74 GiB`)
* **Features:** Compression: `lz4` / Deduplication: `OFF`

### 4.2 Matriz de Permisos y Control de Acceso (ACLs)

#### A. Dataset Raíz: `/mnt/zpool`

* **Tipo de Permisos:** UNIX (POSIX Básicos)
* **Propietario:** `root` | **Grupo:** `root`
* **Reglas:**
  * Owner (`root`): `Read | Write | Execute`
  * Group (`root`): `Read | Execute`
  * Other: `Read | Execute`

#### B. Datasets Privados: `/mnt/zpool/Personal` (y sub-datasets `Documents` y `Media`)

* **Tipo de Permisos:** NFSv4 ACL (Case Sensitivity: OFF)
* **Propietario:** `erickcastillo` | **Grupo:** `erickcastillo`
* **Listas de Control de Acceso (ACEs):**
  * `owner@` (`erickcastillo`): **Allow | Full Control**
  * `group@` (`erickcastillo`): **Allow | Full Control**
  * `Group - builtin_users`: **Deny | Special** (Fuerza denegación a usuarios generales no autorizados).
  * `Group - builtin_administrators`: **Deny | Special**
* **Herencia (Flags):** Los permisos NFSv4 tienen habilitados explícitamente `File Inherit` y `Directory Inherit`, garantizando que cualquier carpeta o archivo creado en `Documents` o `Media` herede esta misma postura de máxima restricción.

#### C. Dataset Compartido: `/mnt/zpool/Retrobat`

* **Tipo de Permisos:** POSIX ACL Extendidos (Case Sensitivity: ON)
* **Propietario:** `erickcastillo` | **Grupo:** `erickcastillo`
* **Reglas Directas y por Defecto (Default ACLs para nuevos archivos):**
  * `User Obj` (`erickcastillo`): `Read | Write | Execute`
  * `Group Obj` (`erickcastillo`): `Read | Write | Execute`
  * **`User - bcorella`**: `Read | Execute` *(Acceso estrictamente de solo lectura).*
  * `Mask`: `Read | Write | Execute`
  * `Other`: `None` *(Bloqueo total a usuarios no enumerados).*

---

## 5. Network Shares (Samba/SMB)

Se han exportado los siguientes recursos de red, los cuales se apoyan directamente en los ACLs de ZFS configurados en el punto 4.2 para hacer cumplir la seguridad.

| Share Name | Path Mapeado | Estado | Notas de Acceso |
| :--- | :--- | :--- | :--- |
| **Documents** | `/mnt/zpool/Personal/Documents` | Habilitado | Restringido por NFSv4 a `erickcastillo`. |
| **Media** | `/mnt/zpool/Personal/Media` | Habilitado | Restringido por NFSv4 a `erickcastillo`. |
| **Personal** | `/mnt/zpool/Personal` | Habilitado | Punto de montaje padre. Restringido por NFSv4. |
| **Retrobat** | `/mnt/zpool/Retrobat` | Habilitado | Regido por POSIX. `erickcastillo` (R/W), `bcorella` (R-Only). |

---

## 6. Applications & Workloads

### 6.1 Tailscale (VPN Mesh)

* **Estado:** Running (App Version: `v1.96.5` / Community Train).
* **Montajes:** Interfaz de Red del host montada directamente (`Network device`).
* **Privilegios de Seguridad:**
  * `UID: 0` / `GID: 0` (Ejecución como root del host).
  * `CHOWN` y `DAC_OVERRIDE` (Bypass de permisos para gestión de red profunda).

---

## 7. Auditing & Logging Policies

* **Audit Retention:** 7 Días.
* **Storage Quota Warnings:** Alerta visual a `75%`, crítica a `95%`.
* **Syslog Transport:** UDP (Nivel: Info).

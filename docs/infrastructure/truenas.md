# As-Built Documentation: TrueNAS SCALE Storage Node

## Document Control

* **System:** TrueNAS SCALE
* **OS Version:** 25.04.2.6
* **Role:** Almacenamiento NFS/SMB (ZFS) para el resto de la infraestructura

> **Alcance:** TrueNAS **no** se gestiona por IaC; este documento es la fuente de verdad de su configuración de bootstrap manual (ZFS, ACLs, datasets, IAM y shares).

## 1. Hardware & Resource Allocation

El sistema opera sobre hardware bare-metal con una asignación de memoria fuertemente sesgada hacia la caché de lectura de ZFS (ARC), garantizando un rendimiento óptimo de I/O.

| Componente | Especificación | Detalles / Estado |
| :--- | :--- | :--- |
| **CPU** | Intel(R) Core(TM) i3-8100 | 4 Cores @ 3.60GHz |
| **RAM Total** | 16 GiB (15.4 GiB Usables) |  |
| **Storage (Data)** | 1x SSD NVMe (~1 TB) | `nvme0n1` |

---

## 4. Storage Subsystem

* **Pool Name:** `zpool`
* **Capacity:** ~928 GiB
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
* **Propietario:** Admin principal
* **Listas de Control de Acceso (ACEs):**
  * `owner@`: **Allow | Full Control**
  * `group@`: **Allow | Full Control**
  * `Group - builtin_users`: **Deny | Special** (Fuerza denegación a usuarios generales no autorizados).
  * `Group - builtin_administrators`: **Deny | Special**
* **Herencia (Flags):** Los permisos NFSv4 tienen habilitados explícitamente `File Inherit` y `Directory Inherit`, garantizando que cualquier carpeta o archivo creado en `Documents` o `Media` herede esta misma postura de máxima restricción.

#### C. Dataset Compartido: `/mnt/zpool/Retrobat`

* **Tipo de Permisos:** POSIX ACL Extendidos (Case Sensitivity: ON)
* **Propietario:** Admin principal
* **Reglas Directas y por Defecto (Default ACLs para nuevos archivos):**
  * `User Obj` (admin): `Read | Write | Execute`
  * `Group Obj`: `Read | Write | Execute`
  * **Usuario estándar**: `Read | Execute` *(Acceso estrictamente de solo lectura).*
  * `Mask`: `Read | Write | Execute`
  * `Other`: `None` *(Bloqueo total a usuarios no enumerados).*

---

## 5. Network Shares (Samba/SMB)

Se han exportado los siguientes recursos de red, los cuales se apoyan directamente en los ACLs de ZFS configurados en el punto 4.2 para hacer cumplir la seguridad.

| Share Name | Path Mapeado | Estado | Notas de Acceso |
| :--- | :--- | :--- | :--- |
| **Documents** | `/mnt/zpool/Personal/Documents` | Habilitado | Restringido por NFSv4 al admin principal. |
| **Media** | `/mnt/zpool/Personal/Media` | Habilitado | Restringido por NFSv4 al admin principal. |
| **Personal** | `/mnt/zpool/Personal` | Habilitado | Punto de montaje padre. Restringido por NFSv4. |
| **Retrobat** | `/mnt/zpool/Retrobat` | Habilitado | Regido por POSIX. Admin (R/W), usuario estándar (R-Only). |

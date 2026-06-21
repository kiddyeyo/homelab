# As-Built Documentation: Local DNS & Ad-Blocking Server

## Document Control

* **System:** Pi-hole (v6 Architecture)
* **OS Version:** Ubuntu 24.04.4 LTS (Noble Numbat)
* **Hostname:** `pihole-dns`
* **Domain:** `infra.sintaq.net`
* **Role:** Primary DNS Resolver & Network Sinkhole
* **Timezone:** `America/Hermosillo` *(Heredada)*

## 1. Container Provisioning & Compute (Proxmox LXC)

El servicio se ejecuta como un contenedor Linux (LXC) sin privilegios, con los módulos del kernel necesarios habilitados para soportar contenedores anidados (Docker) y túneles de red (VPN).

### 1.1 Virtual Hardware Allocation

* **LXC ID:** `101` (Node: `pve2`)
* **Privilege Level:** Unprivileged (`unprivileged: 1`)
* **CPU:** 1 vCore (AMD Ryzen 7 6800U architecture)
* **Memory (RAM):** 512 MB
* **Swap:** 512 MB
* **Boot Policy:** Start on boot (`onboot: 1`)

### 1.2 Storage & Filesystem

* **Storage Pool:** `local-zfs`
* **Volume:** `subvol-101-disk-0`
* **Allocated Size:** 10 GB
* **Mount Point:** `/`

### 1.3 Advanced Features (LXC config)

* **Nesting:** Enabled (`nesting=1`). Permite la ejecución del demonio de Docker (`docker0` detectado en la pila de red).
* **Keyctl:** Enabled (`keyctl=1`).
* **Device Passthrough:** `/dev/net/tun` mapeado para permitir el enrutamiento del adaptador de Tailscale.

---

## 2. Network & Interfaces Configuration

El contenedor opera con múltiples interfaces lógicas para servir DNS tanto a la red local como a la red mallada.

| Interfaz | Estado | Dirección IP | Gateway IPv4 | Notas / Propósito |
| :--- | :--- | :--- | :--- | :--- |
| **`eth0`** | UP | `192.168.100.23/24` | `192.168.100.1` | Interfaz principal (LAN). Conectada a `vmbr0`. MAC: `BC:24:11:DF:19:9C`. |
| **`tailscale0`** | UP | `100.118.187.71/32` | N/A | VPN Mesh nativa. |
| **`docker0`** | DOWN | `172.17.0.1/16` | N/A | Bridge de red interno para contenedores locales. |

* **Resolución Local (`/etc/resolv.conf`):** El propio contenedor se utiliza a sí mismo como nameserver principal (`192.168.100.23`) con dominio de búsqueda `infra.sintaq.net`.

---

## 3. Pi-hole Service Architecture (DNS / FTL v6)

El servidor DNS no realiza resolución recursiva directa hacia internet, sino que delega las consultas válidas a un resolver local en un puerto alterno (típicamente *Unbound*).

### 3.1 DNS Forwarding & Core Settings

* **Upstream DNS Server:** `127.0.0.1#5335` (Resolución recursiva local).
* **Listening Mode:** `ALL` (Responde en todas las interfaces: `eth0`, `tailscale0`, `docker0`).
* **DNSSEC:** Enabled (Validación de firmas activada).
* **Cache Size:** 10,000 registros (con `use-stale-cache` de 3600s para optimizar latencia).
* **Blocking Mode:** `NULL` (Responde `0.0.0.0` o `::` a dominios bloqueados).
* **Rate Limiting:** 1000 queries / 60 segundos por cliente.

### 3.2 Blocklists (Gravity)

* **Adlists:** Lista estándar de StevenBlack (`https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts`).

---

## 4. Local DNS Records & Infrastructure Mapping

Pi-hole actúa como la fuente principal de verdad (Single Source of Truth) para el descubrimiento de servicios de la infraestructura interna.

### 4.1 A Records (Custom Hosts)

| Hostname | FQDN Base (`.infra.sintaq.net` implícito si aplica) | IP Address |
| :--- | :--- | :--- |
| `opnsense` | `opnsense` | `192.168.100.1` |
| `proxmox` | `proxmox` | `192.168.100.21` |
| `truenas` | `truenas` | `192.168.100.22` (Tailscale: `100.101.176.50`) |
| `pihole` | `pihole` | `192.168.100.23` |
| `traefik` | `traefik` | `192.168.100.24` (Proxy host/Bastion) |
| `infra.sintaq.net` | `infra.sintaq.net` | `192.168.100.24` (Tailscale: `100.92.217.120`) |
| `vaultwarden` | `vaultwarden` | `192.168.100.25` |
| `immich` | `immich` | `192.168.100.28` |
| `paperlessngx` | `paperlessngx` | `192.168.100.29` |
| `homepage` | `homepage` | `192.168.100.30` |
| `monitoring` | `monitoring` | `192.168.100.31` |

### 4.2 CNAME Records (Service Aliases)

Todos los servicios expuestos a través del proxy inverso apuntan mediante CNAME al dominio principal (`infra.sintaq.net`), el cual resuelve hacia la IP del servidor Traefik (`192.168.100.24`).

* `opnsense.infra.sintaq.net`
* `pihole.infra.sintaq.net`
* `proxmox.infra.sintaq.net`
* `vaultwarden.infra.sintaq.net`
* `proxy.infra.sintaq.net`
* `truenas.infra.sintaq.net`
* `immich.infra.sintaq.net`
* `paperless.infra.sintaq.net`
* `homepage.infra.sintaq.net`
* `dozzle.infra.sintaq.net`

---

## 5. Web Interface & API Security

La administración del sistema a través de la interfaz web (o llamadas API) está protegida por listas de control de acceso (ACLs) restrictivas.

* **Web UI Ports:** `80`, `443s` (Redirección HTTP a HTTPS y certificado automático Let's Encrypt / TLS interno si aplica).
* **Web UI ACL (`webserver.acl`):** `+192.168.100.24` > **Nota de Seguridad:** El panel de administración de Pi-hole está bloqueado para toda la red, **excepto** para la IP del proxy inverso (`192.168.100.24`). Cualquier intento de acceso directo desde la LAN será rechazado por el servidor web interno (CivetWeb).
* **Theme:** `high-contrast-dark`
* **API Auth:** Autenticación requerida vía Hash (Configurado `pwhash` y `app_pwhash`).

## 6. Recursive DNS Resolver (Unbound)

En lugar de utilizar servidores DNS públicos (como Google o Cloudflare), el sistema utiliza Unbound como un resolver recursivo autoritativo completo. Esto garantiza que las consultas DNS no sean rastreadas por terceros y se validen de origen a destino.

### 6.1 Network & Listen Interfaces

* **Listen Interface:** `127.0.0.1` (Aislado, solo Pi-hole puede consultarlo).
* **Port:** `5335`
* **Protocols:** IPv4 (TCP y UDP activados). **IPv6 desactivado** (`do-ip6: no`, `prefer-ip6: no`).

### 6.2 Security & DNSSEC Validation

* **DNSSEC Anchors:** Archivo de confianza raíz autogestionado (`auto-trust-anchor-file: "/var/lib/unbound/root.key"`).
* **Strict Validation:** `harden-dnssec-stripped: yes` (Si falta la firma en una zona de confianza, se clasifica como BOGUS y se bloquea).
* **Spoofing Protection:** `harden-glue: yes` (Solo confía en registros "glue" dentro de la autoridad del servidor).
* **Privacy Controls:** Consultas inversas hacia rangos IP locales y privados están explícitamente denegadas y no se envían a internet (`private-address` en rangos RFC 1918 y RFC 6303).

### 6.3 Performance Tuning & Caching

Unbound está altamente sintonizado para hardware multinúcleo y mitigación de problemas de fragmentación de red.

| Parámetro | Valor | Propósito |
| :--- | :--- | :--- |
| `num-threads` | `2` | Paralelización de consultas adaptada a los vCores disponibles. |
| `msg-cache-size` | `128m` | Caché de mensajes y estructura de respuesta. |
| `rrset-cache-size` | `256m` | Caché de registros (RRSet), configurado al doble del `msg-cache` como buena práctica. |
| `edns-buffer-size` | `1232` | Prevención de fragmentación de paquetes UDP (Estándar *DNS Flag Day 2020*). |
| `prefetch` | `yes` | Renovación automática de dominios populares antes de que expire su TTL. |

### 6.4 Operational Caveats (As-Built Notes)

> **Alerta del Kernel / Buffer:** En los registros de inicio del servicio (Systemd) se observa la advertencia: `warning: so-rcvbuf 2097152 was not granted. Got 425984.` Unbound solicita 2MB para el buffer de recepción (`so-rcvbuf: 2m`), pero el contenedor LXC no privilegiado hereda el límite máximo del host (`net.core.rmem_max`), el cual por defecto en Proxmox/Debian es menor. Esto **no afecta la operación normal** en una red doméstica/homelab, pero para evitar el warning se requeriría ajustar el `sysctl` directamente en el nodo `pve2`.

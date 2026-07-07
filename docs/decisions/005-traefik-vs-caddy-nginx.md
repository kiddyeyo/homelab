# ADR-005: Traefik sobre Caddy, Nginx y otros reverse proxies

!!! success "Aceptada · 2026-06-20"

## Contexto
El homelab requiere un reverse proxy/edge router que termine TLS para todos los servicios internos (Immich, Vaultwarden, Paperless-NGX, Semaphore UI, etc.), gestionando certificados wildcard vía Cloudflare DNS-01, sin exponer puertos públicos (acceso vía Tailscale), y con configuración por servicio definida estáticamente vía File Provider en vez de auto-discovery dinámico sobre un Docker socket compartido entre VMs.

Las opciones evaluadas:

1. **Nginx** — reverse proxy/servidor web de propósito general, configuración declarativa vía archivos `.conf`.
2. **Caddy** — reverse proxy moderno, configuración simplificada, HTTPS automático de fábrica.
3. **Traefik** — reverse proxy/edge router orientado a infraestructura dinámica, con múltiples providers de configuración (Docker, File, Kubernetes CRD, etc.) y gestión de certificados integrada.

## Decisión
Se usa **Traefik**, corriendo en VM, configurado vía **File Provider** (definición estática por servicio en archivos, no auto-discovery vía Docker socket entre VMs — consistente con la decisión de no exponer el Docker socket entre VMs), con certificados wildcard emitidos vía **Cloudflare DNS-01 challenge**.

## Alternativas consideradas

### Nginx
- Rechazado por ser, en comparación, más verboso y "clunky" para este caso de uso específico: la sintaxis de `.conf` de Nginx para reverse proxy + TLS + routing por servicio requiere más líneas y más repetición por cada nuevo servicio que el equivalente declarativo en Traefik (dynamic configuration vía YAML).
- La renovación automática de certificados no es nativa — requiere Certbot (u otra herramienta externa) como capa adicional, con su propio cron/timer y su propia integración con el método de challenge (en este caso, DNS-01 de Cloudflare). Esto introduce una pieza más de software a mantener fuera del propio Nginx.
- Nginx sigue siendo superior en escenarios de altísimo rendimiento o necesidades muy específicas de tuning a bajo nivel — pero esa ventaja no es relevante en el contexto de un homelab personal con tráfico bajo y predecible.

### Caddy
- Conceptualmente muy similar a Traefik en cuanto a configuración declarativa y simplicidad de uso — ambos están diseñados para reducir la fricción frente a Nginx.
- Rechazado frente a Traefik específicamente por **menor capacidad de automatización de certificados** en el escenario de DNS-01 con Cloudflare para wildcard: aunque Caddy sí soporta DNS-01 vía plugins (`caddy-dns/cloudflare`), requiere compilar un binario custom con el plugin incluido (`xcaddy` o build propia), ya que el binario oficial no lo trae de fábrica. Traefik soporta DNS-01 con Cloudflare de forma nativa en el binario estándar, sin pasos de build adicionales.
- Esto se traduce en menos piezas que mantener actualizadas (no hay que rebuildear Caddy en cada actualización de versión para conservar el plugin) y menos fricción operativa para un caso de uso que ya estaba resuelto de forma más directa en Traefik.

### Traefik (elegido)
- Soporte nativo de DNS-01 challenge con Cloudflare en el binario estándar, sin necesidad de builds custom ni plugins externos — resuelve exactamente el requerimiento de certificados wildcard sin pasos adicionales.
- "All-in-one" en el sentido de que routing, terminación TLS, gestión de certificados (ACME) y middlewares viven en una sola herramienta con una sola configuración coherente, en vez de repartir responsabilidades entre el proxy y herramientas externas (Certbot, plugins de build).
- Ecosistema de middlewares (headers, rate limiting, autenticación básica/forward-auth, compresión, redirects) configurable de forma declarativa y componible, reutilizable entre servicios sin duplicar lógica.
- Soporta múltiples providers de configuración (Docker, File, Kubernetes CRD, Consul, etc.), lo que da flexibilidad futura sin cambiar de herramienta — en este caso se usa específicamente File Provider porque Traefik y los demás servicios corren en VMs distintas sin Docker socket compartido (decisión de seguridad ya tomada), y el provider de Docker auto-discovery requeriría exponer el socket entre VMs, lo cual se descartó explícitamente.
- En la práctica, configuración percibida como sencilla para el volumen de servicios del homelab, sin el overhead de Nginx ni el paso extra de build de Caddy.

## Consecuencias
- (+) Certificados wildcard renovados automáticamente vía DNS-01 con Cloudflare, sin intervención manual ni binarios custom.
- (+) Una sola herramienta resuelve routing + TLS + middlewares, sin depender de Certbot ni plugins compilados aparte.
- (+) File Provider permite definir el routing de cada servicio de forma declarativa y versionada en Git, sin necesidad de exponer el Docker socket entre VMs.
- (+) Ecosistema de middlewares reduce duplicación de configuración entre servicios.
- (-) File Provider implica mantenimiento manual de la configuración por servicio (a diferencia del auto-discovery vía labels de Docker) — aceptado como trade-off consciente a cambio de no exponer el Docker socket entre VMs.
- (-) Traefik es menos conocido que Nginx en términos de volumen de documentación/comunidad para casos de borde muy específicos — mitigado porque la documentación oficial de Traefik cubre suficientemente bien el caso de uso de File Provider + DNS-01.

## Relacionado
- ADR-002 (VMs sobre LXC — Traefik corre en su propia VM de edge)
- Decisión relacionada: no exponer Docker socket entre VMs (justifica el uso de File Provider en vez de Docker provider/auto-discovery).

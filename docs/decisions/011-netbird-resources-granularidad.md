# ADR-011: Control de acceso granular por servicio vía NetBird Resources + nameserver local (Pi-hole)

!!! success "Aceptada · 2026-06-22"

## Contexto

ADR-010 estableció la migración a NetBird, pero dejó pendiente, sin resolver, cómo lograr control de acceso granular por servicio cuando múltiples servicios (Immich, Vaultwarden, y potencialmente otros) viven detrás de la misma VM/IP de Traefik. El problema concreto: una sola policy de NetBird hacia la IP de Traefik en el puerto 443 da acceso de todo-o-nada a todos los servicios enrutados por esa instancia de Traefik, porque NetBird opera en capa 3/4 (IP+puerto) y no inspecciona el `Host()` HTTP que distingue un servicio de otro.

Se exploraron y descartaron las siguientes alternativas antes de llegar a la solución adoptada:

- **ForwardAuth con Authelia/Authentik como middleware de Traefik.** Funciona correctamente para aplicaciones web puras sin cliente nativo, pero rompe aplicaciones con cliente API-first (Immich, Vaultwarden): el cliente nativo espera una respuesta JSON/API de la aplicación, no un redirect HTTP a un portal de login HTML, y no sabe interpretar ese redirect. Aplicarlo selectivamente (solo a routers sin cliente nativo) es viable, pero no resuelve el caso de Immich/Vaultwarden, que es el caso de uso concreto que motivó esta decisión.

- **NetBird Network Routes con IP interna directa, bypaseando Traefik.** Sí da granularidad real por servicio (policy por IP de servicio específico), pero pierde el TLS válido que Traefik provee vía Let's Encrypt/DNS-01 — la app pasaría a recibirse por HTTP plano o un cert no válido para esa IP. Descartado explícitamente: Immich no funciona de forma confiable sin TLS válido en su cliente móvil.

- **IPAllowList por router en Traefik, usando rangos de IP de NetBird.** Resuelve granularidad y mantiene TLS intacto, pero requiere editar el file provider de Traefik (IaC) y redeployar cada vez que cambia quién tiene acceso a qué servicio. Descartado por fricción operativa inaceptable para cambios de acceso frecuentes, y porque las IPs de los peers a quienes se da acceso no son garantizadamente estables para hardcodearse de forma duradera en configuración versionada.

- **mTLS (certificados de cliente) por router en Traefik.** Da granularidad real, en el handshake TLS, sin redirect ni ruptura de cliente nativo. Descartado por el costo operativo de gestionar una CA propia y distribuir/revocar certificados de cliente — complejidad desproporcionada para el número de servicios y personas involucradas actualmente.

- **Traefik como sidecar por VM (una instancia por servicio) en vez de centralizado.** Resuelve el problema porque cada servicio tiene su propio punto de entrada/TLS/IP de NetBird independiente. Descartado como solución general porque multiplica la gestión de certificados ACME y la superficie de configuración linealmente por servicio, revirtiendo el razonamiento de ADR-005 (Traefik centralizado) sin necesidad, dado que se encontró una solución que no requiere ese sacrificio. Queda como opción de respaldo para casos excepcionales no cubiertos por la solución adoptada.

## Decisión

Usar el modelo de **Networks, Routing Peers, Resources y Policies de NetBird**, configurando un **nameserver custom (Pi-hole local)** asociado a la Network del homelab, con **Resources definidos por dominio** (no por IP), para lograr control de acceso granular por servicio sin modificar la configuración de Traefik ni sacrificar TLS.

Mecanismo: se crea una Network en NetBird (ej. `homelab`) con un Routing Peer (el host de Proxmox o una VM con ruta a la red interna). Se configura un nameserver para esa Network apuntando al Pi-hole local, especificando los dominios que debe resolver. Cada servicio expuesto vía Traefik se declara como un Resource dentro de la Network, identificado por su FQDN (ej. `immich.tudominio.com`, `vault.tudominio.com`) — no por IP. Las Policies se definen contra estos Resources, no contra la IP compartida de Traefik.

El enforcement ocurre en el plano de NetBird, antes de que exista una conexión TCP hacia Traefik: si un peer no tiene una Policy que le otorgue acceso a un Resource específico, NetBird no instala una clave WireGuard hacia esa ruta en la interfaz del peer — la conexión no se establece (sin key), independientemente de si se intenta acceder por el FQDN declarado o directo a la IP subyacente. Traefik continúa recibiendo únicamente tráfico ya autorizado, y opera sin cambios: sigue terminando TLS con sus certs de Let's Encrypt/DNS-01 de forma normal, sin necesidad de IPAllowList, ForwardAuth, ni mTLS adicional.

Validado empíricamente: intentos de conexión a dominios resolubles por Pi-hole pero no declarados como Resource, e intentos por IP directa al mismo destino, fueron bloqueados por NetBird (error de ausencia de clave WireGuard), confirmando enforcement real a nivel de plano de red, no solo ocultamiento por DNS.

## Alternativas consideradas

Ver sección Context — cada alternativa descartada incluye su razón técnica específica de rechazo. Adicionalmente se evaluó:

- **Twingate**, cuyo modelo es estructuralmente similar pero con una diferencia relevante: el Connector de Twingate resuelve DNS usando la configuración de red local donde está desplegado (heredada implícitamente), en vez de una declaración explícita de nameserver por Network como en NetBird. Adicionalmente, el Relay de Twingate nunca termina conexiones que transportan datos — actúa solo como facilitador de NAT traversal en un túnel TLS de extremo a extremo cifrado entre Cliente y Connector, mientras que con NetBird Cloud la metadata de qué Resources existen (nombres de dominio) es visible para la plataforma de NetBird. No se considera suficiente para reconsiderar la decisión de ADR-010: Twingate no ofrece control plane self-hosteable bajo ninguna circunstancia, mientras NetBird sí, y el costo de migrar de plataforma nuevamente no se justifica por esta diferencia marginal de exposición de metadata.

## Consecuencias

- (+) Traefik permanece centralizado, sin cambios a su configuración ni a su modelo de gestión de certificados (consistente con ADR-005).
- (+) Control de acceso granular por servicio gestionado enteramente desde el dashboard de NetBird — agregar o revocar acceso a un servicio específico no requiere tocar IaC ni redeployar Traefik.
- (+) TLS válido de extremo a extremo intacto para cada servicio.
- (+) Enforcement real a nivel de plano de red (ausencia de clave WireGuard), no dependiente de ocultamiento por DNS ni de listas de IP potencialmente inestables.
- (+) Compatible con aplicaciones de cliente nativo/API-first (Immich, Vaultwarden) sin romper su flujo de autenticación, a diferencia de ForwardAuth.
- (-) Depende de mantener el nameserver custom (Pi-hole) correctamente configurado y disponible para la Network de NetBird; si Pi-hole falla, la resolución de Resources por dominio dentro de esa Network se ve afectada. Mitigado porque Pi-hole ya es una dependencia existente del homelab, no una pieza nueva introducida por esta decisión.
- (-) Cada servicio nuevo requiere declarar explícitamente su Resource en NetBird (dominio + Network) antes de ser accesible con esta granularidad — paso administrativo adicional al desplegar un nuevo servicio, aunque menor comparado con el de mantener reglas de Traefik por IP.
- (-) La metadata de qué Resources (dominios) existen en el homelab es visible para NetBird Cloud, dado que no se está self-hosteando el control plane (ver ADR-010). Aceptado como parte del mismo trade-off ya documentado en ADR-010.

## Relacionado

- ADR-010 (NetBird sobre Tailscale) — esta decisión resuelve el punto que ADR-010 dejó explícitamente pendiente: el mecanismo de control de acceso granular por servicio.
- ADR-005 (Traefik sobre Caddy/Nginx, centralizado) — esta decisión reafirma y preserva esa arquitectura centralizada, en vez de requerir su reemplazo por sidecars per-VM.
- ADR-009 (break-glass path: Proxmox, TrueNAS y Semaphore por IP directa, sin Traefik) — no afectado por esta decisión; esos componentes permanecen fuera del modelo de Resources por dominio, accesibles vía policy directa de NetBird como ya estaba definido.

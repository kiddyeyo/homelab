# ADR-012: Technitium DNS Server (con zona autoritativa local) sobre Pi-hole

## Status
Accepted

## Context

El homelab usa actualmente Pi-hole como servidor DNS para filtrado de anuncios/tracking y resolución de nombres locales vía Local DNS Records (tabla plana nombre→IP sin estructura de zona). Pi-hole opera como capa de filtrado sobre dnsmasq, en modo forwarding hacia upstreams externos, sin soporte nativo de protocolos cifrados (DoH/DoT) como servidor ni como cliente, y sin capacidad de ser autoritativo para ningún dominio.

Tres limitaciones concretas de Pi-hole motivaron esta decisión:

1. **Sin resolución reversa real.** No existe mecanismo para PTR records sobre un dominio propio, lo que mantiene los logs de Traefik, journald y otros servicios mostrando IPs en vez de nombres.

2. **Sin zona autoritativa.** Local DNS Records es una tabla de overrides sin SOA, sin NS, sin flag AA (Authoritative Answer), sin NXDOMAIN formal cacheable, y sin soporte de tipos de registro más allá de A/AAAA/CNAME. No es posible declarar `infra.sintaq.net` como una entidad administrativa real del namespace DNS.

3. **Sin API suficiente para integración con el monorepo IaC.** El flujo actual de creación de VMs vía Terraform no tiene forma de propagar automáticamente un registro DNS correspondiente — el registro se crea a mano en la UI de Pi-hole, rompiendo el principio de "nada configurado manualmente salvo el bootstrap inicial" ya aplicado al resto del stack (Proxmox, Semaphore, GitHub Actions runner).

NetBird ya usa Pi-hole como nameserver custom para resolución de Resources por FQDN dentro de la Network (ver ADR-011). Esta dependencia debe preservarse o migrarse explícitamente al evaluar el reemplazo.

## Decision

Migrar de Pi-hole a **Technitium DNS Server**, desplegado en una VM dedicada dentro de la topología VM-per-service existente, con tres componentes de alcance:

1. **Reemplazo del servidor DNS** (forwarding + blocklists), preservando funcionalidad equivalente a Pi-hole como filtro de anuncios/tracking.
2. **Creación de una zona Primary autoritativa para `infra.sintaq.net`**, con SOA y NS propios, reemplazando los Local DNS Records actuales por registros de zona real (A, y PTR vía zona reversa para el rango de la LAN del homelab).
3. **Integración programática vía la API HTTP nativa de Technitium**, consumida desde el monorepo IaC (Terraform y/o Ansible) para que la creación de una VM propague automáticamente su registro DNS correspondiente, sin paso manual.

NetBird se reconfigura para usar Technitium como nameserver custom de la Network (mismo rol que cumplía Pi-hole), sin cambios en el modelo de Resources/Policies ya definido en ADR-011.

## Alternatives Considered

### Mantener Pi-hole, añadir Unbound como recursivo
Resolvería parcialmente forwarding cifrado hacia upstream, pero no añade capacidad de zona autoritativa ni API de zona — el problema central (DNS como overrides sin estructura, sin integración IaC) persiste. Rechazado: no resuelve el motivo principal de la migración.

### AdGuard Home
Evaluado como paso intermedio. Mejora sobre Pi-hole en protocolos cifrados nativos (DoH/DoT/DNSCrypt/DoQ como servidor) y filtros estilo Adblock, pero mantiene el mismo modelo de "Local DNS Records" sin zona real — no resuelve PTR, SOA/NS, ni autoridad formal. Rechazado como destino final porque introduciría una migración intermedia sin resolver el problema de fondo; quedaría como migración doble innecesaria antes de llegar a Technitium.

### Servidor autoritativo dedicado en paralelo (BIND/PowerDNS) + Pi-hole o AdGuard Home para filtrado
Separaría las dos responsabilidades (autoridad de zona vs. filtrado) en dos servicios distintos, cada uno especializado. Rechazado: añade un servicio adicional al stack (más superficie de mantenimiento, otra VM, otro componente en el monorepo) cuando Technitium cubre ambas responsabilidades en un solo binario con una sola API.

## Consequences

- (+) Logs de Traefik, journald y otros servicios resuelven IPs internas a nombres FQDN reales vía PTR, sin depender de mapeos manuales.
- (+) `infra.sintaq.net` se convierte en una zona DNS real y formal (SOA, NS, registros con TTL individual), consistente con el comportamiento esperado del protocolo DNS en vez de una tabla de overrides.
- (+) Los registros DNS de las VMs pueden gestionarse como artefacto declarativo dentro del monorepo IaC (vía API de Technitium desde Terraform/Ansible), eliminando el paso manual de creación de registros y extendiendo el principio de "todo como código" ya aplicado al resto del stack.
- (+) Soporte nativo de DoH/DoT/DoQ como servidor y como cliente hacia upstream, sin necesidad de proxies adicionales.
- (+) Camino abierto a DNSSEC sobre la zona propia si en algún momento se requiere validación de integridad interna, sin cambiar de servidor.
- (-) Footprint de memoria mayor que Pi-hole/dnsmasq en reposo, al correr sobre runtime .NET. Aceptado: no es una restricción de recursos crítica en el nodo Proxmox actual.
- (-) Migración no tiene importador automático 1:1 desde Pi-hole; los Local DNS Records existentes deben reescribirse a mano como registros de zona, y las blocklists deben revalidarse (la mayoría son compatibles por formato, pero requieren reconfiguración).
- (-) Requiere instalar la App "Advanced Blocking" desde el catálogo de Apps de Technitium para alcanzar paridad funcional de filtrado con Pi-hole/AdGuard Home — paso adicional ausente en los otros dos.
- (-) Curva de aprendizaje conceptual del modelo de zonas DNS (SOA, NS, AA, NXDOMAIN formal) antes de operar la zona con confianza, aunque ya documentado y entendido previo a esta decisión.
- (-) NetBird debe reconfigurarse para apuntar a la nueva IP/nameserver de Technitium en vez de Pi-hole — cambio de configuración puntual, sin impacto en el modelo de Resources/Policies de ADR-011.

## Related

- ADR-011 (NetBird: Resources por FQDN para granularidad de acceso) — la Network de NetBird depende de un nameserver custom; esta decisión reemplaza ese nameserver de Pi-hole a Technitium sin alterar el modelo de acceso ya definido.
- ADR-010 (NetBird sobre Tailscale) — sin impacto directo, mencionado por la cadena de dependencia del nameserver.

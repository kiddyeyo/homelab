# ADR-0007: Backend de Terraform en PostgreSQL, compartido entre Semaphore y GitHub Actions runner

## Status
Accepted

## Context
El `tfstate` de Terraform necesita vivir en un backend accesible desde **dos** puntos de ejecución distintos (ver ADR-0006): Semaphore UI (ejecución manual vía botones) y un GitHub Actions self-hosted runner (ejecución automática disparada por push, con filtros granulares por path/tag). Ambos puntos de ejecución necesitan leer y escribir el mismo estado sin pisarse entre sí — si Semaphore aplica un cambio manual y luego el runner aplica un cambio granular sobre otro módulo, ambos deben ver el estado actualizado y respetar locking.

Las opciones evaluadas en distintos momentos de este análisis fueron:

1. **Local backend** sobre un volumen Docker persistente — opción inicialmente considerada cuando Semaphore era el único punto de ejecución.
2. **Consul** como backend remoto con locking nativo vía sesiones.
3. **MinIO/S3-compatible** self-hosted con locking nativo de la API S3.
4. **PostgreSQL** como backend remoto.

El contexto cambió la decisión: mientras solo existía un punto de ejecución (Semaphore), el backend local era defendible porque no había necesidad real de compartir estado entre procesos distintos. Al incorporar GitHub Actions self-hosted runner como segundo punto de ejecución (ver ADR-0006), el backend local deja de ser viable — ambos puntos de ejecución corren en contextos potencialmente distintos (VM de Semaphore vs. proceso del runner) y necesitan ver el mismo `tfstate` con locking real entre ejecuciones concurrentes.

## Decision
Se usa **PostgreSQL** como backend remoto de Terraform (`backend "pg"`), apuntando a la instancia de PostgreSQL que ya corre para Semaphore. Tanto Semaphore como el GitHub Actions self-hosted runner usan el mismo backend, garantizando una sola fuente de verdad para el estado sin importar desde qué punto se ejecutó el último `apply`.

## Alternatives Considered

### Local backend sobre Docker volume
- Válido cuando solo existía un punto de ejecución. Rechazado al introducir GitHub Actions como segundo ejecutor: un backend local vive físicamente en el filesystem de un solo proceso/VM, por lo que Semaphore y el runner verían copias de estado distintas y desincronizadas — exactamente el problema que un backend remoto con locking existe para resolver.

### Consul
- Evaluado a fondo en una iteración previa del análisis: locking distribuido nativo vía sesiones, paths de KV store por root module.
- Rechazado por overhead operacional desproporcionado si su único uso es almacenar `tfstate` — Consul aporta valor real cuando también se usa para service discovery o health checking, ninguno de los cuales es un requerimiento actual del homelab. Mantener un servidor Consul exclusivamente como backend de Terraform agrega un componente más sin beneficio proporcional.

### MinIO / S3-compatible
- Self-hosted, consistente con la filosofía de no depender de SaaS de terceros, con locking nativo de la API S3.
- No descartado por una razón técnica de fondo, sino por preferencia: ya existe una instancia de PostgreSQL corriendo (la de Semaphore), y añadir MinIO introduce un componente adicional a mantener (otro servicio, otra VM o stack de Docker, otro backup) cuando el backend de PostgreSQL resuelve el mismo problema sin componentes nuevos.

### PostgreSQL (elegido)
- Backend de Terraform soportado nativamente (`backend "pg"`), con locking real vía advisory locks de PostgreSQL.
- **Reutiliza infraestructura que ya existe**: la misma instancia de PostgreSQL que ya sirve a Semaphore como su base de datos pasa a servir también como backend de `tfstate`, sin levantar un componente nuevo.
- Permite que Semaphore y el GitHub Actions runner compartan el mismo estado sin necesidad de sincronización adicional — ambos apuntan al mismo connection string.
- Operacionalmente más simple que Consul o MinIO para este caso específico, porque no introduce ninguna pieza nueva de infraestructura.

## Consequences
- (+) Una sola fuente de verdad de `tfstate`, consistente entre ejecución manual (Semaphore) y ejecución automática (GitHub Actions runner).
- (+) Sin componentes nuevos de infraestructura — se reutiliza la instancia de PostgreSQL ya existente.
- (+) Locking real entre ejecuciones concurrentes vía advisory locks.
- (-) La disponibilidad de PostgreSQL se vuelve crítica para *cualquier* operación de Terraform (plan/apply) desde cualquiera de los dos puntos de ejecución — antes, con backend local, Semaphore no dependía de ningún servicio externo para acceder a su propio estado. Aceptado como trade-off porque Semaphore ya depende de esa misma instancia de PostgreSQL para funcionar en absoluto.
- (-) Acceso a credenciales de PostgreSQL necesario desde ambos puntos de ejecución — resuelto mediante el mismo mecanismo de SOPS+age usado para el resto de secretos (ver ADR-0003 y ADR-0006), sin necesidad de cargar el connection string como variable suelta en ningún sistema.

## Related
- ADR-0003 (SOPS+age — mecanismo de secretos para el connection string de PostgreSQL)
- ADR-0004 (Semaphore como orquestador manual)
- ADR-0006 (GitHub Actions self-hosted runner como segundo punto de ejecución — la razón por la que este ADR existe)

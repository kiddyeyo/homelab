# ADR-0006: Arquitectura dual Semaphore (manual) + GitHub Actions self-hosted runner (granular), sobre GitLab CI/Jenkins/Drone/Atlantis exclusivos

## Status
Accepted

## Context
El homelab necesita dos modos de ejecución de Terraform/Ansible que resuelven necesidades distintas:

1. **Ejecución manual a demanda**: correr un playbook o un módulo de Terraform puntual desde un panel, sin depender de un commit a Git (ej. un re-run de un task que falló, una operación exploratoria).
2. **Ejecución automática granular disparada por Git**: que un cambio en un archivo específico (ej. un `docker-compose.yml` de un servicio, o un módulo concreto de Terraform) dispare *solo* la tarea correspondiente, sin tener que ejecutar todo el pipeline ni intervenir manualmente. Esto es lo que Semaphore no resuelve de forma nativa: su modelo de templates y triggers no tiene filtrado granular por path/tag a nivel de archivo modificado en un push.

Las herramientas evaluadas, en distintas rondas de análisis:

- **Semaphore UI** (ya en uso como orquestador manual — ver ADR-0004).
- **GitHub Actions** con self-hosted runner.
- **GitLab CI** (autogestionado).
- **Jenkins**.
- **Drone CI**.
- **Atlantis** (PR-native para Terraform).

## Decision
Se adopta una arquitectura de **dos puntos de ejecución con responsabilidades separadas**, compartiendo el mismo mecanismo de secretos (SOPS+age, ver ADR-0003):

- **Semaphore UI** = control node para ejecución **manual** de Terraform y Ansible, vía botones en el panel.
- **GitHub Actions con self-hosted runner** = ejecución **automática** de los mismos playbooks/módulos de Terraform, disparada por triggers de Git (tags, paths, rules), permitiendo cambios granulares por servicio o módulo sin scripting custom.

Ambos puntos de ejecución usan **providers/collections de SOPS** para desencriptar las variables que necesitan justo antes de ejecutar — nunca se carga ningún secreto como variable de entorno persistente en ningún sistema (ni en Semaphore Variable Groups como almacenamiento primario, ni en GitHub Actions Secrets). El control de acceso a los secretos se reduce a una sola pregunta: quién tiene la clave privada de age, listada en el propio repositorio en términos de quién tiene acceso a qué.

GitHub (repo privado, plan Free) se eligió como plataforma Git sobre GitLab self-managed.

## Alternatives Considered

### GitLab CI (self-managed)
- Rechazado frente a GitHub principalmente por el **peso del propio servidor a mantener**: GitLab self-managed no es solo un runner, es un monolito (Rails + PostgreSQL + Redis + Gitaly) que habría que correr y mantener en `pve2` — un componente entero adicional para features que no se necesitan siendo un solo desarrollador (merge trains, push rules avanzados, artifact registry).
- El argumento típico a favor de GitLab (runner en Go, diseñado para self-hosting desde el inicio) aplica solo a la capa de *runner*, que GitHub también resuelve igual de bien con su propio self-hosted runner — no es una ventaja exclusiva de GitLab.
- Push rules ni siquiera está disponible en el tier self-managed más bajo donde sí aplicaría — el argumento de "GitLab da más control" no se sostiene en la práctica al nivel de plan relevante para este caso.

### Jenkins
- Mayor overhead operativo de todas las opciones evaluadas: servidor propio, plugins a mantener, modelo de pipeline (Jenkinsfile/Groovy) más pesado que YAML declarativo.
- Inconsistente con el criterio ya aplicado en el resto del homelab de evitar componentes con overhead injustificado para un solo operador (mismo criterio que llevó a descartar Headscale frente a Tailscale).

### Drone CI
- Evaluado como alternativa ligera basada en contenedores, pero no aporta nada que GitHub Actions self-hosted runner no resuelva ya, mientras que sí introduce una plataforma de CI separada del propio Git host — un componente más, sin necesidad real.

### Atlantis
- Fuerte específicamente para el flujo de PR-native de Terraform (comentarios `plan`/`apply` en el PR), pero **no cubre Ansible**. Habría que mantener Atlantis para Terraform y otra herramienta distinta para disparar Ansible automáticamente — rompe el principio de "un mecanismo, ambas herramientas" que sí cumple GitHub Actions.
- Agrega un componente más para mantener (otro servicio corriendo, expuesto a webhooks de GitHub) por una ventaja de UX que no compensa la pérdida de cobertura de Ansible.

### GitHub Actions con self-hosted runner (elegido)
- Cubre **tanto Terraform como Ansible** bajo el mismo pipeline YAML, sin necesidad de una segunda herramienta para la otra.
- El self-hosted runner hace **polling outbound** hacia GitHub — no requiere exponer ningún puerto ni webhook entrante, consistente con la arquitectura de red existente (Tailscale, sin exposición pública).
- Soporta filtrado granular nativo (`paths:`, `rules: changes:` — funcionalmente equivalente en ambas plataformas) sin scripting custom, resolviendo directamente la necesidad original de disparar tareas específicas según qué archivo cambió.
- El runner self-hosted no consume cuota de minutos de GitHub (el límite de 2,000 min/mes de Free es irrelevante porque la ejecución ocurre en infraestructura propia, no en runners hosteados por GitHub).
- Repo privado por defecto: la seguridad real del homelab no depende de la visibilidad del repositorio (eso ya lo cubren SOPS+age y la ausencia de exposición pública vía Tailscale), pero se mantiene privado como postura por defecto, con la opción de hacerlo público después sin fricción si se quisiera usar GitHub Pages para documentación.
- Plan Free de GitHub es suficiente para el caso actual; el upgrade a Pro ($4/mes) queda disponible de forma trivial si se necesitan protected branches o code owners — sin comparación posible contra el costo de GitLab Premium/Ultimate por usuario.

## Consequences
- (+) Dos modos de ejecución cubiertos sin solaparse: manual (Semaphore) y automático/granular (GitHub Actions), ambos consistentes sobre el mismo estado (ADR-0007) y el mismo mecanismo de secretos (ADR-0003).
- (+) Ningún secreto vive cargado como variable persistente en ningún sistema — el control de acceso se reduce a la distribución de la clave de age, documentada en el propio repo.
- (+) Sin exposición de webhooks entrantes ni puertos públicos — ambos puntos de ejecución operan vía outbound (Semaphore por su propio modelo, el runner por polling hacia GitHub).
- (+) Cambios granulares por servicio/módulo sin scripting custom.
- (-) Dos sistemas de ejecución que mantener en vez de uno — aceptado porque resuelven necesidades genuinamente distintas (ejecución a demanda vs. ejecución disparada por Git) que ninguna herramienta única evaluada cubría sin sacrificar una de las dos.
- (-) Disciplina operativa necesaria para que ambos puntos de ejecución no entren en conflicto sobre el mismo recurso al mismo tiempo — mitigado por el locking nativo del backend de PostgreSQL (ADR-0007).

## Related
- ADR-0003 (SOPS+age — mecanismo único de secretos para ambos puntos de ejecución)
- ADR-0004 (Semaphore como orquestador manual — sigue vigente, ahora como uno de dos puntos de ejecución en vez de el único)
- ADR-0007 (PostgreSQL como backend de Terraform compartido — requisito técnico que esta arquitectura dual genera)

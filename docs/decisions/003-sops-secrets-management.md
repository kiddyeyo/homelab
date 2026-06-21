# ADR-0003: SOPS + age sobre Doppler, Infisical, HCP Vault y Ansible Vault para gestión de secretos

## Status
Accepted

## Context
El homelab requiere un mecanismo para almacenar y distribuir secretos (API tokens, claves SSH, credenciales de servicios) de forma segura, versionable junto al resto del código de infraestructura (Terraform, Ansible), y operable por Semaphore en tiempo de ejecución sin intervención manual.

Las opciones evaluadas:

1. **Doppler** — SaaS de gestión de secretos.
2. **Infisical** — plataforma de gestión de secretos, con opción self-hosted o SaaS.
3. **HashiCorp Vault (HCP Vault o self-hosted)** — sistema de gestión de secretos de grado empresarial.
4. **Ansible Vault** — cifrado nativo de Ansible para variables sensibles.
5. **SOPS + age** — herramienta de cifrado de archivos estructurados (YAML/JSON/ENV) usando claves asimétricas vía `age`.

Esta decisión está directamente alineada con la preferencia de fondo ya establecida en el proyecto: privacidad y control como propiedad técnica, no como garantía contractual de un tercero.

## Decision
Se usa **SOPS (Secrets OPerationS) cifrado con age** como mecanismo de gestión de secretos en el monorepo. Los archivos cifrados viven versionados en Git junto al código; la clave privada de age se distribuye fuera de banda y se inyecta en Semaphore como variable de entorno (`SOPS_AGE_KEY`).

## Alternatives Considered

### Doppler
- Rechazado: es SaaS-only, no existe opción self-hosted. Esto contradice directamente la decisión de fondo de no depender de infraestructura online de terceros para algo tan crítico como el acceso a secretos del homelab — si Doppler tiene un incidente, una caída, o cambia su modelo de negocio, la disponibilidad de los secretos del homelab queda fuera de mi control.
- Modelo de pricing por usuario/proyecto que no aporta valor proporcional para un solo operador.

### Infisical
- Mismo problema de fondo que Doppler en su modalidad SaaS. La opción self-hosted existe, pero introduce un servicio adicional con su propia base de datos, proceso de actualización, y superficie de mantenimiento — exactamente el tipo de "infraestructura online dependiente" que se busca evitar, solo que ahora bajo mi propia operación en vez de la de un tercero. El costo operacional no se justifica frente a SOPS, que no requiere ningún servicio corriendo.

### HashiCorp Vault (HCP o self-hosted)
- Rechazado por ser la opción de mayor curva de aprendizaje y mayor peso operacional de las cinco evaluadas. Vault resuelve problemas de secretos dinámicos, leasing, rotación automática, y políticas de acceso granulares a escala de organización — ninguno de los cuales es un requerimiento real en un homelab de un solo operador con un número acotado de secretos estáticos.
- Operar Vault self-hosted correctamente (unsealing, almacenamiento del unseal key, alta disponibilidad, políticas ACL) es un proyecto en sí mismo, desproporcionado al problema que se necesita resolver.
- HCP Vault (la variante administrada) vuelve a introducir la dependencia de SaaS de terceros que ya se descartó en Doppler.

### Ansible Vault
- Opción más cercana en simplicidad a SOPS, y nativa del propio ecosistema Ansible ya en uso.
- Rechazado frente a SOPS por dos razones: (1) Ansible Vault cifra el archivo completo como blob opaco, mientras que SOPS cifra solo los *valores* dejando las claves/estructura legibles en texto plano dentro del repo — esto permite hacer diff y review legibles en Git sin necesidad de descifrar. (2) Ansible Vault está acoplado a Ansible; SOPS es agnóstico a la herramienta y cifra YAML/JSON/ENV por igual, lo cual es relevante porque el monorepo usa tanto Terraform como Ansible, y ambos necesitan consumir los mismos secretos sin duplicar el mecanismo de cifrado.

### SOPS + age (elegido)
- Cero infraestructura adicional: no hay servicio que levantar, ni unseal, ni proceso en background. El cifrado/descifrado ocurre client-side con la clave de age.
- Archivos cifrados versionables en Git con diffs legibles (estructura/claves en texto plano, solo los valores cifrados).
- age es deliberadamente minimalista (sucesor moderno de PGP, sin el legacy de formatos y opciones de PGP), lo que reduce superficie de error de configuración.
- Funciona igual de bien para variables de Ansible que para `.tfvars` de Terraform — un solo mecanismo para todo el monorepo.
- Curva de aprendizaje baja: la clave privada de age vive fuera de banda (no en Git) y se inyecta en Semaphore como secreto en un Variable Group; no hay UI ni API que aprender más allá de la CLI de `sops`.

## Consequences
- (+) Cero dependencia de infraestructura online de terceros para acceder a secretos — alineado con la postura de privacidad como propiedad técnica.
- (+) Sin costo recurrente ni límites de plan.
- (+) Diffs de Git legibles y revisables sin descifrar.
- (+) Un solo mecanismo de cifrado para Terraform y Ansible.
- (-) Sin rotación automática de secretos ni leasing dinámico — aceptable porque el volumen y la tasa de cambio de secretos en el homelab es baja y manejable manualmente.
- (-) La pérdida de la clave privada de age sin backup implica pérdida total de acceso a los secretos cifrados — mitigación: backup de la clave privada fuera del repo, en almacenamiento separado (ya cubierto por Vaultwarden/proceso de backup personal).
- (-) Sin UI de gestión — se opera 100% vía CLI/Git, lo cual es aceptable para un solo operador pero no escalaría a un equipo grande sin convenciones adicionales.

## Related
- Variable Groups de Semaphore (`SOPS_AGE_KEY`, `PROXMOX_VE_API_TOKEN`) como mecanismo de inyección en tiempo de ejecución.

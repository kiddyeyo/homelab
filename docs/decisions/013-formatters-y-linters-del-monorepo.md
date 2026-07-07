# ADR-013: Stack de formatters y linters para el monorepo

!!! success "Aceptada · 2026-06-23"

## Contexto

El monorepo de IaC del homelab mezcla varios lenguajes y formatos en el mismo árbol de archivos: Terraform (`bpg/proxmox`), Ansible (playbooks y roles con expresiones Jinja2), Docker Compose, y un conjunto de archivos YAML "huérfanos" — configuraciones de aplicación montadas como volúmenes de contenedor (Homepage, Traefik static/dynamic, Immich hwaccel, Dozzle users) que no pertenecen a ningún playbook ni manifiesto de Compose, y que por lo tanto no son cubiertos por ningún linter/formatter específico de los otros stacks.

Antes de esta decisión no existía un criterio explícito para:

1. Qué herramienta corre sobre qué tipo de archivo.
2. En qué etapa del pipeline corre cada herramienta (pre-commit local vía Lefthook, vs. Makefile manual, vs. CI).
3. Si los formatters con autofix (`terraform fmt`, `prettier --write`) deben poder modificar archivos automáticamente dentro de un hook de git, o si esa modificación debe ser siempre una acción explícita del operador.

El criterio de clasificación adoptado para resolver el punto 2 fue: ¿el check necesita red/credenciales? → si sí, vive solo en CI. ¿Es rápido y offline? → si sí, vive en pre-commit. Para el punto 3, el criterio fue: los checks read-only (`-check`, `validate`, `lint`) son seguros para correr de forma automática en un hook porque solo reportan; los formatters con autofix modifican el archivo en disco y, si corren dentro del hook sin que el operador lo pida explícitamente, generan dos problemas: (a) el diff que termina en el commit no es el que el operador escribió a mano, y (b) el archivo en disco puede dejar de coincidir con lo que estaba *staged*, mezclando "lo que se comiteó" con "lo que quedó en el working directory".

Sobre los YAML huérfanos específicamente: se evaluó si `prettier` podía aplicarse de forma generalizada a *todos* los YAML del repo (incluyendo Ansible y Compose) para evitarse mantener reglas de estilo distintas por tipo de archivo. Se determinó que no es seguro hacerlo, por dos riesgos concretos:

- **Docker Compose**: usa YAML anchors/aliases (`<<: *default`) cuya re-serialización por un formatter genérico puede alterar la estructura de referencias.
- **Ansible**: usa expresiones Jinja2 embebidas en strings YAML (`"{{ var }}"`), que un formatter no consciente de Jinja2 puede romper al normalizar comillas o espaciado.

Ningún otro validador del pipeline cubre los YAML huérfanos de aplicación, lo que dejaba esos archivos sin ningún tipo de chequeo de sintaxis o estilo.

## Decisión

Se adopta el siguiente stack, diferenciado por tipo de archivo y con una separación estricta entre check (automático, en hook) y autofix (manual, solo por comando explícito):

**Check (read-only, corre en pre-commit vía Lefthook y se espeja en CI):**
- `terraform fmt -check -diff -recursive` — estilo de código Terraform.
- `terraform validate` — validez sintáctica y de esquema de providers.
- `ansible-lint` (config propia `.ansible-lint`) — reglas de Ansible, consciente de Jinja2.
- `docker compose config` — validación de sintaxis y resolución de anchors de cada `docker-compose.yml`.
- `yamllint` (config propia `.yamllint.yml`) — sintaxis y estilo de los YAML huérfanos de configuración de aplicación.
- `check-sops-encrypted` (hook custom ya existente) — verifica que los archivos marcados como secretos estén cifrados antes de commitear.

**Autofix (exclusivamente manual, vía Makefile, nunca en un hook):**
- `terraform fmt -recursive` — reescribe el estilo de los `.tf`.
- `prettier --write` (config propia `.prettierrc.json`) — aplica **únicamente** sobre los YAML huérfanos de configuración de aplicación (Homepage, Traefik static/dynamic, Immich hwaccel, Dozzle users). No se aplica a `docker-compose.yml` ni a playbooks/roles de Ansible, por los riesgos de anchors y Jinja2 descritos en Context.

Targets resultantes:

```
make fmt   → terraform fmt + prettier (solo YAML huérfanos)
make lint  → terraform fmt -check, terraform validate, ansible-lint,
             docker compose config, yamllint
git commit → Lefthook corre exactamente lo de "make lint", nunca "make fmt"
```

`yamllint` se configura para excluir o relajar las rutas donde `prettier` ya es la fuente de verdad de estilo, evitando que ambas herramientas reporten conflictos de formato sobre el mismo archivo.

Checkov y Trivy (escaneo de seguridad/compliance) quedan explícitamente fuera de alcance de esta decisión — atienden un objetivo distinto (seguridad, no prevención de fallos de CI) y se evaluarán en un ADR separado si se adoptan.

## Alternativas consideradas

- **`pre-commit` (framework Python de pre-commit.com)**: descartado. El operador ya usa Lefthook (binario Go, sin dependencia de runtime Python) y no hay justificación para migrar o mantener dos sistemas de hooks en paralelo.
- **Aplicar `prettier --write` a todos los YAML del repo indiscriminadamente**: descartado por el riesgo concreto sobre anchors de Compose y expresiones Jinja2 de Ansible detallado en Context.
- **Incluir `terraform fmt` (sin `-check`) y `prettier --write` dentro del hook de pre-commit**: descartado. Permitir que un hook modifique archivos en silencio rompe la garantía de que el commit refleja exactamente lo que el operador escribió y revisó.
- **`ansible-lint --fix=all` de forma automática**: descartado del flujo automático por el mismo principio — el autofix de Ansible-lint puede alterar comportamiento de un playbook, no solo estilo, así que requiere revisión humana del diff antes de commitear.

## Consecuencias

- (+) Separación clara entre "esto solo te avisa" (pre-commit/CI) y "esto modifica tu código" (Makefile manual) — el operador mantiene control total de cada cambio que entra al historial de git.
- (+) Los YAML huérfanos de configuración de aplicación quedan cubiertos por sintaxis (`yamllint`) y estilo (`prettier`) sin arriesgar los archivos que usan features YAML avanzadas (anchors) o templating (Jinja2).
- (+) Paridad entre lo que corre localmente (Lefthook) y lo que corre en CI — mismo comando (`make lint`), sin desincronización de reglas.
- (-) Mantener tres configs de linter distintas (`.yamllint.yml`, `.ansible-lint`, `.prettierrc.json`) añade superficie de mantenimiento — mitigado porque cada una vive en la raíz del repo y se versiona junto con el código que valida.
- (-) El operador debe correr `make fmt` manualmente y revisar el diff antes de cada commit con cambios de estilo — es un paso extra comparado con un autofix silencioso, pero es el trade-off explícito aceptado para mantener el principio de "ningún cambio entra a git sin ser visto".

## Relacionado

- ADR-001 (Docker sobre Kubernetes/baremetal — contexto de por qué hay Compose en el repo)
- ADR-009 (break-glass path — independiente de este ADR pero parte del mismo monorepo de IaC)
- ADR-014 (estrategia de pinning de versiones para `uv`/`pnpm`, herramientas que gestionan estos mismos formatters/linters)

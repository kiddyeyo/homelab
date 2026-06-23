# ADR-014: Estrategia de pinning de versiones con uv (Python) y pnpm (Node.js)

## Status
Accepted

## Context

El monorepo de IaC mezcla dos ecosistemas de tooling con necesidades de reproducibilidad: Python (Ansible, Ansible-lint, yamllint, mkdocs — ver ADR-013) y Node.js (Prettier, usado como autofix sobre los YAML huérfanos — ver ADR-013). Ambos ecosistemas necesitan que cualquier clon del repo — el self-hosted GitHub Actions runner, la máquina Kubuntu del operador, o cualquier otra persona que clone el monorepo — obtenga exactamente la misma versión de cada herramienta, sin instalación manual fuera del repo y sin depender de "lo último disponible" en el momento de instalar.

Antes de esta decisión, parte del tooling Python vivía como `uv tool` (instalación global, equivalente conceptual a `pipx`) — `ansible-core`, `ansible-lint`, `lefthook`, `mkdocs`, `yamllint` — lo cual no es versionable a nivel de repositorio: `uv tool` no genera un lockfile único que trackee el conjunto completo de herramientas, cada tool es independiente y no comparte árbol de resolución de dependencias. Esto significa que la versión instalada depende de cuándo y en qué máquina se ejecutó `uv tool install`, no de un estado declarado en Git.

En paralelo, surgió la necesidad de instalar Prettier (Node.js) con el mismo estándar de reproducibilidad. Se evaluaron alternativas a `npm` como gestor de paquetes — pnpm, Bun, Yarn Berry — buscando el equivalente conceptual más cercano a `uv` en el ecosistema Node. pnpm fue identificado como el más cercano por su store global de contenido direccionable, deduplicación vía hard-links, y compatibilidad "drop-in" con los comandos de `npm` — sin requerir adoptar un runtime nuevo, a diferencia de Bun.

Un punto de confusión inicial fue tratar "instalación global" y "version locking en el repo" como el mismo objetivo: son objetivos que se contradicen entre sí. Una instalación global vive fuera de cualquier proyecto (en `$HOME` o una ruta de sistema) y no tiene relación con ningún `pyproject.toml`/`package.json` ni lockfile de un repo específico — si el operador instala una herramienta global y luego clona el repo en otra máquina o en CI, esa máquina no tiene la herramienta salvo que también se instale manualmente, que es exactamente lo que se busca evitar.

## Decision

Se fija como estándar: **toda herramienta de tooling cuya versión debe ser reproducible vive como dependencia declarada a nivel de proyecto, fijada en un lockfile commiteado al repo — nunca como instalación global suelta.** La instalación global solo se permite para el gestor de paquetes en sí (`uv`, `pnpm`), que es la herramienta de gestión, no el paquete gestionado.

**Python — `uv project` (`pyproject.toml` + `uv.lock`):**

```bash
uv init
uv add ansible-core==2.21.0 ansible-lint==26.4.0 yamllint==1.38.0 mkdocs==1.6.1
```

- `pyproject.toml` declara los constraints de versión.
- `uv.lock` contiene la resolución exacta, con hashes, multiplataforma.
- Ambos archivos se commitean al repo.
- Toda invocación se hace vía `uv run` (`uv run ansible-playbook`, `uv run ansible-lint`, `uv run yamllint`, `uv run mkdocs serve`), nunca contra un binario instalado globalmente.
- Reproducibilidad estricta en CI vía `uv sync --locked`, que falla si el lockfile está desincronizado del `pyproject.toml` en vez de regenerarlo en silencio.
- Actualizaciones de versión son deliberadas y puntuales, nunca masivas: `uv lock --upgrade-package <paquete>` para un bump a la vez, con su propio commit — nunca `uv lock --upgrade` salvo decisión explícita de actualizar todo el set junto.
- `lefthook` se queda como `uv tool` (instalación global) porque no es un paquete Python — es el binario del gestor de hooks, equivalente en rol a `uv`/`pnpm` mismos, no a una dependencia del proyecto.

**Node.js — `pnpm` (`package.json` + `pnpm-lock.yaml`):**

```bash
# una sola vez por máquina, instalación global del gestor
curl -fsSL https://get.pnpm.io/install.sh | sh -

# dentro del repo
pnpm init
pnpm add -D prettier
```

- `package.json` declara Prettier como `devDependency`.
- `pnpm-lock.yaml` fija la versión exacta con hash de integridad — es este archivo el que da reproducibilidad real, no `package.json` por sí solo (que puede declarar un rango con `^`).
- Invocación vía `pnpm exec prettier` (equivalente a `npx` pero apuntando siempre a la versión fijada en el lockfile, nunca a una descarga ad-hoc del registry) o vía script declarado en `package.json` (`pnpm run format`).
- `node_modules/` nunca se commitea — va en `.gitignore`.
- El self-hosted runner de CI solo necesita `pnpm install` (lee el lockfile) antes de `pnpm exec prettier --check .`, obteniendo exactamente la misma versión usada localmente.

**Qué se commitea al repo, resumen:**

```
pyproject.toml      ← constraints Python
uv.lock              ← resolución exacta Python, CON hashes
package.json         ← constraints Node.js (Prettier)
pnpm-lock.yaml       ← resolución exacta Node.js, CON hash de integridad
.gitignore           ← excluye node_modules/, .venv/, collections/
```

## Alternatives Considered

- **Mantener el tooling Python como `uv tool` global**: descartado. No genera un lockfile único versionable; la reproducibilidad depende de memoria/documentación externa de qué versión se instaló cuándo, no de un estado declarado en Git.
- **Bun como gestor de paquetes Node.js**: descartado para este caso de uso. Es más rápido que pnpm, pero implica adoptar un runtime completo nuevo — una decisión arquitectónica de mayor alcance que simplemente "gestionar la versión de Prettier", desproporcionada para el problema concreto que se resuelve aquí.
- **Yarn Berry**: no evaluado a profundidad; pnpm cubre el mismo objetivo (deduplicación, velocidad, compatibilidad con comandos de `npm`) sin introducir un formato de lockfile propietario adicional al ya elegido para Python.
- **`npx` para invocar Prettier sin instalación de proyecto**: descartado. `npx` ejecuta sin persistir versión fijada — cada invocación puede resolver una versión distinta del registry si no hay caché local, rompiendo la garantía de reproducibilidad que ya se exige a Terraform (`required_version`, provider pin) y a Ansible (collections vía `requirements.yml`).
- **Instalación global de Prettier (`npm install -g prettier` o equivalente con pnpm)**: descartado. Resuelve "tenerlo a mano" pero no resuelve reproducibilidad — cualquier otra máquina (incluido el runner de CI) necesitaría repetir la instalación manual, y no hay garantía de que resuelva la misma versión.

## Consequences

- (+) Mismo principio de pinning aplicado de forma consistente en los tres ecosistemas del monorepo: Terraform (`required_version` + versión de provider, ver ADRs previos), Python (`uv.lock`), y Node.js (`pnpm-lock.yaml`) — sin un cuarto patrón distinto por lenguaje. Ningún ecosistema depende de "lo que esté instalado en la máquina del operador" para resolver una versión.
- (+) El self-hosted GitHub Actions runner reproduce exactamente el mismo entorno que la máquina local del operador con un solo comando por ecosistema (`uv sync --locked`, `pnpm install`).
- (+) Actualizaciones de versión quedan trazadas en el historial de Git como commits individuales y deliberados, en vez de drift silencioso por reinstalaciones manuales en distintas máquinas.
- (-) Duplica temporalmente algunas herramientas durante la transición desde `uv tool` global hacia `uv project` (por ejemplo, `ansible-core` puede existir simultáneamente como tool global v2.21.0 y como dependencia de proyecto v2.21.1) — mitigado desinstalando los `uv tool` redundantes una vez migrado todo el tooling Python al proyecto (`uv tool uninstall ansible-core ansible-lint mkdocs yamllint`).
- (-) Introduce un segundo lockfile y gestor (`pnpm` además de `uv`) exclusivamente para Prettier — aceptado porque Prettier no tiene equivalente funcional maduro en el ecosistema Python, y el costo de mantener un `package.json` mínimo es bajo frente al beneficio de reproducibilidad.
- (-) Bumps de versión en `uv.lock` requieren disciplina manual (`--upgrade-package` puntual en vez de `--upgrade` masivo) para no mezclar varios cambios de versión difíciles de revertir en un solo commit — es un proceso, no algo que la herramienta fuerce por sí sola.

## Related

- ADR-013 (stack de formatters y linters — define qué herramientas necesitan pinning bajo este ADR)
- ADR-007 (Terraform backend compartido — mismo principio de reproducibilidad aplicado a `tfstate`)

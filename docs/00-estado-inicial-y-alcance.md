# LTSB — Estado inicial, alcance y discrepancias detectadas

Fecha de la fase de investigación: 2026-10-01.

## 0. Ruta de trabajo (confirmada)

Ruta real confirmada por inspección del sistema de archivos:

- `D:\Users\Darkness\Documents\F22\LTSB` — directorio de trabajo y raíz del repositorio.
- `F:` **no existe**. Las unidades montadas en el host son `C:`, `D:`, `S:`, `X:`.
- Al inicio, la raíz del repositorio contenía **únicamente** un repositorio git vacío
  (rama `master`, sin commits, sin remoto configurado). No había proyecto previo que inspeccionar.

**Nota de nomenclatura.** El nombre del proyecto es **LTSB** (Windows 10 LTSB 2016, build 14393).
Las apariciones históricas de `LTCB` en la documentación y en `scripts/validar.sh` eran errores
de transcripción y fueron corregidas. No existe una segunda nomenclatura ni una migración pendiente.

**Excepción conocida:** el directorio del plan persistente se llama
`.planning/2026-10-01-ltcb-lab-remoto-windows10/`. Es un identificador interno creado por la
herramienta de planning, no documentación visible. Se mantiene sin renombrar para no invalidar
`.planning/.active_plan` ni la atestación de integridad; su contenido usa exclusivamente `LTSB`.

## 1. Herramientas disponibles en el host de trabajo

| Herramienta | Estado |
|---|---|
| `git` | 2.53.0.windows.1 — presente |
| `python` | 3.12.7 — presente |
| `gh` (GitHub CLI) | **ausente** |
| `docker` | **ausente** |
| `qemu-system-x86_64` / `qemu-img` | **ausentes** |
| Credenciales de GitHub | **ninguna detectada** |

No hay forma local de autenticarse contra la API de GitHub sin intervención del usuario
(ver `docs/05-control-por-agente.md`, sección de autenticación).

## 2. Alcance de esta fase

**Hecho:** investigación documental, verificación de capacidades del runner, y diseño de la
arquitectura del laboratorio. Estructura de proyecto creada. Workflow de sondeo redactado.

**No hecho (fuera de autorización explícita):**

- Ninguna ejecución en GitHub Actions.
- Ninguna descarga de ISO.
- Ninguna creación de VM ni imagen de disco.
- Ninguna modificación de `explorer.exe`, `uxtheme.dll`, registro, ni de ninguna instalación real.
- Ningún gasto, ningún método de pago, ninguna API de pago.

## 3. Objetivos de investigación y su estado

| # | Objetivo | Estado al cierre de esta fase |
|---|---|---|
| 1 | ¿GitHub Actions sirve gratis para este propósito? | **Resuelto** — sí, con condiciones. Ver `01-arquitectura-y-viabilidad.md` |
| 2 | Capacidades exactas del runner Windows | **Resuelto** — documentado, con hallazgo decisivo |
| 3 | ¿Arrancar VM Windows 10 14393 con QEMU en el runner? | **Hipótesis original descartada**; arquitectura corregida a Linux+KVM |
| 4 | Automatización sin intervención humana | **Diseñado**, no ejecutado |
| 5 | Reproducibilidad | **Diseñado**, no ejecutado |
| 6 | Control del ciclo experimental por OpenCode | **Diseñado**, bloqueado en autenticación |
| 7 | Dark mode en Explorer de 14393 | **Investigado** — no hay soporte nativo; hay vía temática |
| 8 | Store / AppX / MSIX en 14393 | **Investigado** — MSIX Core es la única vía oficial y casi ninguna app moderna califica |

## 4. Reglas metodológicas adoptadas

Cada afirmación en `docs/` lleva una de estas etiquetas:

- `[OFICIAL]` — documentación de GitHub, Microsoft o el proyecto upstream, con URL.
- `[COMUNIDAD]` — reporte de terceros, foro, issue, blog. Verificable pero no-normativo.
- `[HIPÓTESIS]` — inferencia propia, aún sin ejecución que la respalde.

Ninguna afirmación se declara verificada sin URL o sin log de ejecución. Lo no encontrado se
marca `[NO ENCONTRADO]` en lugar de omitirse.

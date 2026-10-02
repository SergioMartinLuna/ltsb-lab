# 01 — Arquitectura propuesta y veredicto de viabilidad

## Veredicto en una línea

**Todavía no hay veredicto.** La investigación de este documento llevó a la conclusión de que la
vía correcta era **QEMU + KVM en un runner `ubuntu-latest`**. Esa conclusión era una inferencia
razonada a partir de documentación, no una medición, y este documento la enunciaba con una
confianza que no tenía. Lo que ahora se hace es **medirlo antes de construir nada**: ver
[`docs/02`](02-experimento-000-sonda.md).

Dos cosas que este documento daba por resueltas y no lo estaban:

- Que en un runner Windows solo hay TCG. La virtualización anidada es **técnicamente posible** en
  Windows Server 2025; GitHub la declara no soportada, lo cual significa "sin garantía", no
  "imposible". Nadie lo ha probado en un runner.
- Que por eso hay que usar Linux. Deriva de lo anterior.

El experimento 000 mide las dos cosas en el runner Windows, que es el que importa: el objetivo es
una VM de Windows, no de Linux. Si WHPX funciona, la arquitectura original se recupera. Si no,
la conclusión de Linux se sostiene y se pone a prueba después.

**Restricción que no depende del runner y que ninguna arquitectura puede esquivar:** el runner
público tiene **14 GB de SSD**. Una instalación de Windows 10 14393 no cabe, ni bajo KVM ni bajo
TCG, ni en Windows ni en Linux. Ese techo es el problema real de este laboratorio, y es anterior
a cualquier decisión sobre aceleración.

---

## 0. Cómo leer este documento

El texto se conserva tal como se escribió, con sus etiquetas `[OFICIAL]`, `[COMUNIDAD]` y
`[HIPÓTESIS]`, porque el trabajo de investigación sigue siendo válido. Lo que se corrige es el
**estatus** de sus conclusiones: son hipótesis que EXP-000 va a poner a prueba, no hechos
establecidos.

Donde el documento afirma algo que depende del runner sin haberlo medido, está marcado con
`[POR MEDIR]`.

---

## 1. Pregunta 1 — ¿GitHub Actions es utilizable gratis?

### `[OFICIAL]` Sí, si el repositorio es público

Runners estándar de GitHub-hosted son **gratis e ilimitados en repositorios públicos**.

> "Use of standard GitHub-hosted runners is free: In public repositories, For GitHub Pages, For
> Dependabot" — https://docs.github.com/en/billing/managing-billing-for-github-actions/about-billing-for-github-actions

Y explícitamente: *"GitHub Actions will remain free for public repositories. In 2025, we saw
developers use 11.5 billion total Actions minutes in public projects for free (~$184 million)"*
— https://github.com/resources/insights/2026-pricing-changes-for-github-actions

### `[OFICIAL]` Si es privado, hay cuota mensual (plan Free)

| Plan | Artifact storage | Minutos/mes | Cache por repo |
|---|---|---|---|
| GitHub Free | **500 MB** | **2.000** | 10 GB |
| GitHub Pro | 1 GB | 3.000 | 10 GB |

Fuente: https://docs.github.com/en/actions/reference/limits

**Consecuencia práctica para LTSB:** 500 MB de artifacts es insuficiente para una imagen de disco de
Windows 10 (mín. ~7 GB comprimida, ver §4). Por eso el diseño de §5 usa **GitHub Releases**, que no
tiene ese límite.

### `[OFICIAL]` Límites de tiempo y concurrencia

| Límite | Valor |
|---|---|
| Duración máxima de job (GitHub-hosted) | **6 horas** |
| Jobs concurrentes, plan Free | 20 |
| Runner `ubuntu-slim` (1 CPU) | timeout de **15 minutos**, no sirve |

Fuente: https://docs.github.com/en/actions/reference/limits

El límite de 6 h es la restricción que descarta la instalación completa en cada corrida
(ver §3).

### `[OFICIAL]` Restricción relevante de 2026

A partir del **1 de marzo de 2026** los runners self-hosted consumen la cuota de minutos gratuitados
del plan. Los runners estándar en repos públicos siguen sin costo.

Fuente: https://github.com/resources/insights/2026-pricing-changes-for-github-actions

Esto importa solo si más adelante se evaluúa un runner propio. En la arquitectura propuesta no se usa.

---

## 2. Pregunta 2 — Capacidades del runner Windows (la pregunta que cambia el diseño)

### `[OFICIAL]` Especificación publicada

Runner Windows x64 en repositorio **público**: **4 vCPU, 16 GB RAM, 14 GB SSD garantizados**.
En repositorio **privado**: 2 vCPU, 8 GB RAM, 14 GB.

Fuente: https://docs.github.com/en/actions/reference/runners/github-hosted-runners

Notas relevantes de la misma página:

- **OS real = Windows Server**, no Windows 10. Hoy `windows-latest` = Windows Server 2025
  (build 26100). `windows-2022` = build 20348. `[OFICIAL]`
  https://github.com/actions/runner-images/blob/main/images/windows/Windows2025-Readme.md
- **Privilegios**: *"Windows virtual machines are configured to run as administrators with User
  Account Control (UAC) disabled."* `[OFICIAL]` — admin sin UAC.
- La imagen `Windows2022` declara explícitamente: **"Windows features: Windows Subsystem for Linux
  (WSLv1): Enabled"**. `[OFICIAL]` Solo WSL1. La ausencia de WSL2 es la pista: WSL2 requiere
  virtualización anidada, y no está.
- **Red**: salida a internet abierta, sin ICMP de entrada (los runners están en Azure).
  Hosts requeridos: `github.com`, `api.github.com`, `*.actions.githubusercontent.com`,
  `*.blob.core.windows.net`, `release-assets.githubusercontent.com`, entre otros.

### `[OFICIAL]` Nested virtualization: no soportada en runners estándar

> "While nested virtualization is technically possible while using runners, it is not officially
> supported. Any use of nested VMs is experimental and done at your own risk, we offer no
> guarantees regarding stability, performance, or compatibility."
> — https://docs.github.com/en/actions/concepts/runners/github-hosted-runners

Y en la discussion oficial `actions/runner-images#9285`, un miembro del equipo de GitHub:

> "it is enabled :) and is available on larger hosted runners but not on the standard ones yet"
> — https://github.com/actions/runner-images/discussions/9285

Traducción operativa: **`-accel whpx` no es una opción en `windows-2022`/`windows-2025` estándar.**

### `[COMUNIDAD]` Consecuencia medida: el runner Windows cae a emulación pura

Third-party (WarpBuild, re-revisado 2026-08-13) documenta explícitamente que nested virtualization
está disponible en su clase **Linux x86-64** y **no** en Windows, macOS ni ARM64:

| Clase de runner | Nested virtualization |
|---|---|
| Linux x86-64 | **Sí** |
| Linux ARM64 | No |
| **Windows** | **No** |
| macOS | No |

https://www.warpbuild.com/runners/nested-virtualization

Sin WHPX, QEMU en Windows cae a **TCG** (emulación de instrucciones en software).

### `[COMUNIDAD]` El coste medido de TCG para instalar Windows 10

Un repositorio que publica benchmarks de build de imágenes Windows 10 con QEMU **sin Hyper-V**
(TCG) en hardware decente (i7-10700K / 32 GB / NVMe):

| Configuración | Tiempo de build | Tamaño final | Boot |
|---|---|---|---|
| Mínima (4 GB RAM, 2 CPU) | **~4,5 horas** | ~12 GB | ~45 s |
| Estándar (8 GB RAM, 4 CPU) | ~3,0 horas | ~15 GB | ~30 s |
| Alto rendimiento (16 GB, 8 CPU) | ~2,0 horas | ~18 GB | ~25 s |

https://github.com/saifyxpro/windows10-custom-image-builder

**Esto es en hardware local de escritorio.** En un runner de 4 vCPU con almacenamiento limitado, y
sumado al límite duro de **6 horas por job**, instalar Windows 10 en cada corrida no es viable.

### `[COMUNIDAD]` El storage garantizado de 14 GB es un problema real

GitHub garantiza 14 GB. La realidad observada en `windows-2025` tras un cambio de imagen fue de
**~33 GB en C:**, y el propio personal de GitHub cerró el issue como *"not-a-bug, as it follows the
pledge"* (los 14 GB comprometidos).

- Issue `actions/runner-images#12609` — https://github.com/actions/runner-images/issues/12609
- El issue `#12416` documenta que `D:` (147 GB) se eliminó de `windows-2025` el 2025-07-14 y se
  restauró el 2025-08-18. Inestabilidad real del entorno de disco.
  https://github.com/actions/runner-images/issues/12744

Windows 10 instalado ocupa **20 GB** como mínimo declarado por el propio medio de Microsoft
(archive.org metadata: *"Disk space: 16 Gb of free space (32-bit) or 20 Gb (64-bit)"*).
14 GB garantizados no alcanzan, y ni siquiera los ~33 GB reales dejan margen cómodo.

### Conclusión de la Pregunta 2

> `[POR MEDIR]` Esta tabla se escribió antes de tener datos de un runner Windows. Las celdas de
> aceleración y de la última fila son hipótesis, no mediciones. EXP-000 las somete a prueba.

| Capacidad | Runner Windows estándar | Runner Linux x64 estándar |
|---|---|---|
| Aceleración de VM | `[POR MEDIR]` se asume TCG; WHPX sin verificar | ✅ **KVM** `[OFICIAL]` changelog 2024-04-02 |
| 4 vCPU / 16 GB RAM | ✅ | ✅ |
| Espacio garantizado | 14 GB | 14 GB (más si se limpia la imagen) |
| Timeout de job | 6 h | 6 h |
| SO del host | Windows Server 2022/2025 | Ubuntu 24.04/26.04 |
| Instalación de Windows 10 por job | ❌ no cabe: 14 GB de disco | ❌ no cabe: 14 GB de disco |

La última fila cambió: la instalación de 14393 no cabe en ninguno de los dos runners, por
disco, no por aceleración. La aceleración decide si una VM ya construida arranca rápido o painful;
no decide si se puede construir.

---

## 3. Pregunta 3 — ¿Se puede arrancar Windows 10 14393 con QEMU?

### `[OFICIAL]` Sí, KVM está disponible en runners Linux x64

El changelog de GitHub del **2 de abril de 2024** declara aceleración por hardware en runners Linux:

> "Actions users of our 2-vCPU GitHub-hosted Linux runners will be able to make use of hardware
> acceleration for Android testing. Previously this feature was only available on runners with 4 or
> more vCPUs."
> — https://github.blog/changelog/2024-04-02-github-actions-hardware-accelerated-android-virtualization-now-available/

El paso que exige es solo dar permisos al device node:

```bash
echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=1"' \
  | sudo tee /etc/udev/rules.d/99-kvm4all.rules
sudo udevadm control --reload-rules
sudo udevadm trigger --name-match=kvm
```

### `[COMUNIDAD]` Precedente real y directamente reutilizable: build completo de Windows en Actions

`cocoonstack/windows` construye una imagen Windows 11 qcow2 **dentro de `ubuntu-latest`** con
`-accel kvm`, en un solo job, y publica el resultado. Es el patrón exacto que LTSB necesita, con
Windows 10 14393 en lugar de Windows 11.

https://github.com/cocoonstack/windows/blob/551ab34a3/.github/workflows/build.yml

Detalles relevantes de ese workflow, con el porqué de cada decisión:

- **Libera ~30 GiB** de SDKs preinstalados antes de empezar (`/usr/share/dotnet`, `/opt/ghc`,
  `/usr/local/lib/android`, `/opt/hostedtoolcache/CodeQL`, …). Sin esto, 14 GB no alcanzan para
  ISO + ISO repack + virtio-win + qcow2 en crecimiento.
- **Repackea el ISO** para inyectar `autounattend.xml` en la raíz y `efisys_noprompt.bin` como
  boot loader EFI. Motivo: el bootloader EFI de Windows espera una tecla y bloquearía el job.
- **KVM + enlightenments de Hyper-V**: `-cpu host,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time`.
  Sin ellos Windows no toma sus rutas rápidas dentro del guest.
- **Snapshot de QMP** sobre la consola serie y detección de stalls por tamaño de qcow2.
- **Comprime y trocea**: `qemu-img convert -c` y `split -b 1900M` para los límites de GitHub.
- reportedly ~2 h de job.

Otro precedente independiente: `tikoci/restraml` arranca una VM RouterOS CHR con QEMU en
`ubuntu-latest` y hace health-check por HTTP, con fallback explícito a TCG si no hay KVM.
https://github.com/tikoci/restraml/blob/main/.github/workflows/manual-using-docker-in-docker.yaml

### `[HIPÓTESIS]` Timeboxing de la instalación de 14393 (a confirmar con el experimento)

Windows 10 14393 es **más liviano** que Windows 11: no requiere TPM 2.0, ni Secure Boot, ni
`q35` estricto. Con BIOS (i440fx), disco IDE/AHCI y NIC `e1000e`, es el caso más simple posible de
QEMU+Windows. Estimación: **instalación en 30-60 min bajo KVM**, mucho menos que los ~2 h de
Windows 11 del precedente. Marcado `[HIPÓTESIS]` porque no hay medición propia todavía.

---

## 4. Pregunta 4 — Presupuesto de disco (por qué se publica en Releases y no en Artifacts)

| Artefacto | Tamaño aproximado |
|---|---|
| ISO Windows 10 14393 x64 | ~3,3 GB |
| ISO virtio-win | ~0,15 GB |
| qcow2 instalado (sin comprimir) | ~10-15 GB `[COMUNIDAD]` |
| qcow2 comprimido (`-c`) | ~5-8 GB `[COMUNIDAD]` |
| Overlay por experimento | cientos de MB – 1 GB |

`[OFICIAL]` Límites que aplican:

- **Artifacts**: 500 MB en plan Free. Insuficiente. → no usar para la imagen.
- **Releases**: *"Up to 1000 release assets may be associated with a single release. Each file
  included in a release must be under 2 GiB. There is no limit on the total size of a release, nor
  bandwidth usage."* — https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases
- **Repos bloquea pushes > 100 MiB** y advierte > 50 MiB. La ISO **no puede ir al repo**.

→ **Decisión: la imagen base y la ISO se distribuyen como release assets troceados en partes de
< 1,9 GiB, con SHA256SUMS.** Es exactamente lo que hace `cocoonstack`, y es gratis en repo público.

---

## 5. Arquitectura propuesta

```
┌───────────────────────────────────────────────────────────────────┐
│  OpenCode (agente, máquina del usuario)                            │
│  - redacta experimento (YAML/JSON)                                │
│  - dispara workflow (gh workflow run)                             │
│  - lee artifacts + logs, decide siguiente experimento             │
└───────────────┬───────────────────────────────────────────────────┘
                │  GitHub REST API (requiere PAT — ver doc 05)
                ▼
┌───────────────────────────────────────────────────────────────────┐
│  Repositorio público LTSB                                          │
│  ┌────────────────────┐        ┌──────────────────────────────┐    │
│  │ .github/workflows/ │        │  Release: imagen base 14393  │    │
│  │  00-sonda.yml      │        │  win10-14393.qcow2.NN.part   │    │
│  │  01-build-base.yml │        │  + SHA256SUMS               │    │
│  │  02-experimento.yml│        │  (sin límite de 2 GiB total) │    │
│  └────────────────────┘        └──────────────┬───────────────┘    │
└────────────────────────────────────────────────┼──────────────────┘
                                                 │ descarga
┌────────────────────────────────────────────────▼──────────────────┐
│  Job en ubuntu-latest  (4 vCPU, 16 GB, KVM)                       │
│                                                                   │
│  ┌─── A ─────────────────────────────────────────────────────┐     │
│  │ Sonda: capacidad real de KVM, espacio, red, timeouts      │     │
│  └──────────────────────────────────────────────────────────┘     │
│  ┌─── B ── (una vez, ~1 h) ──────────────────────────────────┐    │
│  │ Instala 14393 desatendida con autounattend.xml            │    │
│  │ OpenSSH + QEMU guest agent + pwsh  → snapshot             │    │
│  │ Comprime, trocea, publica release                        │    │
│  └──────────────────────────────────────────────────────────┘     │
│  ┌─── C ── (por experimento, ~20-40 min) ────────────────────┐   │
│  │ Descarga base → crea overlay qcow2 → boot → ejecuta       │   │
│  │ script .ps1 → captura stdout/stderr/eventos/screenshot    │   │
│  │ → publish overlay o diff como artifact → upload           │   │
│  └──────────────────────────────────────────────────────────┘     │
└───────────────────────────────────────────────────────────────────┘
```

### Decisiones de diseño y su justificación

| Decisión | Justificación | Evidencia |
|---|---|---|
| Runner `ubuntu-latest`, no `windows-*` | KVM disponible; en Windows solo TCG | `[OFICIAL]` changelog 2024-04-02 + `[COMUNIDAD]` WarpBuild |
| Imagen base publicada como Release, no artifact | 500 MB de límite vs ~5-8 GB de imagen | `[OFICIAL]` docs de límites y releases |
| Repo **público** | Minutos y artifacts ilimitados, releases sin límite | `[OFICIAL]` docs de billing |
| Overlay qcow2 por experimento | Estado inicial reproducible y desechable | `[COMUNIDAD]` `gha-outrunner` usa exactamente este patrón |
| ISO fuera del repo | GitHub bloquea > 100 MiB | `[OFICIAL]` docs de archivos grandes |
| ISO en secret o release privado | La ISO es software propietario de Microsoft | `[OFICIAL]` lifecycle docs |
| `autounattend.xml` inyectado en la ISO | Es la única vía de instalación 100 % desatendida | `[COMUNIDAD]` precedente `cocoonstack` |
| SSH como canal de control, no RDP | Automatizable, sin sesión gráfica interactiva | `[COMUNIDAD]` workflows de referencia |
| Captura de pantalla vía QMP `screendump` | Funciona headless, sin sesión interactiva | `[OFICIAL]` QEMU monitor docs |

---

## 6. Alternativas evaluadas y por qué se descartan

| Alternativa | Motivo del descarte |
|---|---|
| QEMU en `windows-2022` / `windows-2025` | Sin WHPX → TCG → 3-4,5 h por instalación, contra un techo de 6 h. Sin margen. |
| Hyper-V en runner Windows estándar | GitHub: "available on larger hosted runners but not on the standard ones". Larger runners **siempre se cobran**, incluso en repos públicos. |
| Instalar Windows 10 en cada job | Tono de §2/§3. Se paga el coste de instalación cada corrida. |
| Usar la máquina del usuario como host | Prohibido por el encargo. |
| Azure / AWS free tier | Requiere tarjeta de crédito. El encargo prohíbe APIs de pago e infraestructura de pago sin autorización. |
| GitHub Codespaces (120 h core/mes gratis) | Es un runner Linux. Solo cambia la interfaz, no añade KVM ni cambia el techo de 6 h. Podría ser un plan B para iterar rápido. |
| Docker / Windows containers | Los contenedores Windows en Linux no existen. La virtualización anidada en el runner es técnicamente posible pero **no soportada** por GitHub: eso significa "sin garantía", no "imposible". `[POR MEDIR]` |

---

## 7. Veredicto de viabilidad

**Pendiente.** No se puede declarar viable ni inviable antes de tener una medición del runner.
Lo único firme hasta ahora:

1. El costo cero depende de que el repositorio sea **público**. `[OFICIAL]`
2. El techo de **6 h por job** y **14 GB de SSD** en el runner estándar son datos oficiales y no
   se pueden negociar. `[OFICIAL]`
3. **Windows 10 14393 no se puede instalar dentro del runner**, ni en Windows ni en Linux: no cabe
   en 14 GB. Esto no es un problema de aceleración y no lo resuelve ninguna arquitectura de
   ejecución.
4. Por lo tanto, la pregunta relevante no es "¿cómo instalo 14393 en el runner?" sino
   "¿construyo `base.qcow2` **fuera** del runner y la publico como release?".

Lo que EXP-000 responde es la pregunta previa y más barata: **¿puede un runner Windows ejecutar
una VM con QEMU, y con qué aceleración?** Es un job de minutos que no toca Windows 14393, y su
resultado decide si la construcción fuera del runner tiene sentido hacerla en Windows, en Linux, o
en la máquina del usuario.

Nótese que los puntos 3 y 4 invalidan la premisa de la versión anterior de este documento, que
proponía construir la imagen base dentro del propio runner.

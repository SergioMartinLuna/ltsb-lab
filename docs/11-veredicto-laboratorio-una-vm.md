# Veredicto de laboratorio — UNA VM Windows 10 LTSB 2016 (14393) persistente y gratuita

Fecha: 2026-10-02. Fase: verificación documental y de capacidad. Sin ejecución, sin
instalación, sin autenticación, sin commit, sin push.

Supersede `docs/10-veredicto-de-plataforma.md`, que respondía al objetivo eliminado de dos
VMs simultáneas.

## VEREDICTO DE LABORATORIO

**Sí. GitHub Actions sobre repositorio público sostiene el laboratorio con UNA VM 14393
persistente a costo estrictamente cero.**

La restricción de simultaneidad que enterraba el diseño anterior desaparece. Queda **un solo
obstáculo**, y es de construcción, no de operación: el runner tiene `14 GB` de disco
`[OFICIAL]` y la instalación de 14393 necesita más. Ese obstáculo tiene dos salidas
gratuitas; una es viable, la otra requiere verificación.

---

## 1. Lo que realmente ocupa espacio

Un solo número importa ahora, porque todo lo demás entra:

| Magnitud | Valor | Etiqueta |
|---|---|---|
| Footprint instalado 14393, Compact OS + single-instancing | **10.09 GB** | `[OFICIAL]` tabla 1607 x64, 4 GB RAM |
| Footprint instalado 14393, normal | **15.06 GB** | `[OFICIAL]` misma tabla |
| **Base qcow2 comprimida en el runner** | **~6.66 GB** | `[EST]` (ratio ~0.66 sobre 10.09 GB) |
| Pico de construcción sin optimizar | ~24.36 GB | `[EST]` de `docs/09` |
| QEMU instalado vía apt | ~0.8–1 GB | `[EST]` |
| ISO 21H2 English x64 | 4.563 GB | `[COMUNIDAD]` archivo publicado por Microsoft |

Cuatro magnitudes distintas. Confundirlas es exactamente lo que produjo el error de
EXP-000.

## 2. Almacenamiento persistente: Releases elimina el techo de 10 GB

Este es el cambio decisivo respecto del análisis anterior.

| Fuente | Límite | Persistente | Costo |
|---|---|---|---|
| **Releases** | **sin límite total**; **2 GiB por archivo**; hasta 1000 assets; sin límite de ancho de banda | **sí, indefinido** | **no facturado** |
| Cache | 10 GB/repo; **eviction a los 7 días** sin acceso; excedente facturado a $0.07/GB/mes | 7 días | excedente facturado |
| Artifacts | 500 MB (plan Free) | retención limitada | — |
| Git LFS | 10 GiB storage + 10 GiB bandwidth; excedente facturado | sí | excedente facturado |
| Repositorio | solo código | sí | — |

`[OFICIAL]` Releases: *"Up to 1000 release assets may be associated with a single release.
Each file included in a release must be under 2 GiB. There is no limit on the total size of
a release, nor bandwidth usage."*

**Consecuencia:** el límite de 10 GB del Cache deja de ser el techo. Un qcow2 de 6.66 GB no
entra como un archivo, pero se **parte en 4 trozos de ~1.7 GB** y ambos se recombinan en el
runner. Los discos de la VM viven en Releases, versionados y con historial.

**Cache queda solo para cosas chicas** (QEMU instalado, herramientas) donde interesa la
descarga rápida, nunca para el disco de la VM.

## 3. Presupuesto de disco por job

El disco del runner es efímero y mide `14 GB` `[OFICIAL]`. Con una sola VM entra todo:

| Job | Contenido | Total | ¿Entra? |
|---|---|---|---|
| **A — experimentos** | base 6.66 + overlay 0.5–2 + QEMU 0.9 + evidencia 0.3 | **~10.4 GB** | **sí**, holgura ~3.6 GB |
| **B — fuente 21H2** | ISO 4.56 + extraídos <1 + herramientas 0.3 | **~5.9 GB** | **sí**, holgura ~8 GB |
| **C — construcción** | disco destino 12 + temp WinPE 1 + QEMU 0.9 | **~13.8 GB** | **al límite**, ver §5 |

La clave de que el job B no compita con el A es que son **jobs separados**: cada uno recibe
sus propios 14 GB. La ISO nunca convive con la VM en el mismo disco.

## 4. Arquitectura concreta

### Almacenamiento permanente (fuera del runner, fuera de Git)

```
Release "lab-assets-v1"
  ├─ base/14393-base-aa.b  1.7 GB  ┐
  ├─ base/14393-base-ab.b  1.7 GB  ├─ se recombinan → base-14393.qcow2 (6.66 GB)
  ├─ base/14393-base-ac.b  1.7 GB  │
  └─ base/14393-base-ad.b  1.66 GB ┘
  ├─ src21h2/explorer.exe, shell32.dll, ... (<1 GB)
  └─ states/<experimento>-overlay.qcow2   ← snapshots nombrados

Release "win21h2-iso"  (opcional, 3 trozos de 1.52 GB)
```

`states/` en Releases es lo que responde a *"volver a un estado anterior"*: cada overlay es
un estado experimentales congelado y recuperable por nombre.

### Ciclo de un experimento

```
1. POST /repos/{owner}/{repo}/actions/workflows/lab.yml/dispatches
   OpenCode dispara el job. No hay interacción humana.

2. actions/checkout → descargar los 4 trozos del Release → cat → base-14393.qcow2
   (sha256 verificado contra un manifiesto en el repo)

3. qemu-img create -f qcow2 -b base-14393.qcow2 -F qcow2 overlay.qcow2
   el overlay es el estado de trabajo; la base es solo lectura, nunca se toca

4. qemu-system-x86_64 -accel kvm -m 4096 -smp 2 \
     -drive file=overlay.qcow2,if=virtio \
     -drive file=shared-21h2/,if=virtfs,readonly=on \
     -netdev user,id=n0 -device virtio-net-pci,net=n0 \
     -qmp tcp:127.0.0.1:4444,server,nowait   ← control remoto por OpenCode

5. QMP + WinRM/RDP tunnel: ejecutar comandos, copiar archivos, instalar paquetes,
   reiniciar, capturar evidencia. OpenCode habla con el job por la API de GitHub
   y con la VM por QMP.

6. Guardar:
   - overlay si el estado es valioso → Release states/<exp>.qcow2 (chunk si >2 GiB)
   - evidencia (screenshots, logs, salida de comandos) → artifacts (500 MB alcanza)
   - veredicto del experimento → artifact + issue

7. Restaurar un estado anterior:
   - a la base limpia:  borrar overlay y recrearlo   (instantáneo)
   - a un estado guardado:  bajar states/<exp>.qcow2 de Releases
```

### Respuestas puntuales a lo pedido

| Pregunta | Respuesta |
|---|---|
| ¿Cuánto espacio necesitamos? | ~6.66 GB persistentes de VM + <1 GB de fuente 21H2 + overlays por experimento |
| ¿Cuánto podemos conservar? | **ilimitado** — Releases no tiene tope total `[OFICIAL]` |
| ¿Cómo se almacena la VM entre ejecuciones? | base qcow2 partida en 4 assets de un Release, versionada |
| ¿Cómo se recupera? | `cat` de los 4 trozos + verificación sha256 contra manifiesto |
| ¿Cómo la arranca y controla OpenCode? | `workflow_dispatch` vía API; dentro, QMP + filesystem compartido `virtfs` |
| ¿Overlays / volver atrás? | sí — overlay descartable por defecto; estados nombrados en Releases |
| ¿Cómo entra la ISO 21H2? | **nunca se monta dentro de la VM.** Se adjunta al runner como cdrom de solo lectura o se extrae con `7z`; ocupa disco del runner en cualquier caso (ver §4) |
| ¿Costo cero? | **sí** — minutos de repositorio público sin costo `[OFICIAL]`; Releases no facturado |

Sobre la ISO: `4.563 GB` de ISO más `6.66 GB` de base daría `11.2 GB`, pero sumando QEMU y
todo lo demás queda al borde.

> **Corrección (ver `docs/12`).** La afirmación de que montarla como cdrom virtual implica
> "costo real en espacio cero" **es falsa**. `[IMPLEMENTADO]` `-drive file=...,media=cdrom`
> solo cambia la presentación hacia el guest; QEMU sigue haciendo `open()` sobre el fichero
> del runner. La ISO **sí ocupa disco** durante toda la instalación y es un término fijo del
> presupuesto. Cualquier aritmética que la excluya está mal planteada.

## 5. El único obstáculo: construir la base dentro de 14 GB

Operar la VM es cómodo. **Fabricar la base de la primera vez no lo es.**

Windows Setup copia la imagen a `~15 GB` sin comprimir, y encima hace swap y staging.
`docs/09` estimó el pico en `~24.36 GB`. El runner tiene `14 GB`. **Faltan ~10 GB.**

Nota: es un problema exclusivo del runner. Una vez que la base existe y vive en Releases,
nunca más hay que construir nada — se recombinan 6.66 GB, que sí entran.

> **Corrección (ver `docs/12`).** El `14 GB` es el **piso garantizado** por GitHub `[OFICIAL]`,
> no el valor típico. En repositorios públicos el runner de 4 núcleos aterriza habitualmente
> en un SKU de `150 GB` de disco con `~90 GB` libres `[COMUNIDAD]`. Además, borrar las
> toolchains preinstaladas libera del orden de `8–10 GB` `[COMUNIDAD]`. Por eso el `13.9 GB`
> de abajo, que se apoya en un presupuesto sin limpiar, es una cota pesimista y debe
> sustituirse por una medición.

### Salida 1 — construir con Compact OS desde el inicio (gratis, viable)

técnicas para bajar el pico:

| Palanca | Ahorro | Etiqueta |
|---|---|---|
| ISO como cdrom virtual: **no se copia al disco destino**, pero sigue ocupando el disco del runner | no ahorra espacio, solo evita duplicarla | `[IMPLEMENTADO]` |
| `ImageInstall\OSImage\Compact = true` en el unattend: Setup instala ya comprimido y **no hace una compactación posterior** que necesite espacio temporal | evita duplicar los ~15 GB | `[OFICIAL]` |
| Pagefile de instalación en 0 y `powercfg /hibernate off` | ~2–4 GB | `[EST]` |
| Borrado de toolchains preinstaladas del runner antes de empezar | ~8–10 GB, **medible con `df` dentro del job** | `[COMUNIDAD]` |
| WinPE staging en el mismo disco, se libera al final | ~0.5 GB transitorio | `[OFICIAL]` |
| Disco destino de 12 GB, una partición, sin Reserved Storage | — | 14393 no tiene Reserved Storage |

```
piso garantizado 14 GB + limpieza ~8-9 GB  ≈  22-23 GB de presupuesto efectivo
pico estimado: ISO 3.3 + base 9.4 + staging 0.5 + temp 0.5 + QEMU 0.9  ≈  14.2 GB
```

**Margen estimado: ~8 GB.** `[EST]` — aritmética, no evidencia. El diseño y el procedimiento
de medición están en `docs/12-prueba-pico-almacenamiento.md`; el veredicto sigue siendo
`COMPACT-OS-BUILD: NO MEDIDO` hasta que haya un `min_avail` real.

### Salida 2 — construir una sola vez fuera del runner

Cualquier máquina con `≥30 GB` libres construye la base en una hora y la sube al Release
partida en 4 trozos. A partir de ahí el laboratorio es 100 % GitHub Actions.

Lo que **no** hace falta: un proveedor de cloud con nested virt y free tier. Se verificó que
ninguno existe (OCI Always Free es ARM, `A1.Flex` no corre invitados x86 `[OFICIAL]`;
AWS y GCP no ofrecen anidado en free tier; Azure no).

## 6. Alternativas descartadas, con el motivo

| Plataforma | Motivo del descarte |
|---|---|
| OCI Always Free | `A1.Flex` es ARM Ampere `[OFICIAL]`: no puede ejecutar Windows x86. BYOL no existe en Free Tier `[OFICIAL]`. Las shapes x86 Always Free (`E2.1.Micro`) tienen 1 GB RAM. |
| Azure Pipelines | Agentes Windows hospedados son efímeros por diseño y sin nested virt soportado |
| GitLab / CircleCI / AWS / GCP | Mismo motivo: efímero y/o sin virtualización anidada |
| Ubicloud | $2.5 de crédito `[COMUNIDAD]` y máquina efímera por job; no hay base persistente |
| Codespaces | Host Linux; no hay host Windows |

Ninguna alternativa aporta algo que GitHub Actions no dé, y GitHub además suma control por
API, que los otros no.

## 7. Riesgos que quedan, con su severidad

| Riesgo | Severidad | Mitigación |
|---|---|---|
| Nested virt no soportada oficialmente `[OFICIAL]`: *"technically possible… experimental, done at your own risk"* | **alta** | runner **Linux** con `-accel kvm`, nunca WHPX; `kernel-irqchip=off` reduce fallos reportados `[COMUNIDAD]` |
| No cabe la construcción en 14 GB | **alta** | §5 salida 1; si falla, salida 2 |
| Windows 14393 sin soporte desde 2016 | **media** | la VM queda congelada en el tiempo; es lo buscado para el experimento |
| AppX/MSIX de 21H2 con dependencias de 19044 | **media** | es precisamente lo que se va a medir; que falle es un resultado, no un bloqueo |
| Repositorio público expone el contenido | **baja** | no hay secretos; los discos no contienen nada sensible |
| Eviction del Cache a 7 días | **baja** | se elude por completo usando Releases |

## 8. Decisión

**No hace falta cambiar de plataforma. Hace falta una sola verificación empírica: que
Windows Setup con Compact OS desde el inicio quepa en el presupuesto efectivo real del
runner.**

El procedimiento de medición está en `docs/12-prueba-pico-almacenamiento.md` y el script
ejecutable en `.github/workflows/10-sonda-disco-construccion.yml`. No se ha ejecutado: sin
credenciales de escritura no hay forma honesta de obtener un `min_avail`.

Si entra, el laboratorio está resuelto al 100 % con GitHub Actions gratuito y el siguiente
paso es construir la base y arrancar los experimentos. Si no entra, la salida 2 es una hora
de trabajo en cualquier máquina y no cambia la arquitectura.

Ambas rutas cuestan cero.

Estado actual: **`COMPACT-OS-BUILD: NO MEDIDO`**.

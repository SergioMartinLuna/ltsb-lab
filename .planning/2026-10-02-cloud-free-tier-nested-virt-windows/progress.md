# Progress Log — Free-tier cloud + nested virt + 2 VMs Windows

Fecha: 2026-10-02

## Fase 1 — Pregunta central (nested virtualization)
- Investigada documentación oficial OCI (Compute Shapes, blog Oracle Linux 2025, resizinginstances, OLCNE).
- Hallazgo: Ampere/ARM no soporta nested virt; A1/A2/A4 no soportan Windows.
- Investigada doc oficial AWS nested virtualization (lanzamiento feb-2026 +扩充 junio-2026).
- Hallazgo: AWS SÍ soporta nested virt en C7i/M7i/C8i/M8i/… pero ninguno es always-free.
- GCP doc oficial: E2 VMs excluidas explícitamente.
- Azure doc oficial: solo series Dv3+/Ebsv5+/M/F → B-series no.

## Fase 2 — OCI en detalle
- Always Free Resources doc leída completa.
- Hallazgo mayor: A1 reducido de 4 OCPU/24 GB a **2 OCPU/12 GB** el 15-jun-2026 (sin anuncio).
- Block volume: 200 GB totales + 5 backups.
- Idle reclamation: Oracle puede destruir instancias ociosas (7 días, <20% CPU/red/mem).
- Microsoft licensing doc: BYOL **no disponible en Free Tier**; licencia OCI-provided = $0.092/OCPU-h.
- BYOI: solo Windows Server 2016/2019/2022/2025; importar ISO no soportado.
- Free Tier doc: tarjeta de crédito necesaria, autorización $1, sin cargo salvo upgrade.

## Fase 3 — AWS / GCP / Azure
- AWS: free tier cambió 15-jul-2025 a créditos ($100 + hasta $100), 6 meses. EC2 no es always-free.
- AWS: EBS free 30 GB + 2M I/Os + 1 GB snapshot (solo legacy).
- AWS: licencia Windows license-included $0.046/vCPU-h (m7i-flex.large → 2 vCPU → $0.092/h).
- GCP: 1 e2-micro/mes, 30 GB-month PD, regiones us-west1/us-central1/us-east1; límite por tiempo no por instancia.
- GCP: licencia Windows $0.046/vCPU-h (f1-micro/g1-small $0.023/h).
- GCP: BYOL Windows Server normalmente no elegible por License Mobility.
- Azure: 750 h/mes de B1s (Linux y Windows), B2pts v2 (ARM), B2ats v2 (AMD); 12 meses; 2 discos P6 64 GB.
- Límite cuantitativo: 750 h/mes < 1.460 h necesarias para 2 VMs 24/7.

## Fase 4 — Otros
- Hetzner: sin free tier (CX desde ~€3.49-5.49/mes). Confirmado.
- DigitalOcean: $200 créditos 60 días, sin compute perpetuo (mín $4/mes).
- Vultr: $100-300 créditos promo. Linode/Akamai: $100 créditos 60 días.
- Búsqueda negativa de free tier con nested virt: ninguno.
- Excepción parcial: GitHub Actions larger runners (nested virt desde 2024) pero EFÍMEROS por job.
- Colab/Kaggle: no se halló doc oficial que exponga /dev/kvm; runtimes efímeros.

## Fase 5 — Informe
- Tabla comparativa construida.
- Veredicto: NINGÚN proveedor cumple.

## Errores
| Error | Intentos | Resolución |
|---|---|---|
| Hook "PLAN TAMPERED" tras pwf_init | 1 | Se reescribió task_plan.md con fases reales |
| URL de doc OCI nested-virt daba 404 (virtualization-with-kvm-on-oci.htm) | 1 | Se localizó evidencia equivalente en computeshapes.htm + blogs oficiales |

## Fase 6 — Verificación de nested virt en GitHub + medición del host local

- Corrección importante: la cita "nested virtualization is technically possible... not
  officially supported" existe pero **no está en la página canónica actual**
  `actions/reference/runners/github-hosted-runners`; vive en rutas heredadas
  (`about-github-hosted-runners`), en `enterprise-cloud@latest/.../github-hosted-runners` y
  en el contenido fuente `github/docs`. La página actual solo afirma que arm64 macOS no
  soporta anidado. Etiquetado como `[OFICIAL, ubicación discreta]`.
- Storage oficial verificado en `actions/reference/limits`: artifacts **500 MB** (Free),
  cache **10 GB/repo**, excedente de cache facturado a **$0.07 USD/GB/mes**, eviction a los
  7 días sin acceso, job timeout **6 h**, concurrencia 20 (Free).
- Aritmética de los dos cuellos: simultaneidad deficit ~2.9 GB en el disco de 14 GB
  (las dos bases solas son ~14.7 GB); persistencia deficit ~4.7 GB contra el cache de 10 GB.
  RAM 16 GB y CPU 4 vCPU **sí alcanzan** y no son el límite.
- **Hallazgo mayor: se midió el host del usuario y es Windows 10 Enterprise LTSC 2021
  build 19044**, o sea exactamente la segunda VM del objetivo. CPU Intel Celeron N4020
  2c/2t, VT-x/SLAT/VMMonitor/DEP todos "Sí", 7.8 GB RAM, 313.6 GB libres en `S:`.
  Hyper-V no instalado (`vmcompute`/`vmms`/`hns` ausentes); QEMU no instalado.
- QEMU WHPX probado desde Windows 10 2004 `[OFICIAL]`; no es virtualización anidada, el
  invitado corre directo sobre el hipervisor de Windows. Conflicto conocido `[COMUNIDAD]`:
  con `Microsoft-Hyper-V-All` habilitado WHPX falla; usar solo `HypervisorPlatform`.
- Footprint de 19044 sigue `[NO ENCONTRADO]`: Compact OS está soportado en LTSC 2021 pero
  Microsoft no publica tabla de tamaños para ese build.
- Escrito `docs/10-veredicto-de-plataforma.md` con veredicto, 4 opciones de descarte y las
  4 decisiones que el usuario debe tomar.

## Fase 7 — Corrección definitiva del objetivo: UNA sola VM 14393

El usuario eliminó el requisito de dos VMs simultáneas y descartó el host local como
infraestructura. Objetivo nuevo: **una** VM Windows 10 LTSB 2016 (14393) persistente, con
la ISO de 21H2/LTSC 2021 usada solo como fuente de extracción y comparación (explorer.exe,
DLLs de shell, AppX/MSIX, dependencias, manifests) montada fuera de la VM.

### Hallazgo que cambia el veredicto

**GitHub Releases no tiene límite total de tamaño**, solo 2 GiB por archivo, hasta 1000
assets y sin tope de ancho de banda `[OFICIAL]`:
"Up to 1000 release assets may be associated with a single release. Each file included in
a release must be under 2 GiB. There is no limit on the total size of a release, nor
bandwidth usage." — https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases

Esto **elimina el techo de 10 GB del cache** que había marcado el análisis anterior. La
base qcow2 de 6.66 GB no entra como archivo único, pero se parte en 4 trozos de ~1.7 GB y
se recombina en el runner. Los discos de la VM y los overlays de estado viven en Releases,
versionados y con historial. Cache queda solo para herramientas chicas.

### Veredicto reemitido

**Sí hay plataforma remota gratuita**: GitHub Actions sobre repo público. Presupuesto por
job con una sola VM: experimentos ~10.4 GB de 14 GB `[OFICIAL]`; fuente 21H2 ~5.9 GB. Son
jobs separados, así que la ISO nunca compite con la VM por disco. La ISO además se monta
como cdrom virtual y no se copia al disco del runner.

### Único obstáculo restante

Construir la base una vez: el pico de instalación es ~24.36 GB `[EST]` contra 14 GB
disponibles. Dos salidas gratuitas:
1. Compact OS desde el inicio (`ImageInstall\OSImage\Compact = true`), ISO como cdrom
   virtual, pagefile de instalación en 0-256 MB, disco destino de 12 GB → pico ~13.9 GB.
   Viable en aritmética, **no verificado en ejecución**. Margen ~0.1 GB.
2. Construir una vez en cualquier máquina con ≥30 GB libres y publicar en Releases.

Las dos cuestan cero y no cambian la arquitectura.

### Estado de validación

- `docs/11-veredicto-laboratorio-una-vm.md` creado (213 líneas, UTF-8 limpio).
- `docs/10` marcado como superado y conservado como registro.
- README actualizado: documentos, bloqueo 5 reescrito, bloqueo 6 nuevo (almacenamiento
  resuelto), fase F reabierta.
- `scripts/validar.sh`: sin fallos, 0 enlaces rotos, 0 CJK/U+FFFD.
- `scripts/validar-powershell.ps1`: 10/10 OK, 0 errores, 0 avisos de PS7.

## Errores
| Error | Intentos | Resolución |
|---|---|---|
| Hook "PLAN TAMPERED" tras pwf_init | 1 | Se reescribió task_plan.md con fases reales |
| URL de doc OCI nested-virt daba 404 (virtualization-with-kvm-on-oci.htm) | 1 | Se localizó evidencia equivalente en computeshapes.htm + blogs oficiales |
| `docs/billing/reference/storage-for-github-actions` y `/actions-storage` dieron 404 | 2 | Límites tomados de `actions/reference/limits` y de la doc de billing, ambos 200 |
| `Get-WindowsOptionalFeature` requiere elevación | 1 | Estado de features queda `[POR MEDIR]`; el agente no está elevado |
| Caracteres corruptos introducidos al escribir `docs/11` | 2 | 4 reemplazos + verificación con Python (UTF-8 decodifica, solo quedan em-dash/flechas/dibujo de caja) |
| PowerShell reportaba CJK espurio al leer UTF-8 | 1 | Se validó con Python en vez de con `Get-Content` |

## Estado
Fases 1–7 completadas. Objetivo corregido a una sola VM. `docs/11` es el veredicto
vigente. Sin commit, sin push, sin autenticación, sin ejecución. El host local quedó
descartado por decisión del usuario.

Siguiente paso propuesto: una sola verificación empírica antes que nada — confirmar que
Windows Setup con Compact OS desde el inicio cabe en 14 GB. De eso depende que la base se
construya sola en el runner o necesite una máquina externa una vez.
---

# Fase 8 — Sonda del pico real de almacenamiento (2026-10-02)

## Objetivo de la fase
Responder si la base 14393 se puede construir sola en el runner con Compact OS desde el
inicio, midiendo el pico real en vez de calcularlo. Sin construir la base definitiva.

## Correcciones a la evidencia previa
- **[IMPLEMENTADO] Falso claim retirado de `docs/11`:** montar la ISO como
  `-drive file=...,media=cdrom,readonly=on` NO tiene coste cero de espacio. QEMU hace
  `open()` de un fichero regular del runner; `media=cdrom` solo cambia la presentación
  hacia el guest. La ISO es término fijo del presupuesto.
- **[COMUNIDAD] El `14 GB` es piso, no valor típico:** en `actions/runner-images#14492` un
  empleado de GitHub declara que repos públicos usan SKU de 4 núcleos con disco de 150 GB y
  ~90 GB libres; privados siguen en ~14 GB. El compromiso oficial sigue siendo 14 GB.
- **[COMUNIDAD] Palanca de presupuesto:** borrar toolchains preinstaladas
  (`dotnet`, `ghc`, `android`, `llvm`, `julia`, `msedge`, `powershell`,
  `$AGENT_TOOLSDIRECTORY`) libera ~8–10 GB. Verificable con `df` dentro del propio job.
- **[OFICIAL] Scratch de WinPE = 512 MB en RAM** (`X:`), no en disco: no suma al presupuesto.
- **[OFICIAL] `wimlib-imagex apply --compact` es Windows-only:** no sirve para replicar
  Compact OS en un runner Linux. Solo Setup real dentro de la VM mide el footprint compacto.
- **[NO ENCONTRADO] No hay URL oficial directa y estable para la ISO 14393:** la página de
  Windows exige selección de edición y la evaluación actual sirve LTSC 2021, no LTSB 2016.

## Aritmética revisada (sigue siendo [EST], no evidencia)
Presupuesto garantizado 14 GB + limpieza ~8–9 GB ≈ 22–23 GB efectivos.
Pico estimado: ISO 3.3 + base compacta 9.4 + staging 0.5 + temp 0.5 + QEMU 0.9 ≈ 14.2 GB.
Margen estimado ~8 GB. La cota pesimista anterior (`13.9 GB` sobre 14 GB sin limpiar) queda
sustituida; ninguna de las dos es una medición.

## Entregables
- `.github/workflows/10-sonda-disco-construccion.yml` — sonda de 8 etapas, un job.
  Etapas: censo → limpieza y nueva medición → ISO desde Release verificada → disco destino
  sparse 12 GiB → unattend con `Compact=true` + imagen FAT16 para `autounattend.xml` →
  sampler arrancado antes de QEMU → Setup bajo KVM → agregación y veredicto → artifact.
  El sampler corre en el runner cada 2 s y registra `(timestamp, avail, du destino)`.
  El "temporal + auxiliar" se obtiene como residuo `pico − iso − destino`, que es lo único
  que captura lo no controlado sin recorrer el árbol del guest cada 2 s.
- `docs/12-prueba-pico-almacenamiento.md` — diseño, aritmética etiquetada, procedimeinto de
  obtención de la ISO, criterio de aceptación y limitaciones declaradas.
- `docs/11-veredicto-laboratorio-una-vm.md` — corregido el claim de la ISO, el rol del
  `14 GB` y el veredicto final.

## Criterio de aceptación (fijado antes de ejecutar)
```
VIABLE     <=> min_avail >= 2 GiB AND qemu rc == 0
NO VIABLE  <=> min_avail < 2 GiB, o Setup falla con 0x80070070 (ERROR_DISK_FULL)
```
Más: si el job aterrizó en el SKU grande, el resultado se marca `NO-CONCLUYENTE` aunque el
pico sea holgado, porque no informa sobre el piso garantizado.

## Obtención de la ISO sin comprometer el presupuesto
El runner no descarga la ISO de un tercero. Vive en un Release del propio repo troceada en
assets <2 GiB, con `iso_size_bytes` e `iso_sha256` como inputs de `workflow_dispatch`; se
verifica antes de montar y se monta loop read-only. Queda pendiente publicar ese primer
Release y fijar los hashes: sin él la etapa 2 no arranca.

## Bugs encontrados y corregidos durante el diseño
| Bug | Corrección |
|---|---|
| sampler con rutas inventadas `/home/runner/work/...` | usa `$GITHUB_WORKSPACE` |
| `autounattend.xml` adjunto como si fuera dispositivo de bloque | empaquetado en `autounattend.img` FAT16, expuesto como segundo CDROM |
| línea basura `if [ "$VEREDUCIBLE" = "" ]` | eliminada |
| `USADO_TOTAL` y `OCUPADO_DISCO` calculados pero no usados | `PICO_DESTINO` = máximo de la columna 3 |
| `ISO_B` sin uso en el sampler | eliminado |
| variables de la etapa 6 escritas con `${VAR}` dentro de un bloque `{ }` sin exportar | corregido al gathered/env ya propagado |

## Validación
- YAML parseable: OK. 1 job, 9 pasos.
- `bash -n` sobre los 8 pasos `run:` unix: OK.
- `bash scripts/validar.sh`: sin fallos, enlaces rotos 0, caracteres corruptos 0.

## Veredicto
No se ejecutó nada: no hay credenciales de escritura, `gh` no está instalado, no hay remoto
configurado y el encargo prohíbe commit/push. Sin `min_avail` real no hay respuesta honesta.

**`COMPACT-OS-BUILD: NO MEDIDO`**

## Próximo paso
Publicar el Release con la ISO 14393 troceada, fijar `iso_size_bytes` e `iso_sha256`, y
lanzar `workflow_dispatch` de la sonda repetidas veces hasta que alguna corrida aterrice en
el SKU del piso para que el veredicto sea concluyente.

## Errores (añadidos)
| Error | Intentos | Resolución |
|---|---|---|
| Hook "PLAN TAMPERED" antes de esta fase | 1 | Releer task_plan.md desde disco antes de escribir |
## Fase 9 — Ejecucion real (2026-10-03)

Repo publico `SergioMartinLuna/ltsb-lab` creado y publicado. Release `iso-14393` con la ISO
14393 troceada en 4 assets + `SHA256SUMS`.

### Coridas de la sonda y fallos encontrados (todos por codigo, no por hipotesis)

| Corrida | Sintoma | Causa raiz real | Correccion |
|---|---|---|---|
| 37082286247 | `sha256sum: no properly formatted checksum lines` | Se escribia el hash sin nombre de fichero | `printf '%s  instalador.iso\n'` |
| 37082671177 | `no properly formatted checksum lines` (2a vez) | `sha256sum -c` toma el 2o argumento como OTRO fichero de checksums | Quitar el argumento extra |
| 37082949452 | `no se encontro una imagen Enterprise` | awk sobre `Index: 1`: el indice es `$2`, no `$3` | `idx=$2` + fallback |
| 37083720493 | `mkfs.vfat: too small or too large` | FAT16 exige >=4085 clusters; 2 MiB no alcanza | Imagen FAT16 de 16 MiB |
| 37084124138 | `samples.tsv: No such file` | El sampler escribia en `medicion/samples.tsv`, la medicion leia `samples.tsv` | Unificar en `$WS/samples.tsv` |
| 37084649040 | `qemu_rc=1`, 2 muestras | `Could not access KVM kernel module: Permission denied` | Ver abajo |
| 37085255458 (diag) | — | **`kvm-ok` dice "KVM acceleration can be used"** | Diagnostico decisivo |
| 37085639291 | QEMU no arranca | `virtio-net-pci.net` no existe en QEMU 8.2 | Usar `netdev=n0` |
| 37085942255 | en curso | — | — |

### Hallazgo clave sobre KVM

La virtualizacion anidada SI esta disponible en los runners publicos. El fallo
`Permission denied` NO era ausencia de KVM: `/dev/kvm` es `root:kvm 0660` y el usuario
`runner` no pertenece al grupo `kvm` (`kvm:x:993:` sin miembros). La sonda ahora valida con
`kvm-ok` y ejecuta QEMU con prefijo `sudo` cuando el usuario no tiene acceso directo.

### Datos ya medidos del runner (no conclayentes para el piso de 14 GB)

- AVAIL_INICIAL ~ 92.4e9 bytes (86.07 GiB) -> `SKU: grande`, no el piso garantizado.
- Tras limpiar toolchains: ~127.0e9 bytes (118.27 GiB). La limpieza libera ~34.5 GB.
- `avail_pre_setup` ~ 123.0e9 bytes (114.6 GiB).
- `/` y `$GITHUB_WORKSPACE` son el mismo dispositivo (`/dev/root`).

### Contenido real de la ISO (verificado dentro del runner)

- `install.wim`: 1 imagen, LZX, 3.035.720.472 bytes comprimida.
  - Index 1 = "Windows 10 Enterprise 2016 LTSB", Total Bytes 12.120.640.762 (11.29 GiB sin comprimir).
- `boot.wim`: 2 imagenes (Windows PE x64 / Windows Setup x64), Build 14393.
- SHA256 de la ISO ensamblada en el runner: **OK** (assets del Release verificados byte a byte).

Nota de diseno: la imagen ocupa 11.29 GiB sin comprimir, asi que un disco destino de 12 GiB
no deja margen para los temporales de Setup. La sonda se lanza con `target_gb=20`.

# 12 — Prueba del pico real de almacenamiento (Compact OS 14393)

> Estado: **diseño completo, ejecución NO realizada**.
> Este documento no construye la base definitiva. Define cómo medirla.

## 1. Pregunta

¿Se puede construir **una sola** VM Windows 10 Enterprise LTSB 2016 (build 14393)
directamente en un runner de GitHub Actions, con `Windows Setup` y **Compact OS desde el
inicio**, sin depender del límite de 14 GB de almacenamiento?

La respuesta requiere un **pico medido**, no una suma de números. Este documento explica
por qué el cálculo anterior no bastaba, qué hay que medir y cómo.

## 2. Por qué los cálculos anteriores no cierran la pregunta

### 2.1 La ISO sí ocupa disco del runner

`docs/11` afirma que montar la ISO como CDROM virtual no tiene coste de almacenamiento.
**Eso es falso.** `[IMPLEMENTADO]`

QEMU no lee la ISO de ninguna parte que no sea el filesystem del runner:

```
-drive file=iso/instalador.iso,if=ide,media=cdrom,readonly=on
```

`media=cdrom` solo cambia la **presentación** hacia el guest (emulación ATAPI, arranque
desde CD). La lectura sigue siendo un `open()` de un fichero regular en el disco del
host. El fichero ocupa sus bytes reales durante toda la instalación.

Por tanto la ISO es un término fijo del presupuesto y debe estar dentro de la medición,
no fuera.

### 2.2 El límite de 14 GB es un piso, no el valor típico

GitHub documenta **`>= 14 GB` libres** como compromiso para runners estándar de 2 y 4
núcleos `[OFICIAL]` — <https://docs.github.com/en/actions/reference/runners/github-hosted-runners>.

Pero en `actions/runner-images#14492`, un empleado de GitHub declaró `[COMUNIDAD]`:

> - Public repos use 4-core VM, which has a 150 GB disk and ~90 GB of free space.
> - Private repos use 2-core VM, which has a 75 GB disk and ~14 GB of free space.
>
> Previously, there was an issue where 4-core VMs had a 75 GB disk instead of 150 GB.
> We fixed this recently, on July 27. […] our official commitment is a 75 GB disk with
> 14 GB of free space on both public and private repos. We have no plans to reduce the
> 150 GB disk […] but we can't guarantee it will stay that way forever.

Esto obliga a separar dos preguntas que el diseño anterior mezclaba:

| Pregunta | Se responde con |
|---|---|
| ¿Cabe en el runner que **tengo hoy**? | una sola corrida cualquiera |
| ¿Cabe **garantizado** por GitHub? | una corrida que aterrice en el SKU de 14 GB |

Una medición hecha en el SKU de ~90 GB libre **no demuestra nada sobre el piso garantizado**.
La sonda clasifica en qué SKU aterrizó y marca el resultado como no concluyente si no fue
el piso.

### 2.3 El presupuesto se puede ampliar de forma medible

El runner preinstala toolchains que ocupan mucho espacio y no hacen falta para instalar
Windows: `dotnet`, `ghc`, `android`, `llvm`, `julia`, `node_modules`, `msedge`, `chrome`,
`powershell`, y `$AGENT_TOOLSDIRECTORY` (Node, Python, Ruby, Go, Java, …).

Borrarlos libera del orden de 8–10 GB `[COMUNIDAD]`. Es la palanca más grande disponible y,
crucialmente, **es verificable dentro del propio job**: `df` antes y después.

Presupuesto efectivo esperado: `14 GB + ~8 GB ≈ 22 GB`.

## 3. Aritmética estimada (NO es evidencia)

Con la ISO 14393 medida en ~3.3 GB `[COMUNIDAD]`:

| Término | Bytes | GiB | Etiqueta |
|---|---:|---:|---|
| Presupuesto garantizado por GitHub | 14 680 000 000 | 13.67 | [OFICIAL] |
| ISO 14393 en el disco del runner | 3 300 000 000 | 3.07 | [COMUNIDAD] |
| QEMU + wimtools + ntfs-3g | 900 000 000 | 0.84 | [EST] |
| Base Compact OS 14393 | 10 090 000 000 | 9.40 | [EST] |
| WinPE staging en el destino | 500 000 000 | 0.47 | [OFICIAL] |
| Temporales de Setup (`$WINDIR\Panther`) | 500 000 000 | 0.47 | [OFICIAL] |
| **Pico de construcción** | **15 290 000 000** | **14.24** | **[EST]** |

Contra el piso garantizado, sin limpiar: **no cabe** (14.24 > 13.67).

Contra el presupuesto efectivo tras limpiar (~22 GB): **cabe con ~7.5 GB de margen** [EST].

El scratch de WinPE son 512 MB **en RAM** (`X:`), no en disco `[OFICIAL]`, así que no
suma al disco; el staging en el destino sí.

Nada de esta tabla se acepta como respuesta. Sirve para dimensionar el disco de prueba
(12 GiB) y para saber qué significa "viable" cuando llegue la medición.

## 4. Restricciones técnicas que fijan el diseño

1. **`wimlib-imagex apply --compact=FORMAT` es Windows-only** `[OFICIAL]`
   (<https://manpages.debian.org/testing/wimtools/wimlib-imagex-apply.1.en.html>).
   En el runner Linux no se puede replicar Compact OS con wimlib. La única forma válida
   de medir el footprint compacto es ejecutar Setup real dentro de la VM.

2. **La ISO 14393 no tiene una URL oficial directa y estable confirmada** `[NO ENCONTRADO]`.
   La página oficial de Windows requiere selección de edición y formulario; la ISO de
   evaluación actual sirve LTSC 2021, no LTSB 2016. Ver §6.

3. `Compact=true` solo está soportado en ediciones Home/Pro/Enterprise y superior
   `[OFICIAL]` (<https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/compact-os?view=windows-11>).
   LTSB 2016 es Enterprise, así que aplica. Queda `[POR MEDIR]` si el `install.wim` concreto
   lo honra y con qué ganancia real.

4. El comportamiento de particionado se declara en `DiskConfiguration`, y
   `ImageInstall/OSImage` debe ser **hijo directo** de `DiskConfiguration` para que
   Setup aplique la imagen. `InstallTo` apunta a la partición de datos.

5. `autounattend.xml` no puede adjuntarse como fichero suelto a `-drive`: QEMU espera un
   dispositivo de bloque. Se empaqueta en una imagen FAT16 mínima que se expone como
   segundo CDROM, que es como Setup lo descubre.

## 5. La sonda

Workflow: `.github/workflows/10-sonda-disco-construccion.yml`.
Un solo job (`medir`), `ubuntu-latest`, `workflow_dispatch` con parámetros.

### Etapas

| # | Etapa | Qué fija |
|---|---|---|
| 0 | `censo-inicial` | `df -B1 -T`, `free -b`, `nproc`, `lsblk`, `/dev/kvm`, versión de imagen. Clasifica el SKU (piso vs grande) y guarda `AVAIL_INICIAL_BYTES` |
| 1 | `liberar-espacio-y-medir-de-nuevo` | borra toolchains, vuelve a medir. Guarda `PRESUPUESTO_EFECTIVO_BYTES`. **El presupuesto nunca se supone: se mide** |
| 2 | `obtener-iso-desde-release` | baja los trozos del Release propio, verifica tamaño exacto y SHA256, monta loop-RO, ejecuta `wiminfo` sobre `install.wim` |
| 3 | `preparar-disco-destino` | instala QEMU, crea `objetivo.qcow2` sparse de 12 GiB (`preallocation=off`) |
| 4 | `escribir-unattend` | genera `autoinstall.xml` con `Compact=true`, sin hiberfil ni pagefile; lo empaqueta en `autounattend.img` FAT16 |
| 5 | `arrancar-sampler-y-Setup` | arranca el sampler **antes** de QEMU; luego `qemu-system-x86_64 -accel kvm` |
| 6 | `medir-y-emitir-veredicto` | agrega las muestras, calcula el pico, emite la tabla y el veredicto |
| 7 | `subir-informe` | sube solo `medicion/` como artifact (nunca la base) |

### El sampler

Corre en el runner, no en el guest, cada 2 s:

```bash
AVAIL=$(df -B1 --output=avail / | tail -1 | tr -d ' ')
TARGET=$(du -B1 "$GITHUB_WORKSPACE/lab/objetivo.qcow2" 2>/dev/null | cut -f1)
echo -e "$(date +%s)\t$AVAIL\t$TARGET" >> medicion/samples.tsv
```

### Cómo se obtiene cada magnitud pedida

| Magnitud solicitada | Origen |
|---|---|
| Espacio libre inicial | `$AVAIL_INICIAL_BYTES`, etapa 0 |
| Espacio libre durante el despliegue | columna 2 de `samples.tsv`, una muestra cada 2 s |
| Espacio libre en el peor momento | `min` de la columna 2 |
| Espacio ocupado por la ISO | `stat -c %s iso/instalador.iso` (constante y verificada por hash) |
| Espacio ocupado por el disco destino | `max` de la columna 3 |
| Temporales de Setup + auxiliares | **residuo**: `pico − iso − destino`. Es la única forma de capturar lo que no controlamos, sin caminar el árbol entero del runner cada 2 s |
| Pico máximo real | `avail_inicial − min_avail` |
| Espacio libre en el peor momento | `min_avail` |
| Tamaño final de la base | `du -B1 lab/objetivo.qcow2` tras apagar la VM |

El residuo es la cifra clave: si el pico real supera la suma `iso + destino`, la diferencia
es exactamente el overhead de Setup que el cálculo estático no puede ver.

### Criterio de aceptación

Fijado **antes** de ejecutar (regla 2 de `docs/00`):

```
VIABLE     <=> min_avail >= 2 GiB  AND  qemu rc == 0
NO VIABLE  <=> min_avail < 2 GiB, o Setup falla con 0x80070070 (ERROR_DISK_FULL)
```

Más un matiz que evita un falso positivo: si el job aterrizó en el SKU grande, el resultado
se marca `NO-CONCLUYENTE` aunque el pico sea holgado, porque no informa sobre el piso.

## 6. Cómo se obtiene la ISO 14393 sin comprometer el almacenamiento

El runner **no descarga la ISO de un tercero**. El canal correcto ya está definido en
`docs/11`: la ISO vive en un **Release del propio repositorio**, troceada en assets
`< 2 GiB`.

Parámetros de entrada del workflow:

| Input | Función |
|---|---|
| `iso_repo` | `owner/repo` público que aloja la ISO |
| `iso_release_tag` | tag del Release |
| `iso_asset_prefix` | prefijo común de los trozos (`p0`, `p0`+`2`, `p0`+`3`, …) |
| `iso_sha256` | hash esperado, para verificar antes de usar |
| `iso_size_bytes` | tamaño exacto esperado, para detectar un corte a medias |

La descarga se hace por rangos numerados desde `https://github.com/<repo>/releases/download/<tag>/<asset>`,
que no requiere autenticación en repos públicos, se verifica por tamaño y SHA256, y solo
entonces se monta.

Ventajas para el presupuesto:

- La ISO está **antes** del pico, no durante: se cuenta como término fijo.
- Se monta **read-only** y en loop; no se copia al disco destino.
- Se puede preparar en un job separado y cachear solo `install.wim`/`boot.wim` verificados,
  reduciendo el término de la ISO sin tocar la arquitectura.

Lo que **no** se hace, y por qué:

- **No** se descarga la ISO en el mismo instante en que crece el disco destino: eso sí
  competiriá por el mismo presupuesto y produciría un falso "no viable".
- **No** se recurre a fuentes de terceros sin hash verificable: sería una omisión de
  integridad, no una fuente.

Pendiente: publicar el primer Release troceado y fijar `iso_sha256`/`iso_size_bytes`. Sin ese
Release la etapa 2 no puede ejecutarse, y por tanto tampoco el resto.

## 7. Limitaciones declaradas de esta sonda

1. **No se ejecutó.** Requiere `workflow_dispatch` con credenciales de escritura, que este
   entorno no tiene y que el encargo prohíbe usar.
2. Un job puede aterrizar en el SKU grande; hace falta repetir hasta tocar el piso para que
   el veredicto sea concluyente.
3. El residuo agrupa temporales de Setup y auxiliares. Aislarlos exigiría muestrear el árbol
   del guest, que es intrusivo y añade coste.
4. El hash de la ISO depende del Release; si cambia, hay que republicar los assets.
5. La ISO 14393 concreta debe elegirse una vez y fijarse por hash. Cambiarla cambia el
   presupuesto.

## 8. Veredicto actual

No se ha ejecutado ninguna medición. El diseño está completo y validado estáticamente
(YAML parseable, los 8 pasos bash pasan `bash -n`), pero sin `min_avail` real no hay
respuesta honesta.

Lo único responsable hoy:

**`COMPACT-OS-BUILD: NO MEDIDO`**

## Referencias

| Fuente | Etiqueta |
|---|---|
| <https://docs.github.com/en/actions/reference/runners/github-hosted-runners> | [OFICIAL] |
| <https://github.com/actions/runner-images/issues/14492> | [COMUNIDAD] |
| <https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/compact-os?view=windows-11> | [OFICIAL] |
| <https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/windows-setup-scenarios-and-best-practices?view=windows-11> | [OFICIAL] |
| <https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpe-mount-and-image?view=windows-11> | [OFICIAL] |
| <https://manpages.debian.org/testing/wimtools/wimlib-imagex-apply.1.en.html> | [OFICIAL] |
| <https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases> | [OFICIAL] |
| `docs/11-veredicto-laboratorio-una-vm.md` | [PROPIO] |
| `docs/09-verificacion-limite-14-gb.md` | [PROPIO] |

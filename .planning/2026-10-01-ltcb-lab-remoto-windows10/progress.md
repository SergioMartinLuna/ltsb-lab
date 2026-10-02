# Progress Log — LTCB

Plan activo: `task_plan.md` (objetivo completo LTCB, no solo el hilo Dark Mode).

## Bitácora

| # | Acción | Resultado |
|---|--------|-----------|
| 1 | Inspección de unidades, workspace, git y herramientas | `F:` no existe; repo vacío; sin `gh`/docker/qemu; git y python presentes |
| 2 | Planning inicial creado con ID `2026-10-01-ltcb-lab-remoto-windows10` | 3 archivos en `.planning/` |
| 3 | Investigación de runners Windows y nested virtualization | Windows Server 2022/2025; 4 vCPU/16 GB/14 GB públicos; nested no soportada oficialmente |
| 4 | Investigación de KVM en runner Linux | Changelog oficial de Android acceleration; KVM como único caminoAccelerado |
| 5 | Investigación de costos y límites de artifacts/Release | Repo público gratis e ilimitado; Free privado 2000 min/500 MB; Release ≤2 GiB por archivo |
| 6 | Investigación Dark Mode 14393 (Hilo A) | Cronología, ordinals uxtheme, descarte de vía nativa, ruta temática viable |
| 7 | Investigación AppX/MSIX 14393 (Hilo B) | Escalera de 5 estados; MSIX Core soporta 14393 pero las apps del Store no |
| 8 | `docs/00-estado-inicial-y-alcance.md` | Discrepancia de unidad registrada como hallazgo, no silenciada |
| 9 | `docs/01-arquitectura-y-viabilidad.md` | Veredicto Linux+KVM, límites, riesgos, plan de mitigación |
| 10 | `docs/02-experimento-000-sonda.md` | EXP-000 con H0/H1/H2 y criterio de decisión escrito antes de ver datos |
| 11 | `workflows/00-sonda.yml` | Sonda: identidad, disco, `/dev/kvm`, `kvm-ok`, limpieza, red, boot real KVM vs TCG, `resumen.json` |
| 12 | `docs/03-darkmode-14393.md` | Informe del Hilo A con etiquetas y descartes documentados |
| 13 | `docs/04-appx-msix-14393.md` | Informe del Hilo B con tabla de errores y límites de MSIX Core |
| 14 | `task_plan.md` reescrito | Corregida desalineación: el plan cubría solo Dark Mode, ahora cubre el objetivo LTCB completo |
| 15 | `docs/05-control-por-agente.md` | Contrato de `reporte.json`, máquina de estados, WinRM vs SSH, captura QMP, inventario base |
| 16 | `docs/06-reproducibilidad-y-ejecucion.md` | Niveles L0-L4, cadena de dependencias, hashes, convención de artifact, idempotencia |
| 17 | `docs/07-registro-de-experimentos.md` | Matriz EXP-000..EXP-035 con estados y dependencias, plantilla, 7 reglas de disciplina |
| 18 | `docs/08-riesgos-y-limites.md` | 11 riesgos (R-01..R-11) con severidad y mitigación, más los límites aceptados |
| 19 | `experimentos/EXP-000, EXP-003, EXP-010, EXP-030.md` | 4 registros con hipótesis, método y criterio de decisión escrito antes de ejecutar |
| 20 | `README.md` | Índice del proyecto, estado, convenciones, próximos pasos |
| 21 | `scripts/validar.sh` + `scripts/validar-powershell.ps1` | Validación estática local, probada con casos negativos |
| 22 | `.gitignore` y README en `resultados/`, `logs/`, `imagenes/` | Separación entre evidencia pesada (artifacts) e interpretación (versionada) |
| 23 | Validación local ejecutada | YAML OK, 13/13 bloques bash OK, 4/4 bloques PowerShell OK, 0 enlaces rotos, 0 caracteres corruptos |
| 24 | Corrección de nomenclatura y ruta | `LTCB` → `LTSB` en 5 documentos; `F:` → `D:` en README y `docs/00`. El slug del plan no se renombra: `.active_plan` lo referencia |
| 25 | Investigación de runners Windows 2025 | 4 vCPU / 16 GB / 14 GB SSD públicos; UAC deshabilitado; WSL2 2.7.14.0 presente; QEMU, Hyper-V y WHPX **no** listados. Nested virt: posible, no soportada |
| 26 | Descubrimiento: el workflow estaba en `workflows/` | GitHub solo lee `.github/workflows/`. El archivo nunca se habría ejecutado, sin ningún aviso. Es el fallo más caro y más silencioso posible |
| 27 | `.github/workflows/00-sonda-windows.yml` creado | 6 pasos, `windows-latest`, `shell: powershell`, 3 runners, TSV por acelerador, artifact con `reporte.json` |
| 28 | 5 scripts de EXP-000 escritos | `comun`, `entorno`, `preparar`, `invocar-vm`, `consolidar` + `comandos-guest.txt`. Alpine netboot sin ISO, WHPX y TCG sin fallback |
| 29 | Bug de cultura `es-AR` | `126.6` se leía como `1266` y `3.4` como `34`. Corregido con `InvariantCulture`. Verificado |
| 30 | Bug de medición temporal | `Stopwatch.Stop()` tras `Start-Process`: `segundos` medía el lanzamiento, no el arranque. Movido tras `WaitForExit` |
| 31 | Bug de lógica invertido | `$limpio` usaba `-not $salioSolo`; como `WaitForExit` devuelve `$true` al salir por su cuenta, un apagado correcto se marcaba inestable y un timeout se marcaba limpio |
| 32 | Tabla de veredictos unificada | Estaba duplicada en `invocar-vm.ps1` y `consolidar.ps1`, y podían discrepar. Ahora solo `consolidar.ps1` decide, que es lo que las pruebas cubren |
| 33 | `VM_SIN_DISCO` tapaba la causa real | Si ninguna VM arrancaba, `disco_visible` es `null` y devolvía `VM_SIN_DISCO`. Ahora solo se evalúa si alguna VM llegó a userspace |
| 34 | `validar-powershell.ps1` nunca parseaba los `.ps1` | Buscaba bloques cercados, que un `.ps1` no tiene. Toda la lógica de EXP-000 quedó sin revisar. Ahora parsea el archivo completo |
| 35 | `validar-powershell.ps1` se detectaba a sí mismo | `$PatronesPS7` contiene literalmente `??`, `-AsHashtable`, `-AsByteStream`: 7 avisos falsos. Se salta esa búsqueda en ese archivo |
| 36 | `validar.sh` actualizado | Rutas reales de `.github/workflows` + fallo si hay workflows fuera; `bash -n` solo a pasos con shell Unix; chequeo de CJK y U+FFFD |
| 37 | `docs/01` reescrito en su veredicto | El veredicto Linux+KVM era una inferencia documental. Ahora: sin veredicto hasta medir. Techo de 14 GB identificado como el límite real, anterior a la aceleración |
| 38 | `docs/02` y `experimentos/EXP-000` reescritos | Sonda Windows: Alpine netboot, token `EXP000_USERSPACE_OK`, apagado autónomo, 7 veredictos documentados |
| 39 | Pruebas de veredicto ampliadas | De 8 a 17: 11 ramas (2 de regresión nuevas) + 6 comprobaciones de tipos del contrato JSON. **17/17 en verde** |
| 40 | Validación local final | Sin fallos: YAML parseable, 0 workflows fuera de ruta, PowerShell 10/10 con 0 avisos de PS7, 0 enlaces rotos, 0 CJK |

## Errores encontrados y resueltos

| Error | Causa | Resolución |
|---|---|---|
| Caracteres CJK corruptos en `docs/01` y `docs/08` | Erratas de generación en 3 líneas | Localizados con barrido de `\u4E00-\u9FFF` y corregidos. Barrido repetido: 0 restantes |
| `docs/05`: hashtable con `= try { } catch { }` | En PowerShell 5.1 una instrucción `try` no es una expresión | Reescrito: el `try` calcula `$ssh_estado` antes del literal. Detectado por el parser de 5.1 |
| `validar-powershell.ps1` reportaba OK sobre código roto | Bucle usaba `$line` en vez de `$linea`, así que el buffer quedaba vacío y el parser no veía nada | Corregido. Verificado con un archivo de prueba que produce error de sintaxis y 2 avisos de PS7 |
| `validar.sh` fallaba en los 13 pasos bash | `print()` de Python en Windows escribe CRLF: `bash -n` buscaba `s1.sh\r` | Se quita el CR final con `${path%$'\r'}` |
| `validar.sh` no encontraba `python` | En Git Bash el ejecutable es `python`, no `python3` | Detección en cascada `python3` / `python` / `py` |
| `validar.sh` no creaba los temporales | `mktemp` devuelve ruta con separadores nativos que `bash -n` no resuelve | Directorio temporal dentro del repo y separador `/` explícito en Python |
| El workflow estaba en `workflows/`, no en `.github/workflows/` | La ruta se eligió por costumbre, no por la regla de GitHub | Movido a `.github/workflows/`. `validar.sh` ahora falla si encuentra un workflow fuera de ahí |
| Cultura `es-AR` rompía la serialización | `ConvertTo-Json` y `-f` heredan la cultura regional: `126.6` se leía `1266`, `3.4` se leía `34` | `InvariantCulture` en `comun.ps1` y `consolidar.ps1`. Verificado con los cuatro valores |
| `segundos` medía el lanzamiento, no el arranque | `Stopwatch.Stop()` estaba justo después de `Start-Process` | Movido después de `WaitForExit` |
| Arranque limpio invertido | `WaitForExit` devuelve `$true` si el proceso salió por su cuenta; el código usaba `-not $salioSolo` | Eliminado. `invocar-vm.ps1` ya no decide: solo registra hechos |
| Dos tablas de veredictos que podían discrepar | El productor y el consumidor tenían su propia lógica, y las pruebas solo cubrían una | Unificadas en `consolidar.ps1` |
| `VM_SIN_DISCO` con causa real oculta | `disco_visible` es `null` si ninguna VM arrancó, y `-not $null` es `$true` | La comprobación solo corre si alguna VM llegó a userspace |
| `validar-powershell.ps1` nunca revisó los `.ps1` | Buscaba bloques cercados ```powershell, que un `.ps1` no tiene | Ahora parsea el archivo completo. 5 scripts de EXP-000 pasaron de "nunca revisados" a 5/5 |
| `validar-powershell.ps1` se detectaba a sí mismo | `$PatronesPS7` contiene literalmente `??`, `-AsHashtable`, `-AsByteStream` → 7 avisos falsos | Se salta la búsqueda de PS7 en ese archivo; 0 avisos |
| Harness con 2 fallos | El harness escribía `resultado=whpx/tcg` en vez de valores de la tabla | El bug estaba en el harness. Corregido y ampliado de 8 a 17 casos |
| `validar.sh` con `done` duplicado | El `edit` dejó el cierre del bucle dos veces → error de sintaxis en la línea 114 | Detectado por el propio validador al ejecutarse; bloque huérfano eliminado |
| Informe de PowerShell vacío | `[void](Test-Codigo ...)` se tragaba el `Write-Output` de la función | Se llama como sentencia suelta; el detalle vuelve a imprimirse |
| README declaraba un chequeo de CJK que no existía | La comprobación se hizo a mano en una sesión y se documentó como permanente | Añadida como sección real de `validar.sh`, y verificada con casos positivos y negativos |

## Discrepancias registradas (no resueltas silenciosamente)

- **Ruta**: el objetivo declarado era `F:\F22\LTCB`; `F:` no está montada. Todo el trabajo quedó en
  `D:\Users\Darkness\Documents\F22\LTSB`. **Resuelto**: el usuario no objetó y se trabajanó
  selectivamente las apariciones visibles de `LTCB` y `F:`. El slug del directorio del plan se
  conserva, porque `.planning/.active_plan` lo referencia y renombrarlo rompería la atestación.
- **Plan vs resumen**: el plan en disco cubría únicamente el hilo Dark Mode mientras el trabajo
  cubría también el hilo AppX/MSIX. Reconciliado: ambos son objetivos de investigación del mismo
  proyecto.
- **StackOverflow 64773827** devuelve 403 al agente; el contenido citado viene de resultados de
  búsqueda, no de la página leída. Marcado `[NO ENCONTRADO]`/`[COMUNIDAD, no verificado]`.
- **Veredicto de `docs/01` vs evidencia**: el documento declaraba como arquitectura correcta
  `ubuntu-latest` + KVM. Esa conclusión era documental y se enunciaba con una confianza que la
  evidencia no sostenía. Corregido: sin veredicto hasta medir, y con el techo de 14 GB
  identificado como la restricción real.

## Estado: nada ejecutado en runtime

No se ejecutó ningún workflow, VM, descarga de ISO, instalación ni modificación de sistema.
Todos los veredictos de `docs/01`, `docs/03` y `docs/04` son **documentales**, no medidos.

## 5-Question Reboot Check

| Question | Answer |
|---|---|
| Where am I? | Phase 4b completada. EXP-000 implementado sobre el runner Windows y validado en local: 17/17 pruebas, 0 fallos de validación estática. Nada ejecutado en remoto |
| Where am I going? | Phase 6: ejecutar EXP-000 y registrar el veredicto. Previo: repo público y `gh auth login`, ambos del usuario |
| What's the goal? | Laboratorio remoto gratis de 14393 con QEMU, controlado por OpenCode, para investigar Dark Mode y AppX/MSIX |
| What have I learned? | Hilo A: no hay dark mode nativo en 14393, la vía es temática. Hilo B: MSIX moderno no instala en 14393 por MinVersion, pero MSIX Core y EXE/MSI sí ofrecen camino. Hilo C: **`docs/09` reencuadró el límite de disco**: *construir* 14393 no cabe (pico de 24.36 GB), *ejecutarlo* sí cabe en 14 GB con holgura de 3.84 GB. La imagen base se construye fuera |
| What have I done? | 10 documentos, 1 workflow en la ruta correcta, 5 scripts de EXP-000, 4 registros de experimento, 2 validadores estáticos, 17 pruebas de veredicto. Tres bugs reales encontrados validando, ninguno visible desde la ejecución |

## Estado: nada ejecutado en runtime

No se ejecutó ningún workflow, VM, descarga de ISO, instalación ni modificación de sistema. Los
únicos datos medidos son **locales**: 17/17 pruebas de veredicto, la validación estática en verde,
y la aritmética de `docs/09` recalculada por script. Todos los veredictos de `docs/01`, `docs/03` y
`docs/04` siguen siendo **documentales**, no medidos.

## Corrección del Hilo C — el encuadre estaba mal

La conclusión anterior «14393 no cabe en 14 GB, en ninguna arquitectura» era **falsa como
afirmación general**, por dos errores que esta verificación local destruye:

1. Los 20 GB se atribuían a Microsoft y venían de la metadata de Internet Archive. `[COMUNIDAD]`.
2. Eran **espacio libre requerido** — una comprobación de capacidad lógica — y se comparaban
   contra el **storage físico** del host. El footprint real de 1607 x64 con Compact OS es
   10.09 GB `[OFICIAL]`, no 20 GB.

Lo que sí se sostiene: el **pico de construcción** (24.36 GB) no cabe, por ISO + destino +
temporales coexistiendo, y no por culpa de 14393. `docs/01` se contradecía a sí mismo:
afirmaba lo contrario en `docs/01:350-352` y concluía la respuesta correcta en `docs/01:353-354`.

`docs/09` deja listadas las 8 correcciones pendientes en el corpus. **No se aplicaron**, por
instrucción de no modificar la arquitectura durante esta verificación. Dos elementos del corpus
quedan confirmados como correctos y no se tocan: `docs/02:50` (14393 *completo* no cabe — 15.06 GB
> 14 GB) y el límite de 500 MB de artifacts de repo privado.

Pendiente de medición, sin cambiar el veredicto: footprint instalado real de QEMU `[EST: 2.0 GB]`,
tamaño físico real del `base.qcow2` comprimido `[ESTIMADO: 5-8 GB]`, y el tamaño de la ISO local
del usuario (3.3 GB corresponde al SKU en-US x64 de archive.org).

## Bloqueos para la siguiente fase

1. Autorización para crear/publicar un repositorio **público** (en privado, 500 MB de artifacts no
   alcanzan para el `base.qcow2`).
2. `gh auth login` — el agente no puede autenticarse por sí mismo.
3. Fuente remota legal de la ISO 14393 troceada.

Con 1 y 2 se ejecuta EXP-000. Con 3, la construcción de la imagen base (que además tiene que
ocurrir fuera del runner).

# Task Plan: LTSB — laboratorio Windows 10 LTSB 14393 remoto, gratuito y controlado por OpenCode

## Goal

Construir en GitHub Actions un laboratorio descartable, gratuito y reproducible que permita
investigar Windows 10 LTSB 2016 (build 14393) con QEMU, controlado programáticamente por OpenCode,
cubriendo dos objetivos de investigación: Dark Mode real en File Explorer y AppX/MSIX/Store.

Restricciones: costo cero, cero cargas destructivas sobre instalaciones reales, evidencia
etiquetada por plano (declarado / implementado / runtime).

## Next Step

Todo el diseño local de EXP-000 está escrito, implementado y validado (17/17 pruebas en verde,
0 fallos de validación estática). Ahora hace falta una decisión del usuario para desbloquear la
ejecución remota:

1. **Repositorio.** Crear el repo **público** y configurar el remoto. Es necesario, no opcional:
   en repo privado el límite de 500 MB de artifacts no alcanza para el `base.qcow2` de 5-8 GB.
2. **`gh auth login`.** El agente no puede autenticarse.
3. **ISO 14393.** Fuente de distribución troceada.

Con 1-2 se puede ejecutar EXP-000, que es barato y decide la arquitectura de aceleración. Con 3 se
puede construir la imagen base.

Nota de Disco: el runner estándar tiene 14 GB de SSD. Windows 10 14393 no cabe dentro del runner,
ni en Windows ni en Linux. Esto no lo decide EXP-000 y no lo resuelve ninguna arquitectura: la
imagen base se tiene que construir **fuera** del runner.

## Current Phase

Phase 6 (ejecución remota) — esperando decisiones del usuario. EXP-000 implementado y validado
en local, pendiente solo de ejecución.

## Phases

### Phase 1: Inspección del entorno y alcance — completed
- [x] Verificar unidades disponibles (`F:` no existe; hay `C:`, `D:`, `S:`, `X:`)
- [x] Verificar estado del workspace (repo git vacío, sin commits, sin remoto)
- [x] Verificar herramientas locales (git y python presentes; `gh`, docker, qemu ausentes)
- [x] Registrar discrepancia de ruta destino
- [x] Documentar alcance y restricciones en `docs/00-estado-inicial-y-alcance.md`
- **Status:** completed

### Phase 2: Investigación de arquitectura y viabilidad — completed (reabierta)
- [x] Runners Windows:_server 2022/2025, recursos garantizados, nested virtualization no soportada
- [x] Runners Linux + KVM: vía Android acceleration, evidencia oficial
- [x] TCG como fallback: por qué no sirve para instalar Windows repetidamente
- [x] Costos Actions público vs privado; límites de artifacts; límites de Release
- [x] QEMU: opciones de red, unattended, overlay qcow2, captura por QMP screendump
- [x] Veredicto y riesgos en `docs/01-arquitectura-y-viabilidad.md`
- [x] **Corrección**: el veredicto Linux+KVM era una inferencia documental, no una medición. `docs/01`
      reescrito: sin veredicto hasta tener datos del runner Windows; techo de 14 GB identificado
      como el límite real, anterior a cualquier decisión de aceleración
- **Status:** completed

### Phase 3: Investigación de los dos objetivos temáticos — completed
- [x] Dark Mode en 14393:Cronología, ordinals, `DwmSetWindowAttribute`, vía temática, descartes
      → `docs/03-darkmode-14393.md`
- [x] AppX/MSIX/Store en 14393: escalera de 5 estados, MSIX Core, MinVersion, tabla de errores,
      tooling, Store ausente, lifecycle → `docs/04-appx-msix-14393.md`
- **Status:** completed

### Phase 4: Diseño de experimentos y control por agente — completed
- [x] Definir EXP-000 sonda de capacidades + criterios de decisión previos
- [x] `docs/05-control-por-agente.md` — cómo OpenCode opera la VM
- [x] `docs/06-reproducibilidad-y-ejecucion.md` — contratos, artefactos, resúmenes
- [x] `docs/07-registro-de-experimentos.md` — plantilla y matriz EXP-000..EXP-035
- [x] `docs/08-riesgos-y-limites.md`
- [x] `README.md` raíz
- [x] Registros de experimento: EXP-000, EXP-003, EXP-010, EXP-030
- [x] `scripts/validar.sh` + `scripts/validar-powershell.ps1`, probados con casos negativos
- [x] `.gitignore` y separación evidencia/interpretación
- **Status:** completed

### Phase 4b: Reimplementación de EXP-000 sobre el runner Windows — completed
- [x] Corregir `LTCB` → `LTSB` y la ruta `F:` → `D:` en toda la documentación
- [x] Mover el workflow a `.github/workflows/` (ruta real de GitHub) y retirar el obsoleto
- [x] Reescribir `docs/02` y `experimentos/EXP-000` para la sonda Windows: Alpine netboot sin ISO,
      WHPX y TCG, token de userspace, apagado autónomo
- [x] Implementar 5 scripts PowerShell 5.1: `comun`, `entorno`, `preparar`, `invocar-vm`, `consolidar`
- [x] Corregir bug de cultura `es-AR` en serialización numérica (`InvariantCulture`)
- [x] Corregir `Stopwatch` que medía el lanzamiento en vez del arranque
- [x] Unificar la tabla de veredictos en `consolidar.ps1` (el productor la tenía duplicada e invertida)
- [x] Arreglar `validar-powershell.ps1`: parsear `.ps1` completos y no autoseñalarse
- [x] `validar.sh`: rutas reales, saltar pasos PowerShell en `bash -n`, chequeo de CJK
- [x] 17/17 pruebas de veredicto en verde; validación estática sin fallos
- **Status:** completed

### Phase 5: Preparación de imagen base — blocked
- [ ] Localizar distribución legal de la ISO 14393 y trocearla — **bloqueado**, sin fuente
- [ ] `autounattend.xml` con WinRM/SSH y cuenta de laboratorio
- [ ] Script de construcción de `qcow2` base
- **Nota:** 14393 no cabe en los 14 GB del runner. La construcción debe ocurrir fuera del runner y
  publicarse como release.
- **Status:** blocked — depende del bloqueo de ISO y del login de GitHub

### Phase 6: Ejecución remota — blocked
- [ ] Autorizar repositorio público
- [ ] Login de GitHub (`gh auth login`)
- [ ] Ejecutar EXP-000 y registrar veredicto
- **Status:** blocked

## Key Questions

1. ¿Existe soporte nativo de Dark Mode en Explorer 14393? → **NO** `[OFICIAL]`. Nació en 17733/1809.
2. ¿Cuál es la vía reproducible en 14393? → **temática**: UltraUXThemePatcher + OldNewExplorer v1.1.8.1
   + tema compilado para 14393. Riesgo real de pantallas negras/BSOD reportado por usuarios.
3. ¿Se puede instalar MSIX moderno en 14393? → **NO**. MinVersion de las apps del Store (19041/17763)
   supera 14393; MSIX Core no reescribe ese piso.
4. ¿Qué sí es aprovechable? → MSIX Core con `TargetDeviceFamily MSIXCore.Desktop`, `.appx` nativo,
   y distribuciones EXE/MSI/portable de las mismas apps.
5. ¿Linux+KVM o Windows+WHPX? → **sin veredicto**. La conclusión previa (Linux+KVM) era documental,
   no medida. EXP-000 mide el runner Windows; si WHPX funciona, la arquitectura original se recupera.
6. ¿Cuánto se puede automatizar por OpenCode? → vía workflow_dispatch + inputs + artifacts;
   falta definir el contrato exacto.

## Veredicto

**Pendiente de medición.** La arquitectura propuesta sigue siendo `ubuntu-latest` + QEMU/KVM como
línea base, pero ahora es una hipótesis, no una conclusión. EXP-000 se ejecuta sobre
`windows-latest` para medir WHPX antes de decidir.

Restricción firme, anterior a la decisión de aceleración: **Windows 10 14393 no cabe en los 14 GB
del runner**, así que la imagen base se construye fuera del runner y se publica como release.

**No verificado en runtime**: nada se ha ejecutado todavía. Los únicos datos medidos son locales
(17/17 pruebas de veredicto, validación estática en verde).

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Escribir en el workspace real `D:\Users\Darkness\Documents\F22\LTSB` | `F:\F22\LTCB` no existe; no crear una unidad falsa ni inventar rutas. **Ruta resuelta**, el usuario no objetó |
| Corregir `LTCB` → `LTSB` en toda la documentación | "LTCB" nunca existió. Son 4 letras de error repetidas en cada documento por el mismo origen |
| Etiquetar cada afirmación `[OFICIAL]` / `[COMUNIDAD]` / `[HIPÓTESIS]` / `[NO ENCONTRADO]` | Requisito del usuario; evita presentar conjetura como hecho |
| No inventar exports, ordinals ni capacidades del runner | Sin evidencia primaria, cualquier veredicto queda como hipótesis |
| Primer experimento = sonda barata, no instalar Windows | Reduce riesgo y costo; valida la arquitectura antes de gastar horas de runner |
| Criterios de decisión de EXP-000 escritos **antes** de ver datos | Evita racionalizar el resultado a posteriori |
| No ejecutar nada remoto ni autenticarse sin autorización | Límite explícito del usuario |
| No usar ESU de pago para LTSB 2016 | Viola el límite de costo cero |
| Reimplementar EXP-000 sobre `windows-latest` en vez de `ubuntu-latest` | El objetivo es una VM de Windows; medir Linux no dice nada sobre el runner Windows. Además el host del usuario no tiene Hyper-V ni WSL2, así que una arquitectura solo-Linux no es reproducible en su máquina |
| La VM mínima de la sonda es **Linux**, no Windows | 14393 no cabe en 14 GB y tardaría horas bajo TCG. Con un kernel Alpine de 20 MB la pregunta "¿arrancó una VM?" se responde en segundos y sin ambigüedad |
| `shell: powershell` explícito en el workflow | Windows PowerShell 5.1 es el motor que valida `scripts/validar-powershell.ps1` y el que corre dentro de 14393. Con `pwsh` se revisaría una sintaxis y se ejecutaría otra |
| Un solo lugar decide el veredicto (`consolidar.ps1`) | La tabla estaba duplicada en el productor y el consumidor, y **podían discrepar**. Con dos tablas, las pruebas cubren una y el job corre la otra |
| Datos entre pasos en TSV, nunca en `$GITHUB_OUTPUT` | Los valores multilínea (la consola serie) se rompen al pasar por `$GITHUB_OUTPUT` |
| Un timeout nunca cuenta como éxito | Distingue una VM que funcionó de una que arrancó y quedó colgada |

## Errors Encountered

| Error | Attempt | Resolution |
|-------|---------|------------|
| `F:\F22\LTCB` inexistente | 1 | Se trabajó en el workspace asignado; se documentó la discrepancia y se pide confirmación |
| `gh`, docker, qemu no instalados | 1 | No se instalaron sin autorización; la ejecución remota requiere que el usuario autentique |
| El plan quedó alineado solo con el hilo Dark Mode | 1 | Plan reescrito para el objetivo LTCB completo; ambos hilos pasan a ser objetivos de investigación |
| ISO 14393 sin fuente remota legal identificada | 1 | `[NO ENCONTRADO]`; el usuario tiene la ISO localmente, hace falta distribución troceada |
| Caracteres CJK corruptos en `docs/01` y `docs/08` | 1 | Barrido de `\u4E00-\u9FFF` y corrección; 0 restantes |
| `docs/05` usaba `= try {} catch {}` dentro de un hashtable | 1 | No es expresión válida en PS 5.1. Reescrito; detectado por el parser de 5.1 |
| `validar-powershell.ps1` daba OK sobre código roto | 1 | Bucle usaba `$line` en vez de `$linea`, buffer vacío. Corregido y verificado con archivo de prueba |
| `validar.sh` fallaba los 13 pasos bash | 1 | Python en Windows escribe CRLF; `bash -n` buscaba `s1.sh\r`. Se quita el CR |
| `validar.sh` no encontraba `python` ni temporales | 1 | Detección `python3`/`python`/`py` y directorio temporal dentro del repo con separador `/` |
| El workflow estaba en `workflows/`, no en `.github/workflows/` | 1 | GitHub solo lee `.github/workflows/`: el archivo **nunca se habría ejecutado**, sin aviso. Movido, y `validar.sh` ahora falla si aparece un workflow fuera de ahí |
| Cultura `es-AR` rompía la serialización numérica | 1 | `126.6` se leía como `1266` y `3.4` como `34`. Corregido con `InvariantCulture` |
| `Stopwatch.Stop()` justo tras `Start-Process` | 1 | `segundos` medía el coste de crear el proceso, no el arranque de la VM. Movido tras `WaitForExit` |
| `$limpio` invertido en `invocar-vm.ps1` | 1 | `WaitForExit` devuelve `$true` cuando el proceso salió por su cuenta, y el código usaba `-not $salioSolo`. Un apagado correcto se marcaba inestable y un timeout se marcaba limpio |
| Tabla de veredictos duplicada en productor y consumidor | 1 | Las 8 pruebas de rama pasaban mientras el job real podía fallar, porque alimentan TSV a `consolidar` y nunca ejecutan el productor. Unificada en `consolidar.ps1` |
| `VM_SIN_DISCO` tapaba la causa real | 1 | Si ninguna VM arrancaba, `disco_visible` es `null` y devolvía `VM_SIN_DISCO`. Ahora solo se evalúa si alguna VM llegó a userspace |
| `validar-powershell.ps1` nunca parseaba los `.ps1` | 1 | Buscaba bloques cercados, que un `.ps1` no tiene. Toda la lógica de EXP-000 quedó sin revisar. Ahora parsea el archivo completo |
| `validar-powershell.ps1` se detectaba a sí mismo | 1 | `$PatronesPS7` contiene literalmente `??`, `-AsHashtable`, `-AsByteStream`. 7 avisos falsos. Ahora se salta la búsqueda de PS7 en ese archivo |
| El harness de pruebas fallaba 2 de 8 | 1 | El harness escribía `resultado=whpx/tcg` en vez de valores válidos. El bug estaba en el harness, no en el producto |
| El `edit` dejó un bloque `done`/`fi` duplicado en `validar.sh` | 1 | Sintaxis rota en la línea 114. Detectado por el propio validador al ejecutarse |
| `[void](Test-Codigo ...)` se tragaba el `Write-Output` | 1 | El informe salía vacío con 0 líneas de detalle. Se llamó como sentencia suelta |

## Notes

- El usuario pidió explícitamente avanzar incrementalmente y reportar, no entregar todo de una vez.
- Los documentos 03 y 04 son investigación **documental**; ninguno de sus mecanismos fue probado.
  `[HIPÓTESIS]` ≠ verificado.
- Investigar AppX/MSIX fue una ampliación del objetivo original que el usuario pidió preservar.
  No se descartó: es el objetivo de investigación B.

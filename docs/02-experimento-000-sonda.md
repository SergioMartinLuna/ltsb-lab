# 02 — Experimento 000: sonda de capacidades del runner Windows

Estado: **preparado y validado en local, no ejecutado**. Falta que el usuario cree el repositorio y
autentique `gh`. No se ha ejecutado ningún job, no se ha descargado ninguna ISO y no se ha tocado
Windows.

Este es el primer experimento y el único que no toca Windows. Mide si un runner `windows-latest`
puede ejecutar una VM mínima con QEMU, y con qué acelerador. De esa respuesta depende toda la
arquitectura de [`docs/01`](01-arquitectura-y-viabilidad.md).

> Cambio de rumbo respecto de la primera versión de este documento: la sonda corría sobre
> `ubuntu-latest` y medía `/dev/kvm`. Ver [Por qué Windows](#por-qué-windows) más abajo.

## Hipótesis

**H0**: QEMU arranca un guest Linux mínimo en el runner Windows con aceleración **WHPX**, y el
guest ve el flag `hypervisor` de `/proc/cpuinfo`. Eso significaría que hay virtualización anidada
real y que un Windows 14393 completo podría correr en el runner.

**H1**: WHPX no está disponible —la feature `HypervisorPlatform` está deshabilitada, o el
hypervisor anidado no está habilitado en el grupo de seguridad de la VM del runner— y QEMU solo
puede emular con TCG. La VM arrancaría, pero lenta.

**H2**: Ninguno de los dos arranca. La imagen del runner, sus features o su política de grupo
impiden la virtualización por completo, y la arquitectura de `docs/01` se cae entera.

Lo que H0 **no** implica, aunque salga verde: que quepa Windows 14393. El runner público tiene
**14 GB de SSD** y una instalación de 14393 no entra ni de lejos. H0 solo habilita la
investigación; no la resuelve.

## Estado inicial

Runner nuevo, imagen por defecto, sin ninguna modificación. No se habilita ninguna feature de
Windows, no se toca el grupo de seguridad y no se reinicia el runner: si EXP-000 necesitara
reiniciar para habilitar WHPX, dejaría de medir el runner real y mediría uno montado por nosotros.

## Por qué Windows

La primera versión de la sonda usaba `ubuntu-latest` y KVM. Se descartó por dos razones:

1. **El objetivo es Windows.** Todo el laboratorio es una VM de Windows 10 14393. Descubrir
   capacidades de virtualización en Linux no dice nada sobre si el runner Windows las tiene, y las
   dos imágenes son máquinas distintas con grupos de seguridad distintos.
2. **El host del usuario es Windows y no tiene Hyper-V ni WSL2** (ver [`docs/00`](00-estado-inicial-y-alcance.md)).
   Una arquitectura que solo se puede ejecutar en Linux no se puede reproducir en la máquina que
   ejecuta el proyecto. QEMU con TCG funciona en Windows sin nada instalado.

## Diseño

La VM mínima es **Linux, no Windows**, a propósito. Un Windows 14393 completo no cabe en 14 GB y
tardaría horas en arrancar bajo TCG; además, si arrancara, no sabríamos distinguir "QEMU funciona"
de "Windows funciona". Con un kernel Linux de 20 MB y un initrd, la pregunta *"¿arrancó una VM?"*
tarda segundos y se responde sin ambigüedad.

- Runner: `windows-latest` con `shell: powershell` explícito (Windows PowerShell **5.1**, el mismo
  motor que valida `scripts/validar-powershell.ps1` y que corre dentro de 14393).
- Guest: Alpine v3.21 **netboot**. Solo `vmlinuz-lts` e `initramfs-lts`; ninguna ISO.
- Arranque: `-kernel` / `-initrd` con `console=ttyS0 rdinit=/bin/sh panic=-1`. `rdinit=/bin/sh`
  salta el init de Alpine: no hace falta medio de arranque ni sistema de archivos raíz.
- Comandos: por la entrada estándar, que QEMU conecta a la consola serie. No hay red, no hay SSH.
- Token de éxito: el guest imprime `EXP000_USERSPACE_OK`. Es la única prueba de que llegó a
  espacio de usuario.
- Apagado: el propio guest ejecuta `poweroff -f`. Un **timeout nunca es éxito**; un arranque que
  hubo que matar queda registrado como inestable.
- Dos arranques por job: `-accel whpx` y `-accel tcg`, sin fallback implícito. Si WHPX no está
  disponible QEMU aborta y se registra, en vez de emular en silencio y reportar un éxito que no
  ocurrió.

### La regla de oro: quién decide el veredicto

`invocar-vm.ps1` **no decide nada**. Solo registra hechos: el token apareció, el código de salida,
si hubo timeout, si hubo kernel panic, qué dijo stderr, cuántos segundos tardó.

`consolidar.ps1` es el **único** sitio con la tabla de veredictos.

Esto no es una preferencia de estilo. La primera implementación tenía la tabla duplicada en los
dos sitios, y en el productor la condición de "arranque limpio" estaba **invertida**:
`$arranco -and (-not $salioSolo) -and ($codigo -eq 0)`. Como `WaitForExit` devuelve `$true` cuando
el proceso salió por su cuenta, un apagado correcto se marcaba como inestable y un timeout se
marcaba como limpio. Las pruebas de rama no lo detectaban porque alimentan TSV sintéticos a
`consolidar.ps1` y nunca ejecutan el productor. Una sola tabla, un solo lugar, y pruebas que
prueban la tabla que de verdad corre.

## Comandos utilizados

Workflow: [`../.github/workflows/00-sonda-windows.yml`](../.github/workflows/00-sonda-windows.yml).
Scripts: [`../scripts/exp-000/`](../scripts/exp-000/).

| Paso | Script | Qué mide |
|---|---|---|
| 1 | `entorno.ps1` | OS, build, versión de imagen, CPU, RAM, privilegios, features del hypervisor, `bcdedit`, requisitos de `systeminfo`, disco, red |
| 2 | `preparar.ps1` | Instala QEMU por Chocolatey, comprueba que el binario soporta `whpx` y `tcg`, descarga kernel e initrd de Alpine, crea el qcow2 |
| 3 | `invocar-vm.ps1` | Arranque con `-accel whpx`, captura consola y stderr, cronometra |
| 4 | `invocar-vm.ps1` | Arranque con `-accel tcg`, ídem (plan B y línea base de rendimiento) |
| 5 | `consolidar.ps1` | Aplica la tabla de veredictos, escribe `reporte.json` y el step summary |

Los datos viajan entre pasos en archivos TSV, uno por acelerador. Nada se pasa por
`$GITHUB_OUTPUT`: los valores multilínea —la consola serie completa— se rompen al pasar por ahí.

## Archivos modificados

Ninguno dentro del runner. El job es de solo lectura sobre el sistema, salvo la instalación de
QEMU. Toda la salida queda en `exp-000/` y sube como artifact.

## Resultado esperado y cómo se interpreta

`reporte.json` tendrá este contrato. Los booleanos son booleanos y los números son números: un
`"true"` en cadena o un `0` para "no medido" se perderían en el análisis posterior.

```json
{
  "veredicto": "WHPX_VIABLE | WHPX_ARRANCA_PERO_INESTABLE | SOLO_TCG_ESTABLE | SOLO_TCG_INESTABLE | NINGUN_ACELERADOR_ARRANCA | QEMU_NO_INSTALADO | VM_SIN_DISCO",
  "entorno": {
    "os": "Microsoft Windows Server 2025",
    "build": 26100,
    "cpu": "...",
    "cpu_logicos": 4,
    "ram_mb": 16384,
    "admin": true,
    "feature_HypervisorPlatform": "Disabled | Enabled | null"
  },
  "qemu": { "instalado": true, "version": "...", "soporta_whpx": true, "soporta_tcg": true },
  "arranques": {
    "whpx": { "resultado": "...", "llego_a_userspace": true, "timeout": false, "codigo_salida": 0, "segundos": 12.5 },
    "tcg":  { "resultado": "...", "llego_a_userspace": true, "timeout": false, "codigo_salida": 0, "segundos": 88.2 }
  },
  "guest": { "flag_hypervisor": 1, "flag_vmx": 1, "disco_visible": 1, "kernel": "..." }
}
```

El veredicto se decide con reglas escritas **antes** de ver los datos. Se aplican en orden y la
primera que se cumple gana. Ninguna declara viabilidad sin el token de espacio de usuario.

| Veredicto | Significado | Qué hacer |
|---|---|---|
| `WHPX_VIABLE` | WHPX arrancó y el guest se apagó solo | H0 confirmada. Seguir con el experimento 001 |
| `WHPX_ARRANCA_PERO_INESTABLE` | WHPX llegó a userspace pero quedó colgado | Habrá que diagnosticar estabilidad antes de continuar |
| `SOLO_TCG_ESTABLE` | WHPX no disponible; TCG funciona | H1. Se puede avanzar, pero midiendo el costo de emulación |
| `SOLO_TCG_INESTABLE` | Solo emulación, y además inestable | No sirve para una instalación completa |
| `NINGUN_ACELERADOR_ARRANCA` | Ninguno de los dos llegó a userspace | H2. La arquitectura de `docs/01` se cae; replantear |
| `QEMU_NO_INSTALADO` | Chocolatey no entregó QEMU | Problema de entorno, no de capacidad. Reintentar |
| `VM_SIN_DISCO` | Arrancó pero el guest no vio el qcow2 | Problema de la línea de comandos o del bus, no de aceleración |

`VM_SIN_DISCO` solo se evalúa si alguna VM llegó a userspace. Sin ese dato, `disco_visible` es
`null` y la comprobación taparía la causa real con un síntoma secundario.

## Errores

Se registran textualmente en la salida del paso y en el artifact. El workflow usa
`continue-on-error` en los pasos de sondeo para que un fallo en WHPX no impida probar TCG, y
`if: always()` en la consolidación y en la subida del artifact, para que un paso fallido no borre
la evidencia de los anteriores.

## Evidencia

- Log completo del job.
- `exp-000/reporte.json` y `exp-000/resumen.md` como artifact (30 días).
- `exp-000/sonda/*.tsv`: los datos crudos, sin interpretar.
- `exp-000/sonda/consola-whpx.log` y `stderr-whpx.log`: la consola serie íntegra. Es lo único que
  permite refutar una interpretación posterior.
- Step summary en la UI de Actions.

## Conclusión

A llenar tras la ejecución.

## Siguiente hipótesis

A definir según `veredicto`. La rama de `WHPX_VIABLE` es la única que abre la puerta al
experimento 001 con la arquitectura actual; el resto obliga a revisar [`docs/01`](01-arquitectura-y-viabilidad.md)
antes de gastar más minutos de runner.

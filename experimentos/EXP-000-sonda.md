# EXP-000 — Sonda de capacidades del runner Windows

Estado: **preparado y validado en local. No ejecutado.** Falta que el usuario cree el repositorio
remoto y autentique `gh`.

Detalle completo: [`docs/02-experimento-000-sonda.md`](../docs/02-experimento-000-sonda.md)
Workflow: [`../.github/workflows/00-sonda-windows.yml`](../.github/workflows/00-sonda-windows.yml)
Scripts: [`../scripts/exp-000/`](../scripts/exp-000/)

## Hipotesis

- **H0** QEMU arranca un guest Linux minimo en el runner Windows con **WHPX**, y el guest ve el
  flag `hypervisor` de `/proc/cpuinfo`.
- **H1** WHPX no esta disponible (feature deshabilitada, o el hypervisor anidado no habilitado en el
  grupo de seguridad de la VM del runner) y solo se puede emular con TCG.
- **H2** Ninguno de los dos arranca. La virtualizacion en el runner es inviable.

H0 no implica que quepa Windows 14393: el runner tiene 14 GB de SSD. H0 habilita la investigacion,
no la resuelve.

## Metodo

Un unico job en `windows-latest` con `shell: powershell` (Windows PowerShell 5.1). No descarga
ISOs, no crea VMs de Windows, no habilita features, no reinicia el runner, no toca la maquina del
usuario.

1. identidad del runner: SO, build, version de imagen, CPU, RAM, privilegios
2. estado del hypervisor: features de Windows, `bcdedit`, requisitos de `systeminfo`
3. disco y conectividad
4. instalacion de QEMU por Chocolatey y comprobacion de que soporta `whpx` y `tcg`
5. descarga del kernel e initrd de Alpine netboot y creacion del qcow2
6. **arranque real de una VM minima con `-accel whpx`**, cronometrado
7. la misma VM con **`-accel tcg`**, cronometrado
8. `reporte.json` + tabla en el step summary, subido como artifact

Los pasos 6 y 7 son los que importan. No basta con que la feature `HypervisorPlatform` figure
habilitada: hay que ver que QEMU arranca y que el guest reporta el hypervisor.

### Reparto de responsabilidades

| Script | Decide veredictos | Que hace |
|---|---|---|
| `entorno.ps1` | no | mide el runner |
| `preparar.ps1` | no | instala QEMU, baja el kernel, crea el disco |
| `invocar-vm.ps1` | **no** | arranca y registra **hechos**: token, salida, timeout, panic, stderr, segundos |
| `consolidar.ps1` | **si** | unica tabla de veredictos, escribe `reporte.json` |

La tabla vivia duplicada en `invocar-vm.ps1` y en `consolidar.ps1`, y en el productor la condicion
de arranque limpio estaba invertida. Se unifico en `consolidar.ps1` para que las pruebas de rama
cubran la tabla que de verdad decide.

## Criterio de decision

Escrito **antes** de ver los datos. Se aplica en orden; la primera regla que se cumple gana.

| Veredicto | Condicion | Siguiente paso |
|---|---|---|
| `WHPX_VIABLE` | WHPX llego a userspace y se apago solo | Fase B: construir la imagen base |
| `WHPX_ARRANCA_PERO_INESTABLE` | WHPX llego a userspace pero quedo colgado | Diagnosticar estabilidad antes de avanzar |
| `SOLO_TCG_ESTABLE` | WHPX ausente; TCG llego a userspace y se apago solo | Se puede avanzar, midiendo el costo de emulacion |
| `SOLO_TCG_INESTABLE` | Solo emulacion, y ademas inestable | No sirve para una instalacion completa |
| `NINGUN_ACELERADOR_ARRANCA` | Ninguno llego a userspace | La arquitectura de `docs/01` es invalida. Replantear |
| `QEMU_NO_INSTALADO` | Chocolatey no entrego QEMU | Problema de entorno, no de capacidad. Reintentar |
| `VM_SIN_DISCO` | Arranco pero el guest no vio el qcow2 | Problema de la linea de comandos o del bus, no de aceleracion |

Un timeout nunca cuenta como exito. El criterio de arranque es el token `EXP000_USERSPACE_OK` en
la consola serie, mas el apagado autonomo del guest.

## Validacion en local

Sin ejecutar el job:

- Los cinco `.ps1` pasan el parser de Windows PowerShell 5.1 sin errores de sintaxis.
- Cero construcciones de PowerShell 7 en la logica de EXP-000.
- 17 pruebas de `consolidar.ps1` en verde: 11 ramas de veredicto (incluidas dos de regresion) y 6
  comprobaciones de tipos del contrato JSON.
- El YAML del workflow es parseable y esta en `.github/workflows/`, la unica ruta que GitHub
  ejecuta. El validador falla si aparece un workflow en otra carpeta.

## Evidencia esperada

- `exp-000/reporte.json` y `exp-000/resumen.md` como artifact
- `exp-000/sonda/*.tsv`: datos crudos, sin interpretar
- `exp-000/sonda/consola-{whpx,tcg}.log`: consola serie integra
- tabla legible en el step summary del job

## Resultado

*(a llenar tras la ejecucion)*

## Conclusion

*(a llenar tras la ejecucion)*

## Siguiente

*(a definir segun el veredicto: EXP-001 si es viable, replanteo si no)*

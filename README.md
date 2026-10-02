# LTSB — laboratorio Windows 10 LTSB 2016 (14393) en GitHub Actions

Laboratorio descartable, gratuito y reproducible para investigar **Windows 10 LTSB 2016, build
14393**, con QEMU sobre runners de GitHub Actions, controlado programaticamente por OpenCode.

Dos objetivos de investigacion:

- **A — Dark Mode real en File Explorer.** Determinar si existe una modificacion reproducible.
- **B — AppX / MSIX / Store.** Determinar que tanta Store/modernidad se puede instalar en 14393.

---

## Estado actual

> **Nada se ha ejecutado. Todos los veredictos de este repositorio son documentales, no medidos.**

| Fase | Estado |
|---|---|
| A. Inspeccion del entorno | completada |
| B. Arquitectura y viabilidad | **reabierta** — el veredicto Linux+KVM era documental, no medido |
| C. Investigacion Dark Mode | completada (documental) |
| D. Investigacion AppX/MSIX | completada (documental) |
| E. Diseno de experimentos y control | EXP-000 implementado y validado en local |
| F. Construccion de la imagen base | **via viable definida** — Compact OS desde el inicio para que quepa en 14 GB, o construir una vez fuera y publicar en Releases. `docs/11` §5 |
| G. Ejecucion remota | bloqueada — falta repo y login |

Bloqueos para avanzar:

1. **Ruta de destino — resuelta.** La ruta real es `D:\Users\Darkness\Documents\F22\LTSB`. La unidad `F:`
   no existe en este entorno; todo el material esta en `D:`.
2. **Repositorio.** El remoto no esta configurado. Se necesita un repo **publico** (ver
   `docs/08` R-09: en repo privado el limite de 500 MB de artifacts no alcanza para el `base.qcow2`
   y los 2000 min/mes se agotarian).
3. **Autenticacion.** `gh` no esta instalado y el agente no puede autenticarse. Requiere accion del
   usuario.
4. **ISO 14393.** El usuario la tiene localmente; falta un canal de distribucion troceada
   (`docs/06` §6).
5. **Techo de disco — acotado.** El runner estandar tiene 14 GB de SSD. Windows 10 14393 **no se
   puede construir** dentro del runner (pico ~24 GB), pero **si se puede ejecutar**: la base
   comprimida ocupa ~6.66 GB y entra. `docs/09` lo verifica; `docs/11` §5 propose las dos
   salidas gratuitas para construir la base una vez.
6. **Almacenamiento persistente — resuelto.** Releases de un repo publico no tienen limite
   total de tamano, solo 2 GiB por archivo `[OFICIAL]`. Alli vive la base de la VM, partida en
   4 trozos, y los overlays de estado. Elimina el techo de 10 GB del cache. Ver `docs/11` §2.

---

## Lo que EXP-000 decide

`windows-latest` puede ejecutar una VM con QEMU, y con qué aceleración. WHPX (real) o TCG (emulación).

Este es el primer experimento y no toca Windows 14393: arranca un kernel Linux mínimo de Alpine
netboot, sin ISO, y cronometra. Cuesta minutos y no cuesta un centavo en un repo público.

No decide si 14393 se puede instalar: eso ya se sabe que no, por disco.

---

## Respuestas principales (documentales, pendientes de medir)

**Dark Mode en 14393:** no hay soporte nativo. La funcion se desarrollo en una rama de Insider
posterior y llego a GA en build 1809 (17733/17763). Microsoft nunca la retroporto. La unica via
reproducible y documentada es **tematica**: UltraUXThemePatcher + OldNewExplorer v1.1.8.1 + un tema
compilado especificamente para 14393. Ver `docs/03`.

**MSIX en 14393:** MSIX nativo no tiene soporte antes de 1709. MSIX Core si declara soporte oficial
para `10.0.14393.0`, pero no convierte aplicaciones modernas: las apps del Store publican un
`TargetVersion` de 19041 o 17763, muy por encima de 14393. Si una app no es instalable nativamente en
14393, tampoco lo sera con MSIX Core. Ver `docs/04`.

---

## Documentos

| Archivo | Contenido |
|---|---|
| [`docs/00-estado-inicial-y-alcance.md`](docs/00-estado-inicial-y-alcance.md) | Inspeccion del entorno, discrepancia de ruta, alcance y restricciones |
| [`docs/01-arquitectura-y-viabilidad.md`](docs/01-arquitectura-y-viabilidad.md) | Veredicto de arquitectura, costos, limites, riesgos |
| [`docs/02-experimento-000-sonda.md`](docs/02-experimento-000-sonda.md) | Diseno de EXP-000, la sonda que decide la arquitectura |
| [`docs/03-darkmode-14393.md`](docs/03-darkmode-14393.md) | Objetivo A: cronologia, APIs, vias, descartes |
| [`docs/04-appx-msix-14393.md`](docs/04-appx-msix-14393.md) | Objetivo B: escalera de estados, MSIX Core, tabla de errores |
| [`docs/05-control-por-agente.md`](docs/05-control-por-agente.md) | Como OpenCode opera la VM, contrato de `reporte.json` |
| [`docs/06-reproducibilidad-y-ejecucion.md`](docs/06-reproducibilidad-y-ejecucion.md) | Hashes, artefactos, idempotencia, distribucion de la ISO |
| [`docs/07-registro-de-experimentos.md`](docs/07-registro-de-experimentos.md) | Matriz completa EXP-000..EXP-035 y reglas de disciplina |
| [`docs/08-riesgos-y-limites.md`](docs/08-riesgos-y-limites.md) | 11 riesgos con severidad y mitigacion |
| [`docs/09-verificacion-limite-14-gb.md`](docs/09-verificacion-limite-14-gb.md) | Verificacion del limite de 14 GB: construir 14393 no cabe, ejecutarlo si |
| [`docs/10-veredicto-de-plataforma.md`](docs/10-veredicto-de-plataforma.md) | Veredicto para el objetivo de DOS VMs — **superado por `docs/11`**, se conserva como registro |
| [`docs/11-veredicto-laboratorio-una-vm.md`](docs/11-veredicto-laboratorio-una-vm.md) | **Veredicto vigente:** una sola VM 14393 persistente en GitHub Actions, Releases como almacenamiento y la ISO 21H2 como fuente de extraccion |

## Workflows

Viven en `.github/workflows/`. Es la **única** carpeta que GitHub lee: un workflow en otra ruta no
se ejecuta, sin avisar. `scripts/validar.sh` falla si aparece uno fuera de ahí.

| Archivo | Estado |
|---|---|
| [`.github/workflows/00-sonda-windows.yml`](.github/workflows/00-sonda-windows.yml) | implementado y validado en local, no ejecutado. Mide el runner Windows y arranca una VM mínima con WHPX y con TCG |

## Experimentos con registro

| ID | Asunto | Estado |
|---|---|---|
| [`EXP-000`](experimentos/EXP-000-sonda.md) | Sonda de capacidades del runner Windows | implementado, validado en local, no ejecutado |
| [`EXP-003`](experimentos/EXP-003-winrm.md) | Canal de control WinRM | definido |
| [`EXP-010`](experimentos/EXP-010-darkmode-linea-base.md) | Linea base de dark mode en 14393 | definido |
| [`EXP-030`](experimentos/EXP-030-store-14393.md) | Microsoft Store y cmdlets Appx en 14393 | definido |

## Scripts de validacion

Se ejecutan en el host, sin red, sin lanzar nada del workflow.

```bash
# Todo: YAML de los workflows, bash de cada paso run:, enlaces markdown relativos
bash scripts/validar.sh

# PowerShell de docs/, experimentos/ y scripts/ contra el parser de 5.1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validar-powershell.ps1
```

`validar.sh` además usa `actionlint` y `shellcheck` si están instalados, y los omite con aviso si
no. Solo manda por `bash -n` los pasos cuyo `shell:` es de Unix; los de `powershell` se delegan al
otro validador, que los revisa como PowerShell y no como bash.

`validar-powershell.ps1` parsea los `.ps1` del repo **completos**, no solo los bloques cercados en
Markdown, y marca aparte los **avisos de PowerShell 7**: construcciones como `??`, `-AsByteStream` o
`-Parallel` pasan el análisis sintáctico y fallan en runtime dentro de 14393, que corre 5.1. Por eso
el objetivo de compatibilidad es 5.1 y no 7.x.

## Directorios

```
docs/          documentacion (9 archivos)
.github/       workflows de GitHub Actions (unicamente workflows/)
scripts/       validacion estatica y scripts de EXP-000
experimentos/  registro de cada experimento
resultados/    bitacora de ejecuciones (Markdown, versionada)
logs/          buffer local de evidencia pesada (NO versionado)
imagenes/      capturas locales (NO versionado)
```

---

## Convenciones

**Etiquetado de evidencia** (`docs/00` §5):

| Etiqueta | Significado |
|---|---|
| `[OFICIAL]` | Documentacion de Microsoft, GitHub o el proyecto upstream |
| `[COMUNIDAD]` | Foro, issue, proyecto de terceros. Credible, no autoritativo |
| `[HIPOTESIS]` | Razonamiento propio, sin verificar |
| `[NO ENCONTRADO]` | Se busco y no se hallo. Es un resultado, no una laguna |

**Planos de evidencia**, que se mantienen separados en todo el proyecto:

1. **Declarado** — lo que dice la documentacion.
2. **Implementado** — lo que el codigo realmente hace.
3. **Runtime** — lo que el sistema observa al ejecutarse.

La diferencia entre los tres es el objeto de la investigacion, no ruido. Un ejemplo ya medido: el
ordinal de `DWMWA_USE_IMMERSIVE_DARK_MODE` es **19** en 1809/1903 y **20** en Windows 11, y la
documentacion oficial solo documenta el 20. Un agente que confiaria en la documentacion propondría el
valor equivocado.

**Reglas no negociables:**

1. Ningun veredicto sin un `run-id` que lo respalde.
2. Criterio de decision escrito **antes** de ejecutar.
3. Experimentos refutados se conservan y se citan.
4. `[NO ENCONTRADO]` es un resultado valido.
5. Nada se escribe sobre `base.qcow2`; nada se toca fuera de la VM.
6. Costos de API: cero. Publico o no se hace.

---

## Proximo paso

1. ~~Confirmar la ruta de destino.~~ **Hecho**: `D:\Users\Darkness\Documents\F22\LTSB`.
2. Crear el repositorio publico y configurar el remoto. **Accion del usuario.**
3. `gh auth login`. **Accion del usuario.**
4. Lanzar EXP-000 y registrar el veredicto en `resultados/`.

Detalle en `.planning/2026-10-01-ltcb-lab-remoto-windows10/`.

---

## Estado de la validacion local

| Comprobacion | Resultado |
|---|---|
| YAML de `.github/workflows/00-sonda-windows.yml` | parseable, 6 pasos |
| Workflows fuera de `.github/workflows/` | ninguno |
| `bash -n` de los pasos `run:` con shell Unix | 0 aplicables (los 6 pasos son PowerShell) |
| PowerShell contra 5.1, `.ps1` completos y bloques en Markdown | 10/10 OK, 0 avisos de PS7 |
| Tabla de veredictos de EXP-000 | 17/17 pruebas en verde (11 ramas + 6 tipos de contrato) |
| Enlaces Markdown relativos | 0 rotos |
| Caracteres corruptos (CJK) en el texto | 0 |

Ejecutado el 2026-10-01 con Git Bash 5.x y Windows PowerShell 5.1.19041.3693.

**Esto valida la forma, no el comportamiento.** Ningún workflow se ha ejecutado: que el YAML
parsee no dice nada sobre si WHPX existe en el runner ni sobre si una VM arranca dentro. Eso lo
mide EXP-000.

Tres bugs reales aparecieron al validar, y ninguno se habría visto esperando al job:

1. `Stopwatch.Stop()` se llamaba justo después de `Start-Process`, así que `segundos` medía el
   coste de crear el proceso, no el arranque de la VM.
2. La condición de "arranque limpio" estaba invertida: `WaitForExit` devuelve `$true` cuando el
   proceso salió por su cuenta, y el código usaba `-not $salioSolo`. Un apagado correcto se
   marcaba inestable y un timeout se marcaba limpio.
3. La tabla de veredictos estaba duplicada en `invocar-vm.ps1` y en `consolidar.ps1`, y las dos
   podían discrepar. Ahora solo existe en `consolidar.ps1`, que es lo que las pruebas cubren.

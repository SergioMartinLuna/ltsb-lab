# 09 — Verificación del límite de 14 GB frente a Windows 10 14393

Estado: **verificación local, sin ejecución remota.** Ningún número de este documento
procede de un runner real. La arquitectura de `docs/01` **no se modificó** como parte de
este trabajo; la sección 8 lista las correcciones que quedan pendientes y por qué.

---

## 1. Qué se verifica y qué no

La afirmación que sesomete a prueba es la de `docs/01:171-173` y `docs/01:350-351`:

> «Windows 10 14393 no se puede instalar dentro del runner, ni en Windows ni en Linux:
> no cabe en 14 GB. Esto no es un problema de aceleración y no lo resuelve ninguna
> arquitectura de construcción local.»

Se descompone en dos afirmaciones que este documento separa, porque tienen valores
completamente distintos:

| # | Afirmación | Veredicto |
|---|---|---|
| A1 | **Construir** 14393 dentro del runner no cabe en 14 GB | **Se sostiene**, por un motivo distinto al que se daba |
| A2 | **Ejecutar** 14393 en el runner no cabe en 14 GB | **No se sostiene** tal como estaba formulada |

La confusion entre A1 y A2 es la raiz del error. Son problemas de disco distintos.

---

## 2. El error de encuadre

El cálculo anterior comparaba:

```
'Windows instalado ocupa 20 GB (Microsoft) > 14 GB'  =>  NO CABE
```

Eso es inválido por dos motivos independientes, y ambos hay que corregir aunque se
arreglara solo uno.

### 2.1 Atribución falsa a Microsoft

Los 20 GB no vienen de Microsoft. Vienen de la metadata de Internet Archive para el ítem
de LTSB 2016, que reproduce los requisitos de instalación del propio medio:

> `Disk space: 16 Gb of free space (32-bit) or 20 Gb (64-bit)`

Esa metadata es `[COMUNIDAD]`. `docs/01:171-172` ya lo entrecomillaba como si fuera
Microsoft, y el comentario no lo frenó.

### 2.2 Categoría equivocada: espacio libre ≠ ocupación física

El 20 GB es **espacio libre requerido**: una comprobación de *capacidad lógica* que hace
Setup antes de instalar. No es la ocupación física del sistema ya instalado. Son dos
magnitudes distintas y la comparación las trataba como la misma.

La cifra que sí es de Microsoft, y que es de la **misma build** (Windows 10 version 1607
= build 14393 = LTSB 2016), está en la tabla *Size comparisons* de la documentación de
Compact OS:

| Configuración | Footprint x64 |
|---|---|
| Base footprint (sin compact) | 15.06 GB |
| Compact OS | 11.30 GB |
| **Compact OS + single instancing** | **10.09 GB** |
| Sin `hiberfil` | 13.48 GB |
| Sin `hiberfil`, reducido | 14.15 GB |

El footprint real de 14393 es ~10.09 GB, no 20 GB. El veredicto «no cabe» se apoyaba en
una cifra que nunca se midió.

---

## 3. Los cinco conceptos que no se deben mezclar

ElStorage del runner son 14 GB. Lo que gasta ese storage es **una sola cosa**: el tamaño
físico de los ficheros. Todo lo demás es otra magnitud.

| Concepto | Qué es | Compite por los 14 GB |
|---|---|---|
| (a) Tamaño lógico | Lo que ve el guest. `qemu-img create -f qcow2 base.qcow2 32G` | No |
| (b) Tamaño físico | Bytes que ocupa el fichero en el host | **Sí, es lo único** |
| (c) Espacio temporal | Pico de coexistencia durante la instalación | **Sí, pero solo mientras dura** |
| (d) RAM | Lo que se asigna con `-m` | No, va a la columna `Memory (RAM)` |
| (e) Storage del runner | Los 14 GB garantizados | Es el presupuesto |

Un qcow2 vacío de 32 GB lógicos ocupa ~200 KB. `qemu-img info` reporta `virtual size` y
`disk size` por separado precisamente porque no son lo mismo.

**Los 14 GB** son la columna `Storage (SSD)` de la tabla de runners estándar públicos, y
son un recurso independiente de los otros tres de la misma tabla:

| Recurso | Valor | Fuente |
|---|---|---|
| vCPU | 4 | `[OFICIAL]` tabla de runners |
| Memory (RAM) | 16 GB | `[OFICIAL]` misma tabla, columna aparte |
| **Storage (SSD)** | **14 GB** | `[OFICIAL]` misma tabla, columna aparte |
| Timeout de job | 360 min | `[OFICIAL]` misma tabla |

`docs/01:95` ya listaba los tres correctamente. El error no estaba en la tabla de
recursos: estaba en la comparación posterior.

---

## 4. Presupuesto cuando la imagen ya está construida

Este es el escenario que la arquitectura ya contemplaba (`docs/01:317`, base publicada como
Release). La imagen no se construye en el runner, así que el pico temporal de la
sección 5 no aplica y (c) desaparece del presupuesto.

| Concepto | GB | Estado |
|---|---|---|
| QEMU instalado | 2.0 | `[EST]` — ver 4.1 |
| ISO de virtio | 0 | `[OFICIAL]` — 14393 no la necesita, ver C6 |
| `base.qcow2` comprimido | 6.66 | derivado, ver 4.2 |
| Overlay por experimento | 0.5 | `[EST]` |
| Holgura iOS | 1.0 | `[EST]` |
| **Total** | **10.16** | |
| Disponible | 14.0 | `[OFICIAL]` |
| **Holgura** | **3.84** | |

El desglose de `base.qcow2`:

```
10.09 GB  footprint compact+single   [OFICIAL] Microsoft, 1607 x64
x 0.60    ratio de compresión zlib   [EST]
x 1.10    partición + tabla + slack  [EST]
= 6.66 GB
```

### 4.1 Sobre el 2.0 GB de QEMU

`[OFICIAL]` El instalador `qemu-w64Setup-*.exe` mide 197 MB comprimido. El **tamaño
instalado es otra magnitud** y no se ha medido en esta verificación. Se toman 2.0 GB
como margen holgado, no como dato. La sección 5 prueba que el veredicto no depende de
este número.

### 4.2 Sobre el ratio 0.60

`[EST]` Es la única estimación con peso real en el presupuesto. Compact OS ya comprime
los datos del SO, así que zlib rinde **peor** que sobre datos crudos; 0.60 es
conservador frente a los ratios de 0.40–0.55 que se observan en la práctica. La sección 5
varía esta cifra hasta 0.70.

---

## 5. Sensibilidad: cuánto margen aguanta el plan

El veredicto se apoya en dos estimaciones. Se varía una a una.

**Ratio de compresión** (QEMU fijo en 2.0 GB):

| Ratio | Base | Total | Holgura |
|---|---|---|---|
| 0.40 | 4.44 GB | 7.94 GB | 6.06 GB |
| 0.55 | 6.10 GB | 9.60 GB | 4.40 GB |
| 0.70 | 7.77 GB | 11.27 GB | 2.73 GB |

**QEMU instalado** (ratio fijo en 0.60):

| QEMU | Total | Holgura |
|---|---|---|
| 1.0 GB | 9.16 GB | 4.84 GB |
| 2.0 GB | 10.16 GB | 3.84 GB |
| 3.0 GB | 11.16 GB | 2.84 GB |

En el peor caso combinado (ratio 0.70 **y** QEMU 3.0 GB) el total sigue entrando. El
plan no es frágil frente a estas dos incertidumbres.

**El único escenario que rompe el plan es no comprimir la base:**

```
sin compresión: 10.09 x 1.10 = 11.10 GB de base, y solo eso ya consume
el presupuesto sin QEMU, sin overlay y sin holgura.
```

Por eso `convert -c` no es una optimización: es un requisito del diseño.

---

## 6. El pico de construcción — por qué A1 sí se sostiene

Si la imagen se construye dentro del runner, en el mismo instante coexisten:

| Concepto | GB | Estado |
|---|---|---|
| ISO 14393 x64 en-US | 3.3 | `[COMUNIDAD]` metadata de archive.org |
| Destino creciendo | 15.06 | `[OFICIAL]` footprint 1607 x64 base |
| WinSxS + scratch + pagefile | 3.0 | `[EST]` |
| QEMU instalado | 2.0 | `[EST]` |
| Holgura de particiones | 1.0 | `[EST]` |
| **Pico** | **24.36** | |

No cabe en 14 GB, y tampoco en los ~33 GB reales que se observaron en `windows-2025`.

**Pero el motivo es construir, no 14393.** La afirmación correcta es:

> Construir 14393 dentro del runner no cabe, porque el pico de instalación multiplica
> la ISO por el destino por los temporales. Esto se resuelve construyendo la imagen
> fuera y publicándola, que es lo que la arquitectura ya proponía.

La afirmación original atribuía el fallo a la build, y de ahí salía la conclusión
contradictoria de que «ninguna arquitectura de construcción local resuelve esto».

---

## 7. Condiciones bajo las cuales entra

Todas necesarias, todas verificables:

| # | Condición | Por qué |
|---|---|---|
| C1 | La imagen se construye **fuera** del runner y se publica como Release | Elimina el pico de la sección 6. Ya estaba en el diseño |
| C2 | Compact OS + single instancing | 15.06 → 10.09 GB. `[OFICIAL]` |
| C3 | `qemu-img convert -c` para la base | Sin esto el plan no entra, ver sección 5 |
| C4 | `powercfg /h off` y pagefile de 256 MB | `[OFICIAL]` el pagefile escala con la RAM |
| C5 | `DISM /StartComponentCleanup` y `/ResetBase` antes de exportar | Reduce WinSxS; hace la imagen no reversible, aceptable en laboratorio |
| C6 | i440fx + IDE/AHCI + e1000e | 14393 arranca sin drivers virtio, así que no hace falta la ISO de virtio |
| C7 | Base inmutable + overlay descartable | El backing file se trata como solo lectura |
| C8 | Se publica el overlay como artifact, no la base | Los 500 MB de artifact no aceptan la base, ver `docs/08:148` |

**C3 y C7 verificadas contra fuente.** La compresión de clusters en qcow2 la aplica
`qemu-img convert`; QEMU no escribe clusters comprimidos durante el uso normal de una VM
en ejecución. Por eso una base comprimida se usa como *backing file* de solo lectura y
el overlay escribe sin comprimir. No es una convención, es la semántica del formato.

**Lo que no hace falta:** cumplir los 20 GB de espacio libre. Con un disco lógico de
12–16 GB 14393 arranca, porque el footprint real es ~10 GB. Ese 20 GB es un piso de
soporte, no un límite mecánico. Desviarse de él es defendible: el objetivo es un
laboratorio de pruebas, no un equipo en producción. Lo que sí debe respetarse es el
mínimo mecánico de la partición NTFS, muy inferior a 20 GB.

---

## 8. Lo que esta verificación deja sin medir

Declarado por separado para no confundirlo con lo verificado:

| Pendiente | Por qué importa |
|---|---|
| Footprint instalado real de QEMU | Es `[EST]`, no medido. La sección 5 muestra que no cambia el veredicto |
| Tamaño físico real de `base.qcow2` comprimido | El 5–8 GB documentado sigue siendo `[ESTIMADO]`, sin medir |
| Tamaño real de la ISO del usuario | 3.3 GB corresponde al SKU en-US x64 de archive.org. El archivo local no ha sido localizado ni medido |
| Espacio libre real del runner | Los 14 GB son un compromiso, no una medición. La realidad vista en `windows-2025` fue ~33 GB |
| Si 14393 arranca efectivamente con 10 GB y QEMU TCG | Ortogonal al disco; lo decide EXP-000 |

**Ningún número de este documento proviene de una ejecución.** El único dato de runtime
que se cita, los ~33 GB en `windows-2025`, viene de la observación documentada en
`docs/01:162-164`, no de una medición de esta sesión.

---

## 9. Correcciones pendientes en la arquitectura

**No aplicadas**, conforme a la instrucción de no modificar la arquitectura durante esta
verificación. Se listan para que la corrección sea deliberada y no un efecto colateral:

| Ubicación | Afirmación actual | Corrección que corresponde |
|---|---|---|
| `docs/01:23` | «no cabe, ni bajo KVM ni bajo TCG» | Solo vale para *construir*, no para *ejecutar* |
| `docs/01:160` | El storage de 14 GB es un problema **real** | El dato es real; el carácter de problema depende del escenario |
| `docs/01:171-173` | 20 GB atribuidos a Microsoft | Atribución a metadata comunitaria, y categoría: espacio libre requerido ≠ ocupación física |
| `docs/01:187` | «❌ no cabe: 14 GB de disco» en ambas filas | Sustituir por la distinción construir / ejecutar |
| `docs/01:189-191` | La instalación no cabe en ninguno de los dos runners | Reencuadrar: el pico de construcción no cabe; la ejecución sí cabe bajo C1–C8 |
| `docs/01:348-352` | 14 GB como techo duro, no construible | Corregir: 14 GB es el piso garantizado; el límite real es el pico de 24.36 GB de la sección 6 |
| `docs/02:28` | «no entra ni de lejos» | Impreciso, no falso: un 14393 con Compact OS **sí** entra, y la holgura es de 3.84 GB |
| `docs/08:28-40` | R-02, severidad alta, impacto «ISO + base no caben» | Reencuadrar: lo que rompe es el **pico de construcción**, no la ejecución. La severidad sigue siendo alta, pero por el motivo de la sección 6 |

Dos hallazgos adicionales que la verificación deja a la vista:

- **`docs/02:50` se sostiene tal como está.** Dice «un Windows 14393 *completo* no cabe en
  14 GB», y es cierto: sin Compact OS el footprint es 15.06 GB. No hay que tocarlo. La
  distinción entre «completo» y «minimizado» es exactamente la que faltaba explicitar en
  el resto del corpus.
- **`docs/01` se contradice a sí mismo.** En `docs/01:350-352` afirma que 14393 no cabe
  por disco y que «ninguna arquitectura de ejecución» lo resuelve; en
  `docs/01:353-354`, cuatro líneas más abajo, concluye que la pregunta relevante es
  precisamente «¿construyo `base.qcow2` fuera del runner y la publico como release?». El
  documento ya había llegado a la respuesta correcta mientras su propio cuerpo
  afirmaba lo contrario. La corrección es reconciliar texto existente, no elegir
  arquitectura nueva.

`docs/08:148` y `docs/01:256` (`qcow2 comprimido ~5-8 GB [COMUNIDAD]`) se sostienen: el
límite de 500 MB de artifact para un repo privado es real, y la estimación 5–8 GB
sigue siendo `[COMUNIDAD]`, ahora con el rango de sensibilidad de la sección 5 acotado.

---

## 10. Fuentes

| Dato | Fuente | Estado |
|---|---|---|
| 4 vCPU, 16 GB RAM, 14 GB SSD, 360 min | https://docs.github.com/actions/reference/runners/github-hosted-runners | `[OFICIAL]` |
| Footprint 1607 x64 (10.09 / 15.06 GB) | https://learn.microsoft.com/windows-hardware/manufacture/desktop/compact-os | `[OFICIAL]` |
| Semántica qcow2: `virtual size` ≠ `disk size` | https://www.qemu.org/docs/master/interop/qcow2.html | `[OFICIAL]` |
| Compresión de clusters solo en `convert`, lectura en runtime | https://man7.org/linux/man-pages/man1/qemu-img.1.html | `[OFICIAL]` |
| Instalador QEMU 197 MB | https://qemu.weilnetz.de/w64/ | `[OFICIAL]` |
| ~33 GB reales en `windows-2025` | https://github.com/actions/runner-images/issues/12609 | `[COMUNIDAD]` |
| 3.3 GB, 20 GB espacio libre requerido | https://archive.org/details/en_windows_10_enterprise_2016_ltsb_x64 | `[COMUNIDAD]` |

---

## 11. Reproducción de la aritmética

Todo el cálculo de las secciones 4 a 6 es aritmética explícita sobre las cifras de la
sección 10 y las estimaciones marcadas `[EST]`. No hay nada oculto ni ajustado a
medida. Para recalcularlo basta con sustituir los valores `[EST]` por los medidos cuando
existan; la estructura del presupuesto no cambia.

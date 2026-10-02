# Veredicto de plataforma — dos VMs Windows (14393 + 19044) a costo cero

Fecha de la investigación: 2026-10-02. Fase: verificación documental y de capacidad.
Sin ejecución remota, sin autenticación, sin commit, sin push.

## VEREDICTO DE PLATAFORMA

**Ninguna plataforma remota y estrictamente gratuita puede sostener DOS VMs Windows
simultáneas, persistentes y aceleradas. El cuello de botella no es la virtualización
anidada: es el almacenamiento físico, con dos cuellos medibles e independientes.**

| # | Cuello de botella | Déficit |
|---|---|---|
| 1 | Disco efímero del runner: `14 GB` vs. **~14.7 GB** de bases qcow2 comprimidas | ~0.7 GB, y ~4–6 GB realista contando QEMU, overlays y logs |
| 2 | Cache persistente: `10 GB`/repo vs. **~14.7 GB** necesarios para dos bases | **~4.7 GB** |

RAM (`16 GB`) y CPU (`4 vCPU`) **sí alcanzan** para dos VMs. No son el límite.

La virtualización anidada en GitHub-hosted runners no es el descarte: es *"técnicamente
posible… no soportada oficialmente, experimental, a riesgo propio"* `[OFICIAL]`. Es decir,
**técnicamente viable y legalmente gratuito, pero inestable por diseño**. El veredicto no
descarta GitHub Actions por la virtualización, sino por el disco.

---

## 1. Corrección de una afirmación anterior

En el resumen previo esta frase estaba etiquetada `[OFICIAL]`:

> "While nested virtualization is technically possible while using runners, it is not
> officially supported."

**Verificación:** el texto es literal y oficial, pero **no aparece en la página canónica
actual** `actions/reference/runners/github-hosted-runners`. Aparece en rutas heredadas
(`actions/using-github-hosted-runners/about-github-hosted-runners`), en
`enterprise-cloud@latest/actions/concepts/runners/github-hosted-runners` y en el
contenido fuente `github/docs`.

La página canónica actual solo afirma, para arm64 macOS:

> "Nested-virtualization is not supported due to the limitation of Apple's Virtualization
> Framework."

**Lectura correcta:** la advertencia existe y es oficial, pero su presencia en la
documentación vigente es ambigua `[OFICIAL, ubicación discreta]`. No puede citarse como
norma vigente sin indicar la ruta. Esto corrige el resumen anterior, que la presentó como
norma activa.

## 2. Las tres (cuatro) magnitudes de disco, separadas

El error de fondo de EXP-000 fue tratar "14 GB" como si fuera el tamaño del laboratorio.

| Magnitud | Valor | Etiqueta |
|---|---|---|
| 1. Footprint instalado del SO (invitado) | 14393 Compact OS + single-instancing: **10.09 GB** | `[OFICIAL]` tabla Windows 10 x64 4 GB RAM, versión 1607 |
| | 19044: sin tabla oficial de tamaño | `[NO ENCONTRADO]` |
| 2. Tamaño lógico del disco virtual | el que se aprovisione; p. ej. 32 GB sparse | `[EST]` |
| 3. Tamaño **físico** en el host | ≈ 0.5–0.66 × footprint para imagen limpia | `[EST]`; 6.66 GB usado en `docs/09` |
| 4. **Pico de construcción** | requiere ISO + WinPE + destino ≈ **24.36 GB** | `[EST]` medido en `docs/09` |

Nunca confundir 1 con 3, ni 3 con 4.

### 2.1 Footprint de 19044 — dato que sigue faltando

Compact OS **está soportado** en Windows 10 Enterprise LTSC 2021 `[OFICIAL]` (documentación
IoT de Microsoft), pero Microsoft **no publica tabla de tamaños** para 19044. La tabla
existente es solo de 1607. Cualquier cifra para 19044 es `[EST]`.

**Método de medición sin Red ni pago:** montar la ISO en el host (hay 313.6 GB libres en
`S:`), instalar en un disco virtual, y leer `DISM /Online /Get-ReservedStorageState` +
`compact /compactos:query` + `Get-Volume`. Requiere elevación, que el agente no tiene.

## 3. Aritmética de los dos cuellos de botella

Suposiciones: base 14393 = 6.66 GB físicos `[EST]`; base 19044 = 8.0 GB físicos `[EST]`;
QEMU instalado ≈ 0.5–1 GB `[EST]`; overlay por VM 0.5–2 GB `[EST]`.

### Cuello 1 — simultaneidad en un solo job

```
base 14393              6.66 GB
base 19044              8.00 GB
QEMU (paquete ubuntu)  ~1.00 GB
overlays (2)            1.00 GB
logs/artifacts          0.20 GB
                        ─────────
necesario              ~16.9 GB
disponible              14.00 GB   [OFICIAL]
                        ─────────
déficit                 ~2.9 GB
```

Aunque se eliminara QEMU y los overlays, las dos bases solas (`~14.7 GB`) ya superan
`14 GB`. **La simultaneidad es aritméticamente imposible, no marginal.**

### Cuello 2 — persistencia entre jobs

El disco del runner es efímero. Fuentes de persistencia gratuitas en GitHub:

| Fuente | Límite | Etiqueta |
|---|---|---|
| Artifacts | **500 MB** (plan Free) | `[OFICIAL]` |
| Cache | **10 GB** por repositorio; eviction a los **7 días** sin acceso; **excedente se factura** | `[OFICIAL]` |
| Releases | almacenamiento no facturado en repos públicos; límite por archivo | `[OFICIAL]` parcial, `[POR MEDIR]` el límite por archivo |
| Repository | solo código; no apto para discos | — |

El excedente de cache **se factura a `$0.07 USD`/GB/mes** `[OFICIAL]`. Bajo la restricción
de costo cero, 10 GB es un **techo duro**, no negociable.

```
necesario para dos bases persistentes   ~14.7 GB
cache gratuita por repositorio          10.0 GB   [OFICIAL]
                                        ─────────
déficit                                 ~4.7 GB
```

## 4. Evaluación por plataforma

| Plataforma | $0 | Aceleración | Persistencia | 2 VMs simultáneas | Veredicto |
|---|---|---|---|---|---|
| GitHub Actions (público) | sí `[OFICIAL]` | KVM en Linux; anidado no soportado `[OFICIAL]` | solo vía cache/release, tope 10 GB | **no** (disco) | **descartada** |
| GitHub Codespaces | no (cuota) | — | sí | no (host Linux) | descartada |
| OCI Always Free (A1) | sí `[OFICIAL]` | no | sí | no | descartada |
| Azure Pipelines | ~10 GB/mes | no oficial | efímera | no | descartada |
| AWS / GCP free tier | crédito inicial | no | sí | no | descartada |
| Ubicloud | $2.5 créditos `[COMUNIDAD]` | KVM | efímera por job | no | descartada |
| **Host local del usuario** | **sí** | **VT-x + SLAT presentes** `[OFICIAL]`+medido | **disco real, 313.6 GB libres** | **posible** | **única candidata** |

### Razones de descarte, una por una

**OCI Always Free — tres fallos independientes.** La shape `A1.Flex` Always Free es
**ARM Ampere Altra** `[OFICIAL]`: no puede ejecutar invitados Windows x86. Segundo: BYOL de
Microsoft **no está disponible en Free Tier ni en tenancy de prueba** `[OFICIAL]`; las
imágenes Windows de OCI usan licencias provistas por OCI, que tienen costo. Tercero: la
virtualización anidada no está disponible en las shapes Always Free. No hay forma de
obtener un Windows x86 con licencia incluida a costo cero.

**Codespaces.** No ofrece host Windows; el contenedor de desarrollo es Linux. Un invitado
Windows x86 sobre Linux sin aceleración utilizable no cumple el propósito de
experimentación real.

**Azure Pipelines.** Los agentes hospedados de Windows son efímeros por diseño y anidado
solo vía rutas no soportadas. No hay persistencia entre jobs.

**AWS / GCP.** Los niveles gratuitos no ofrecen virtualización anidada. Los créditos
iniciales son finitos y su expiración rompe la premisa de costo cero sostenido.

**Ubicloud.** `[COMUNIDAD]` crédito de $2.5/mes y 1.250 min de runner. La máquina es
efímera por job y el IPv4 público cuesta $3/mes `[COMUNIDAD]`. No hay base persistente.

## 5. La opción que sí sobrevive: el host local

Medido en esta sesión, no documentado:

| Atributo | Valor | Etiqueta |
|---|---|---|
| SO del host | **Windows 10 Enterprise LTSC 2021, build 19044** | medido |
| CPU | Intel Celeron N4020, 2 núcleos / 2 hilos | medido |
| VT-x en firmware | **Sí** | medido |
| SLAT | **Sí** | medido |
| VM Monitor Mode | **Sí** | medido |
| DEP disponible | **Sí** | medido |
| RAM | **7.8 GB** | medido |
| Disco libre | `C:` 28.3 · `D:` 72.5 · **`S:` 313.6** · `X:` 139.8 GB | medido |
| Hyper-V instalado | **no** (`vmcompute`/`vmms`/`hns` ausentes) | medido |
| QEMU instalado | no | medido |

El host cumple los cuatro requisitos oficiales de Hyper-V para Windows 10 **Pro o
Enterprise** `[OFICIAL]`. QEMU con `-accel whpx` sobre `HypervisorPlatform` no es
virtualización anidada: el invitado corre directamente sobre el hipervisor de Windows, sin
capa intermedia inestable. El backend WHPX de QEMU está probado desde Windows 10 2004
`[OFICIAL]`; el host es 19044, muy por encima.

**Lo que le falta, con precisión:**

1. **No es remoto.** El laboratorio corre en la máquina del usuario. El agente lo opera
   igual (QEMUMonitor vía script), pero no hay acceso desde otro lugar sin abrir RDP al
   host, que es una decisión de seguridad que corresponde al usuario.
2. **RAM es el techo real.** 7.8 GB para dos invitados Windows. A 2 GB por invitado quedan
   ~3.8 GB para el host, que ya ejecuta 19044. Funciona en el papel; en la práctica el
   Celeron N4020 de 2 núcleos va a hacer la experimentación painfully lenta.
3. **Conflicto conocido:** con el rol Hyper-V completo habilitado, WHPX puede fallar con
   `WHPX: No accelerator found` `[COMUNIDAD]`. Hay que habilitar solo `HypervisorPlatform`,
   no `Microsoft-Hyper-V-All`.
4. El agente **no tiene elevación**, así que no pudo confirmar el estado de las features
   opcionales ni instalar QEMU.

### 5.1 Una asimetría que reduce el problema a la mitad

El host **ya es** Windows 10 Enterprise LTSC 2021 build 19044 — exactamente la segunda VM
del objetivo. Esto significa que **no hace falta virtualizar 19044**: se puede usar el host
como la máquina LTSC 2021 y virtualizar solo 14393 con QEMU/WHPX.

**Advertencia seria:** usar el host como máquina de experimento implica que los experimentos
lo modifican (registro, `explorer.exe`, `uxtheme.dll`, componentes Store/MSIX). Eso destruye
la línea base del host y contamina el propio entorno del agente. Solo es aceptable si el
host es descartable o si se restaura con una imagen. **Debe decidirlo el usuario, no
asumirlo.**

## 6. Arquitectura más cercana al objetivo

Con la restricción de costo cero intacta, la mejor arquitectura posible es:

**Opción A — GitHub Actions, dos VMs alternadas con discos en Releases (gratis).**

```
por cada job (dura minutos, muy por debajo del tope de 6 h [OFICIAL]):
  1. descargar del Release los trozos de la base comprimida → ensamblar
  2. crear overlay qcow2 sobre la base   (el overlay es el estado descartable)
  3. arrancar 1 invitado con -accel kvm
  4. ejecutar el experimento
  5. subir el overlay como artifact (< 500 MB) y el log
  6. bajar la base a la Free tier para que nunca haya dos bases en cache
```

**Cumple:** costo cero `[OFICIAL]`, Windows 14393 real, overlays = "volver a un estado
anterior" mediante `qemu-img create -b`, automatización total por API, base versionada en
Releases.

**Le falta, con la capacidad concreta:**

| Capacidad faltante | Cantidad |
|---|---|
| Simultaneidad de las dos VMs | 2 → **1**. Falta ~2.9 GB de disco. |
| Cache persistente de dos bases | 10 GB → ~14.7 GB. Falta **~4.7 GB**. |
| Aislamiento | ninguno; cualquier `push` a una rama con acceso dispara código. |
| Estabilidad | anidado no soportado oficialmente; sin SLA. |
| Archivos de disco dentro del repo | no aplica: van a Releases, fuera de Git. |

**Opción B — host local con una sola VM virtualizada (14393) y el host como 19044.**

**Cumple:** costo cero real, disco de 313.6 GB, persistencia nativa, snapshots de QEMU,
aceleración WHPX estable (no anidada), control total por script.

**Le falta:** simultaneidad limpia (el host se convierte en la VM 19044, no una VM
separada), y `2 núcleos / 7.8 GB RAM` limitan el rendimiento de forma severa.

## 7. Veredicto por criterio, uno por uno

| Criterio exigido | GitHub Actions | Host local |
|---|---|---|
| Costo estrictamente cero | **sí** `[OFICIAL]` | **sí** |
| Dos VMs Windows | una de cada build | una virtualizada + el host |
| **Simultáneas** | **no** — falta ~2.9 GB | posible, lento |
| Discos persistentes | vía Releases; cache limitado a 10 GB | **sí**, nativo |
| Aceleración real | KVM, no soportada oficialmente | WHPX, estable |
| Snapshots / volver atrás | overlays | overlays + snapshots |
| Timeout | 6 h por job `[OFICIAL]` | ninguno |
| ISO externa y discos fuera de Git | sí | sí |
| Controlable por el agente | **sí**, total | **sí**, total |
| Remoto | sí | **no** |

## 8. Qué hay que decidir antes de seguir

1. **¿Se acepta perder la simultaneidad?** Si sí, la Opción A es viable hoy y gratis.
2. **¿Se acepta que el laboratorio sea local en vez de remoto?** Si sí, la Opción B cumple
   casi todo con recursos reales, y el cuello pasa a ser el Celeron de 2 núcleos.
3. **¿El host es descartable?** Si se va a usar como VM 19044, hay que aceptar que los
   experimentos lo destruyan, o restaurarlo desde imagen.
4. **¿Se autoriza elevar privilegios en el host?** Sin elevación no se puede habilitar
   `HypervisorPlatform`, instalar QEMU, ni medir el footprint de 19044.

Ninguna de estas cuatro respuestas se puede inferir. Cada una cambia el veredicto.

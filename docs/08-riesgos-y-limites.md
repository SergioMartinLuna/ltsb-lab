# 08 — Riesgos y limites

Estado: **analisis. Ningun riesgo de esta lista ha sido materializado todavia.**

Registro explicito de lo que puede salir mal, con severidad y mitigacion concreta. Un riesgo sin
mitigacion escrita es un riesgo que se descubre a las 3 de la manana.

---

## 1. Riesgos de arquitectura

### R-01: `/dev/kvm` no existe en el runner Linux — **Severidad: critica**

**Impacto:** toda la arquitectura de `docs/01` se cae. QEMU cae a TCG, y la instalacion de Windows
baja de minutos a horas o directamente no cabe en el limite del job.

**Probabilidad:** baja. El changelog oficial de GitHub confirma aceleracion por hardware en runners
Linux. Pero "confirmado para Android" no es lo mismo que "confirmado para ubuntu-latest hoy".

**Mitigacion:** EXP-000 existe precisamente para esto, y es el primer experimento por ese motivo.
Es de bajo costo y decide el rumbo de todo lo demas.

**Si falla:** replantear. La unica alternativa dentro de costo cero es un runner Linux distinto
(`ubuntu-24.04` en vez del `-latest`) o un runner self-hosted, que ya no seria gratis.

---

### R-02: Espacio insuficiente tras limpiar — **Severidad: alta**

**Impacto:** la ISO (4-5 GB) mas el `qcow2` base (10-15 GB) no caben en los ~33 GB disponibles
tras limpiar.

**Probabilidad:** media. El precedente de GitHub construye imagenes Windows en `ubuntu-latest`
así que hay evidencia de que cabe, pero justo al limite.

**Mitigacion:** EXP-000 mide el espacio real antes y despues de limpiar. La limpieza del workflow
replica la del precedente conocido.

**Si falla:** trocear tambien la ISO durante la instalacion (montar por partes), o construir el base
en un job y subirlo a Release antes de cada experimento.

---

### R-03: La imagen del runner cambia sin aviso — **Severidad: media**

**Impacto:** un resultado obtenido en una imagen no se reproduce en otra. Un `ubuntu-latest` de
octubre puede ser distinto de uno de noviembre en kernel, QEMU y herramientas.

**Probabilidad:** alta a mediano plazo. Es el comportamiento normal de las imagenes hospedadas.

**Mitigacion:** pinear `runs-on: ubuntu-24.04` en vez de `ubuntu-latest` una vez que EXP-000 diga
que esa imagen funciona. Renunciar a las actualizaciones automaticas a cambio de reproducibilidad es
el trade correcto para un laboratorio.

**Coste de la mitigacion:** si esa imagen deja de recibir imagenes de seguridad, el laboratorio queda
con un runner viejo. Riesgo aceptado y anotado: el contenido del proyecto es Windows 14393, que ya
esta fuera de ciclo; un runner Linux viejo es un problema menor que un resultado irreproducible.

---

### R-04: Nested virtualization en runner Windows podria funcionar — **Severidad: baja (impacto alto)**

**Impacto:** si la restriction de nested virtualization resultara ser un limite de documentacion y
no una restriccion tecnica, la eleccion de Linux habria sido innecesaria.

**Probabilidad:** baja. La documentacion de GitHub es explicita en que no esta soportada para
Windows hosted runners, y `Hyper-V` requiere nested virtualization que no se expone.

**Mitigacion:** EXP-000 tambien reporta `hypervisor_flag` y `vmx|svm` en `/proc/cpuinfo`, que da
evidencia indirecta sobre el estado de virtualizacion. Si el runner Linux resulta no tener flags de
virtualizacion expuestos, la pregunta queda genuinamente abierta y vale la pena reevaluar.

**Nota:** esto es un ejemplo de por que la regla "no trates lo declarado como prueba" importa. La
documentacion es fuerte evidencia, no prueba.

---

## 2. Riesgos de la investigacion tematica

### R-05: Windhook no soporta 14393 — **Severidad: media**

**Impacto:** EXP-020 falla, y la via limpia de dark mode se cae.

**Probabilidad:** media-alta. No hay evidencia de version minima declarada. La discusion oficial
trata de builds modernos.

**Mitigacion:** EXP-021 (la via de comunidad documentada) es independiente. Si Windhawk falla, queda
la ruta del patcher.

---

### R-06: El parcheo de DLL rompe el shell de forma irrecuperable — **Severidad: alta**

**Impacto:** pantallas negras, errores de driver, BSOD. En una VM sin GPU emulada esto es
particularmente probable, porque el sistema depende del driver de video de Microsoft.

**Probabilidad:** media-alta. Hay reportes de usuarios en foros de exactamente esto.

**Mitigacion, en capas:**
1. Solo dentro del overlay descartable. `base.qcow2` nunca se toca.
2. Snapshot de disco antes de parchear, si el experimento dura mas de un paso.
3. El experimento está diseñado para que un BSOD sea un **resultado**, no un incidente: el job
   termina, se registra el estado, y el siguiente experimento empieza limpio.
4. `-no-reboot` y captura de pantalla en el paso previo permiten distinguir "se rompió" de
   "se reinició".

**Este riesgo es precisamente la razón por la que existe un laboratorio descartable.** Sin VM
descartable, este experimento no se puede hacer.

---

### R-07: Ningun tema oscuro resulta funcional — **Severidad: media**

**Impacto:** los tres mecanismos (Windhook, patcher+ONE, temas) fallan y el objetivo A queda
documentado como no alcanzado en 14393.

**Probabilidad:** media.

**Mitigacion:** esto ya es un **resultado válido**. El valor del proyecto incluye demostrar
documentalmente que no es viable, con evidencia propia, no solo con citas de foros. Un `refutado`
bien documentado es un entregable.

---

### R-08: Ninguna app moderna instala en 14393 — **Severidad: alta (esperada)**

**Impacto:** el objetivo B queda limitado a MSIX Core, `.appx` nativo y EXE/MSI.

**Probabilidad:** **muy alta.** La evidencia de `docs/04` es fuerte: los `MinVersion` de las apps del
Store (19041, 17763) superan 14393, y MSIX Core no reescribe ese piso.

**Mitigacion:** none porque no hace falta. `docs/04` §12 ya identifica las tres vías que sí
funcionan. EXP-030 a EXP-035 no buscan "hacer que MSIX funcione", sino **medir exactamente dónde
se rompe cada capa**. La escalera de cinco estados de `docs/04` §1 es el instrumento de medición.

---

## 3. Riesgos de costo y de seguridad

### R-09: Costos no controlados si el repo es privado — **Severidad: media**

**Impacto:** el plan Free tiene 2000 min/mes y 500 MB de artifacts. Un solo experimento de
instalacion de Windows puede consumir 100-200 min. El limite de costo cero se rompe en semanas.

**Probabilidad:** alta si se elige privado por defecto.

**Mitigacion:** repo **publico** obligatoriamente. Actions estandar es gratuito e ilimitado en repos
publicos. Ademas el `base.qcow2` de 5-8 GB no cabe en los 500 MB de artifacts de un repo privado: el
repo publico es una necesidad tecnica, no solo econmica.

---

### R-10: Contenido de la ISO: origen legal y la ISO no puede distribuirse — **Severidad: media**

**Impacto:** no hay forma de llevar la ISO a los runners.

**Probabilidad:** media. Microsoft permite descargar la ISO de evaluacion de Windows 10 Enterprise,
pero redistribuirla en un repo publico es otra cuestion.

**Mitigacion:** separar el repo publico de codigo y configuracion de la ISO:
- El repo publico contiene workflows, scripts y docs. Nada de la ISO.
- La ISO se sube como Release de un repo **privado**, o se distribuye por otro canal.
- `base.qcow2` derivado de la ISO: verificar tambien la licencia de la imagen derivada.

**Este punto requiere decision del usuario.** No se resuelve por inferencia.

---

### R-11: Divulgacion de informacion sensible — **Severidad: baja**

**Impacto:** el reporte contiene `stdout` de comandos que podrian incluir rutas de usuario, nombres
de equipo o claves.

**Probabilidad:** baja. La cuenta del laboratorio es anonima y generada.

**Mitigacion:** la VM se instala con una cuenta fija y sin datos reales. En `autounattend.xml`, el
nombre de equipo y el usuario son constantes, no entradas del operador. Los scripts no leen variables
de entorno del host.

---

## 4. Limites del diseno que no son riesgos sino restricciones aceptadas

Estos no se mitigan porque son el precio del diseño elegido. Se listan para que no se confundan con
problemas por resolver.

| Limite | Consecuencia | Aceptado porque |
|---|---|---|
| El overlay se destruye al final del job | No hay persistencia entre experiments | Es lo que hace que cada experiment parta de un estado conocido |
| No hay shell remoto en vivo desde el agente | Iterar es lento | Reproducibilidad > velocidad para este objetivo |
| Solo hay capturas al final de cada accion | No se ve el desktop en streaming | Evita instalar software en el guest |
| Sin GPU emulada | Los parcheadores de shell fallan mas | Es el trade por usar Linux + KVM |
| TCG inutilizable | Si no hay KVM, no hay proyecto | KVM se prueba primero, con un experimento barato |
| PowerShell 5.1, no 7 | Restricciones de sintaxis en scripts | 14393 no tiene PowerShell 7 |
| 14393 en fin de soporte (2026-10-14) | Sin actualizaciones, sin drivers firmados nuevos | Es el objetivo de estudio; documentado como riesgo de proyecto |

---

## 5. El riesgo de fondo

El riesgo mayor del proyecto no es tecnico. Es **confundir "lo que dice la documentacion" con "lo
que hace el sistema"**.

Toda la investigacion documental (`docs/01`, `docs/03`, `docs/04`) produce conclusiones que parecen
firmes y que pueden estar equivocadas. Ya se sabe que al menos una lo esta: el ordinal de
`DWMWA_USE_IMMERSIVE_DARK_MODE` es 19 en 1809/1903 y 20 en Windows 11, y la documentacion oficial
solo documenta el 20. Un agente que confiara en la documentacion propondría el valor equivocado para
1809.

Por eso existe `docs/00-estado-inicial-y-alcance.md`, con la discrepancia de ruta registrada, y por
eso el criterio de decision de EXP-000 esta escrito antes de ejecutar. La disciplina de este proyecto
es medir lo que el sistema hace, no repetir lo que alguien escribio.

**Todo veredicto de este repositorio es una hipótesis hasta que hay un `run-id` que lo respalde.**

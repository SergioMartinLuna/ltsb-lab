# 07 — Registro de experimentos

Estado: **matriz de definidos. Ninguno ejecutado.**

Este documento es el índice maestro. El detalle de cada experimento vive en
`experimentos/EXP-XXX.md`, siguiendo la plantilla de §4.

---

## 1. Estados posibles

| Estado | Significado |
|---|---|
| `definido` | Escrito, con hipótesis y criterio de decisión. No ejecutado. |
| `en-curso` | Lanzado, sin resultado todavía. |
| `exitoso` | Ejecutado, hipótesis confirmada, evidencia en `resultados/`. |
| `refutado` | Ejecutado, hipótesis **falsada**. Es un resultado valioso, no un fracaso. |
| `bloqueado` | No se puede ejecutar por una dependencia externa. Se anota cuál. |
| `descartado` | La pregunta Resultó irrelevante. Se documenta por qué se cierra. |

**Regla:** un experimento `refutado` se conserva y se cita. Borrar los experimentos refutados es
como se pierde el conocimiento real del proyecto: las caminos que no funcionan son las que cortan
futuro trabajo duplicado.

---

## 2. Fases y dependencias

```
Fase A — medir el entorno          EXP-000
                                        |
Fase B — construir la imagen         EXP-001  EXP-002
                                        |
Fase C — abrir canal de control      EXP-003  EXP-004  EXP-005
                                        |
Fase D — evidencia visual            EXP-006
                                        |
Fase E — inventario base             EXP-007
                                        |
Fase G — Hilo A: Dark Mode          EXP-010  EXP-011  EXP-012  EXP-020  EXP-021  EXP-022
Fase H — Hilo B: AppX/MSIX          EXP-030  EXP-031  EXP-032  EXP-033  EXP-034  EXP-035
```

**Nada de Fase G ni H puede empezar antes de cerrar Fase E.** Ejecutar un experimento temático sin
inventario base produce datos incomparables, que es peor que no tener datos.

---

## 3. Matriz completa

### Fase A — entorno

| ID | Pregunta | Criterio de decisión | Depende de | Estado |
|---|---|---|---|---|
| **EXP-000** | ¿El runner tiene KVM, espacio y red suficientes? | `KVM_VIABLE` / `KVM_PARCIAL` / `SIN_KVM` | — | `definido` — doc: `docs/02`, wf: `workflows/00-sonda.yml` |

### Fase B — imagen

| ID | Pregunta | Criterio de decisión | Depende de | Estado |
|---|---|---|---|---|
| **EXP-001** | ¿Arranca una VM con overlay desde una base? | La VM inicia y el overlay monta | EXP-000 | `definido` |
| **EXP-002** | ¿La instalación de 14393 es realmente desatendida? | La instalación llega al escritorio sin intervención | EXP-001, ISO | `bloqueado` — falta ISO |

### Fase C — canal de control

| ID | Pregunta | Criterio de decisión | Depende de | Estado |
|---|---|---|---|---|
| **EXP-003** | ¿WinRM queda accesible desde el runner? | `Invoke-Command` retorna en <60 s | EXP-002 | `definido` |
| **EXP-004** | Si no, ¿Win32-OpenSSH portable funciona? | `ssh` con clave pública, sin prompt | EXP-003 | `definido` |
| **EXP-005** | El canal mínimo ejecuta y devuelve salida | Un `Write-Host` desde el host llega al reporte | EXP-003/004 | `definido` |

### Fase D — evidencia visual

| ID | Pregunta | Criterio de decisión | Depende de | Estado |
|---|---|---|---|---|
| **EXP-006** | ¿`screendump` QMP produce una imagen legible? | PNG >1280x720 con contenido no vacío | EXP-002 | `definido` |

### Fase E — inventario

| ID | Pregunta | Criterio de decisión | Depende de | Estado |
|---|---|---|---|---|
| **EXP-007** | ¿El inventario base se genera completo? | Los 4 bloques (`dark_mode`, `appx`, `canales`, sistema) tienen datos | EXP-005 | `definido` |

### Fase G — Hilo A: Dark Mode

| ID | Pregunta | Criterio de decisión | Depende de | Estado |
|---|---|---|---|---|
| **EXP-010** | ¿14393 tiene algún soporte de dark mode? | Hashes + exports de `uxtheme.dll`, flag de registro, existencia de `dark.theme` | EXP-007 | `definido` |
| **EXP-011** | ¿El control 19044 sí lo tiene? | El flag de registro difiere y el hash de `uxtheme` es otro | EXP-007 + VM 19044 | `definido` |
| **EXP-012** | ¿El diff binario explica el cambio? | Tabla de tamaños/hashes/exports de `uxtheme` y `explorerframe` | EXP-010, EXP-011 | `definido` |
| **EXP-020** | ¿Windhawk inyecta dark mode sin tocar DLL? | Explorer oscuro, `uxtheme.dll` con hash idéntico al original | EXP-010 | `definido` |
| **EXP-021** | ¿UltraUXThemePatcher + ONE funcionan? | Explorador arranca y muestra tema | EXP-010 | `definido` |
| **EXP-022** | ¿El tema de 14393 se renderiza bien? | Captura legible, sin artefactos ni texto invisible | EXP-021 | `definido` |

**Nota de riesgo:** EXP-021 y EXP-022 modifican DLL de sistema. Solo dentro de la VM descartable.
`docs/03` §4 documenta reportes de pantallas negras y BSOD. El overlay se destruye al final: ese
es el mecanismo de contención, no una formalidad.

### Fase H — Hilo B: AppX/MSIX

| ID | Pregunta | Criterio de decisión | Depende de | Estado |
|---|---|---|---|---|
| **EXP-030** | ¿14393 incluye Microsoft Store? | `Get-AppxPackage -Name Microsoft.WindowsStore` y contenido de `WindowsApps` | EXP-007 | `definido` |
| **EXP-031** | ¿Qué firma real tiene `Add-AppxPackage`? | `Get-Command Add-AppxPackage -Syntax` | EXP-007 | `definido` |
| **EXP-032** | ¿Un `.msix` moderno instala en 14393? | HRESULT + **mensaje literal** | EXP-031, paquete | `definido` |
| **EXP-033** | ¿MSIX Core instala un paquete compatible? | `msixmgr.exe` reporta éxito | EXP-030, paquete con `MSIXCore.Desktop` | `definido` |
| **EXP-034** | ¿Las dependencias `Microsoft.VCLibs` fallan? | Se lee el `TargetDeviceFamily` real y se intenta instalar | EXP-033 | `definido` |
| **EXP-035** | ¿Renombrar `.msix` a `.appx` funciona? | Error exacto registrado | EXP-032 | `definido` |

**Regla para toda la Fase H:** registrar **HRESULT en hex + mensaje literal**. `docs/04` §6 mostró
que `0x80073CF3` significa "downgrade" en la tabla oficial y "falta un framework" en la práctica.
El código solo no alcanza para concluir nada.

---

## 4. Plantilla de registro

Cada archivo `experimentos/EXP-XXX.md` sigue esta estructura. Los siete campos son obligatorios;
un experimento sin las siete secciones está incompleto, no "casi listo".

```markdown
# EXP-XXX — <titulo>

Estado: definido | en-curso | exitoso | refutado | bloqueado | descartado

## Hipotesis
Que se espera observar y por que se espera. Si no se puede enunciar como algo que el
experimento puede refutar, la hipotesis esta mal escrita.

## Metodo
Como se prueba. Si depende de un binario externo, se registra su URL y su SHA-256.

## Criterio de decision
Las condiciones escritas ANTES de ejecutar. Sin esto, cualquier resultado se puede
racionalizar a posteriori.

## Evidencia esperada
Que artefactos tiene que producir este experimento para considerarse valido.

## Resultado
Se llena despues de ejecutar. Incluye los datos crudos, no solo la interpretacion.

## Conclusion
Que se aprendio y que cambia en el plan. Si la hipotesis fue refutada, se dice explicitamente.

## Siguiente
El experimento que este habilita, o el bloqueo que hay que resolver.
```

---

## 5. Registro de la ejecucion: `resultados/`

Un archivo por ejecucion, nombrado `EXP-XXX-run<run_id>.md`, con la bitácora mínima de
`docs/06` §7 mas un enlace al artifact. Los datos crudos (`.json`, `.png`, `.log`) van en el artifact
del job, no en el repo: el repo guarda la interpretación, el artifact guarda la evidencia.

Regla: **el repositorio no crece con capturas PNG.** Se referencian por hash y por URL. El repo
guarda lo que se aprendió; el artifact guarda lo que se obtuvo.

---

## 6. Reglas de disciplina

1. **Un experimento, una hipótesis.** Si el protocolo tiene cinco preguntas, son cinco
   experimentos.
2. **Criterio de decisión antes de ejecutar.** No negociable.
3. **Refutado se conserva y se cita.**
4. **`[NO ENCONTRADO]` es un resultado valido.** Inventar un dato para llenar una tabla arruina la
   confianza en todo el proyecto.
5. **Ningun experimento escribe sobre `base.qcow2`.** Si lo hace, es un bug de diseño.
6. **Ningun experimento toca una instalacion real.** Toda carga destructiva ocurre en un overlay
   descartable.
7. **El plano declarado / implementado / runtime se separa siempre.** La documentacion de Microsoft
   y el comportamiento real de 14393 no son lo mismo, y la investigacion consiste justamente en
   medir la distancia entre ambos.

# 06 — Reproducibilidad y ejecucion

Estado: **diseño. Nada ejecutado.**

El objetivo de este documento es que cualquiera (incluido el agente en una sesión futura) pueda
reproducir un resultado sin tener que confiar en la palabra de nadie.

---

## 1. Que significa "reproducible" aqui

Cuatro niveles, y el proyecto solo va a poder afirmar los niveles que efectivamente tenga:

| Nivel | Afirmacion | Como se prueba |
|---|---|---|
| L1 El codigo esta en el repo | Los scripts y workflows estan versionados | `git log`, el commit esta en `reporte.json` |
| L2 El codigo produce lo mismo | Reejecutar da el mismo resultado | Comparar dos `reporte.json` del mismo experimento |
| L3 El entorno es identico | El runner, la imagen base y la ISO son los mismos | Hashes de `base.qcow2` y de la ISO registrados |
| L4 El resultado es interpretable | Otro agente llega a la misma conclusion | Conclusion escrita con datos, no con Assertions |

**Honestidad sobre el estado actual: el proyecto esta en L1 para la sonda y en L0 para todo lo
demas.** Ningun workflow se ha ejecutado. Escribir esto evita que un "reproducible" sin pruebas se
lea como un hecho.

### Por que los niveles 2 y 3 son mas duros de lo que parecen

- **L2 tiene ruido real**: timestamps, IDs de job, `run-id`, orden de entradas de registro, hash de
  la maquina. Un `reporte.json` identico byte a byte es imposible. Lo que se busca es que los
  *campos de veredicto* coincidan, no el archivo.
- **L3 tiene una trampa seria**: `ubuntu-latest` **cambia de imagen sin aviso**. El kernel, la version
  de QEMU y el navegador cambian. Un resultado obtenido en `ubuntu-22.04` y otro en `ubuntu-24.04` no
  son el mismo entorno.

  **Mitigacion: pinear `runs-on: ubuntu-24.04`** en vez de `ubuntu-latest` una vez que EXP-000 haya
  identificado cual imagen funciona. Perder la automatizacion de actualizaciones a cambio de
  reproducibilidad es el trade correcto para un laboratorio.

---

## 2. La cadena de dependencias

Un experimento solo es reproducible si toda su cadena lo es. La cadena de este proyecto:

```
commit del repo
  -> workflow.yml de ese commit
    -> imagen del runner (pinneada)
      -> base.qcow2 (hash registrado)
        -> ISO 14393 troceada en Release (hashes registrados)
          -> autounattend.xml (versionado)
            -> script del experimento (versionado)
              -> reporte.json + capturas
```

**Cada eslabón se rompe por separado.** Los puntos donde se rompe con mas frecuencia:

1. **La ISO.** Es binaria externa, Microsoft la puede reemplazar. Sin hash, un resultado
   "reproducible" puede haber usado otra ISO. Por eso los hashes van en el reporte.
2. **`base.qcow2`.** Si se regenera con QEMU de otra version, el `qcow2` cambia. Por eso se
   registra el hash y no se reconstruye salvo decision explicita.
3. **La imagen del runner.** Ver L3.
4. **Los parcheadores del Hilo A.** UltraUXThemePatcher y OldNewExplorer son binarios externos de
   terceros. Hay que registrar su hash y su URL de origen junto al resultado. Un reporte que dice
   "se aplico ONE v1.1.8.1" sin hash no es auditable.

---

## 3. Hashes: que se hashea y cuando

| Que | Algoritmo | Cuando |
|---|---|---|
| Archivos fuente del repo | Git SHA-1 (propio de git) | En cada commit |
| `base.qcow2` | SHA-256 | Al crearse, una vez |
| ISO 14393 troceada | SHA-256 por trozo, y de la ISO completa | Al descargarse, una vez |
| `autounattend.xml` | SHA-256 | Cuando cambie |
| Parcheadores (ONE, UuxThemePatcher, temas) | SHA-256 | Al descargarlos, por URL |
| `.appx` / `.msix` bajo prueba | SHA-256 | Por experimento |
| Capturas de pantalla | SHA-256 | Por captura |
| `reporte.json` | SHA-256 | Al subirlo |

`[COMUNIDAD]` En Linux, `sha256sum`. En la VM, `Get-FileHash -Algorithm SHA256` (disponible en
PowerShell 4+, asi que si funciona en 14393).

**Todos los hashes van dentro del `reporte.json`**, no en un archivo aparte. Razon: si estan aparte,
alguien puede reportarlos de una corrida y los datos de otra, y no hay forma de notarlo.

---

## 4. Nombres de artefacto: la convencion que hace auditable un job

`[HIPOTESIS, propuesta de diseño]`

```
exp-<ID>-<accion>-run<run_id>.json
exp-<ID>-<accion>-run<run_id>-<sha8>.zip
```

Consecuencia buscada: **el nombre del artifact contiene el `run-id` y el commit.** Buscar un
resultado en la UI de Actions o en la API devuelve siempre el origen exacto. Sin esto, seis meses
después nadie sabe qué commit produjo qué captura.

El `sha8` permite además.cachear: si dos experiments usan el mismo commit, el segundo puede reusar
el base ya construido.

---

## 5. Registro de artifacts: límites reales

`[OFICIAL]`

| Repo | Artifact | Retención por defecto | Almacenamiento incluido |
|---|---|---|---|
| Público | 500 MB por repo | 90 días | Sin límite adicional documentado |
| Privado (Free) | 500 MB | 90 días | 500 MB/mes de artifact storage |
| Privado (Team) | 2 GB por repo | 90 días | 2 GB/mes |
| Privado (Enterprise) | 50 GB por repo | 90 días | 50 GB/mes |

`[OFICIAL]` No se puede subir un solo archivo de más de 2 GB como artifact.

**Consecuencia de diseño directa:** el plan de.repo público no es solo por minutos, es también
porque el base `qcow2` (5-8 GB comprimido) no entra en los 500 MB de un repo privado. Con repo
público, el base va como **Release** y el artifact solo lleva reporte, capturas y logs.

Este es el punto donde el límite de costo cero y el diseño se alinean solos. No es casualidad.

---

## 6. Distribucion de la ISO: por que Release y no artifact

`[OFICIAL]` Límites de GitHub Releases:

- Hasta **1.000 assets** por release.
- Máximo **2 GiB por archivo**.
- **Sin límite de tamaño total** (limitado solo por ancho de banda).

`[OFICIAL]` Alternativa: GitHub **Container Registry** (ghcr.io) admite layers de hasta 4 GiB.
https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-container-registry

**Decision propuesta: ISO troceada como Release, en trozos de ~1.9 GiB.**

Razon de los ~1.9 GiB y no 2 GiB exactos: dejar margen bajo el limite duro evita que una
diferencia de conteo de bloques haga fallar la subida. Es un detalleOperation que cuesta una
re-ejecución de 20 minutos descubrirlo de la forma dura.

```bash
# Trocear
split -b 1900M win10_14393.iso partes/iso.part-
sha256sum partes/iso.part-* > SHA256SUMS

# Reensamblar y verificar
cat partes/iso.part-* > win10_14393.iso
sha256sum -c SHA256SUMS
```

El script de ensamblado tiene que **verificar los hashes antes de usar la ISO**. Una ISO corrupta
produce un `autounattend` que se ignora silenciosamente y una instalación que arranca en modo
interactivo, que es un fallo de diagnóstico carísimo.

`[NO ENCONTRADO]` Fuente remota legal de la ISO 14393 para subir a un Release propio. El usuario
indica que la tiene localmente. Sin esto, el laboratorio no arranca. **Es el bloqueo #1 de la
Fase 5.**

---

## 7. Registro de ejecuciones:Bitácora mínima

Por cada ejecucion, sin excepcion:

| Campo | Ejemplo |
|---|---|
| Fecha/hora UTC | `2026-10-01T12:00:00Z` |
| Experimento | `EXP-000` |
| `run_id` | `1234567890` |
| URL | `https://github.com/<user>/<repo>/actions/runs/1234567890` |
| Commit | `abc1234` |
| Runner | `ubuntu-24.04` |
| Duracion | 6m 12s |
| Resultado | `KVM_VIABLE` |
| Artefactos | lista con nombres y hashes |
| Conclusion | una frase |

La bitácora vive en `resultados/`, un archivo Markdown por ejecucion. Es lo que hace que el
proyecto sobreviva a una compactación de contexto o a un cambio de agente: el estado está en disco,
no en la conversación.

---

## 8. Idempotencia

`[HIPOTESIS, requisito de diseño]`

El mismo experimento lanzado dos veces desde el mismo commit debe producir el mismo `veredicto`, y
sus `reporte.json` deben diferir solo en campos de ruido. La lista de campos que **se permite**
diferir esta fijada por adelantado:

```json
{
  "ruido_permitido": [
    "timestamp_utc",
    "run_id",
    "workflow",
    "duracion_s",
    "runner.kernel",
    "guest.uptime_s",
    "guest.mem_free_mb",
    "acciones[].stdout",
    "acciones[].stderr"
  ],
  "campos_de_verdicto": [
    "estado",
    "veredicto",
    "acciones[].exit_code",
    "acciones[].error_hresult"
  ]
}
```

Los `campos_de_veredicto` **no pueden** diferir entre dos corridas del mismo commit. Si difieren,
eso es un hallazgo: o el experimento es no determinista, o el entorno cambio. En ambos casos hay que
investigarlo antes de confiar en el resultado.

Este bloque viaja dentro del reporte. Ponerlo en un documento aparte permite "ajustar" la tolerancia
despues de ver resultados, que es exactamente la forma de autoengaño que hay que evitar.

---

## 9. Verificacion de lo verificable

Checks que deben pasar antes de declarar un experimento valido. `[COMUNIDAD]` para las herramientas,
`[HIPOTESIS]` para la politica.

| Verificacion | Herramienta | Falla cuando |
|---|---|---|
| Sintaxis del workflow | `actionlint` | YAML invalido o expressions rotas |
| PowerShell parseable | `[System.Management.Automation.Language.Parser]::ParseFile` en 5.1 | El script ni se ejecuta |
| Shell del workflow | `shellcheck` | Errores de quoting en bash |
| Overlay creado desde la base correcta | hash de `base.qcow2` en el reporte | Se lanzo sobre otra imagen |
| Capturas con hash | `sha256sum -c` | Evidencia no verificable |
| Reporte con todos los campos del contrato | `jq -e 'has("guest") and has("acciones")'` | Contrato roto |

El parseo de PowerShell contra 5.1 merece emphasis: un script que usa `??` o `-AsByteStream` pasa
perfecto en cualquier editor moderno y falla en el minuto 8 de un job de 40 minutos. Detectarlo en
el commit es la diferencia entre un error barato y uno caro.

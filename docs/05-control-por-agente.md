# 05 — Control de la VM por OpenCode

Estado: **diseño. No implementado ni ejecutado.**

Este documento define el contrato entre OpenCode (el agente) y la VM Windows. Sin esto, el
laboratorio sería unazón de "yo dejo el job corriendo y rezo"; con esto, cada afirmación del agente
sobre el estado de Windows tiene que apuntar a evidencia recuperable de un job concreto.

---

## 1. Principio de diseño

> **OpenCode no habla con la VM. OpenCode lanza un job, y el job devuelve un reporte estructurado.**

No hay shell remoto persistente desde el agente. El agente no tiene IP de la VM, no hay SSH desde
aquí, no hay estado entre invocaciones. Todo lo que el agente puede afirmar sobre 14393 sale de un
`reporte.json` subido como artifact de un workflow con `run-id` identificable.

Esto tiene un costo — no hay iteración rápida e interactiva — y una ventaja enorme: **todo resultado
es reproducible, versionado y auditable**. Un error del agente queda en el log del job, no en una
afirmación sin respaldo.

---

## 2. La superficie de control: `workflow_dispatch` con inputs tipados

Cada acción sobre la VM es un input de un workflow. El agente rellena el input, dispara, y lee el
artifact de salida. Nunca escribe un workflow distinto para cada tarea.

```yaml
on:
  workflow_dispatch:
    inputs:
      experimento:
        description: 'ID del experimento, ej. EXP-011'
        required: true
        type: string
      accion:
        description: 'Accion a ejecutar dentro de la VM'
        required: true
        type: choice
        options:
          - info              # inventario del sistema
          - script            # correr un .ps1 del repo
          - instalar-appx     # intentar instalar un paquete
          - capturar           # screenshot + inventario
          - smoke-test        # suite minima de verificacion
          - limpiar           # reiniciar a snapshot limpio
      parametros:
        description: 'JSON libre pasado al script'
        required: false
        type: string
        default: '{}'
      interactivo:
        description: 'Permitir ejecucion larga sin limite de 6h del job'
        required: false
        type: boolean
        default: false
```

### Por qué `type: choice` y no string libre

`type: choice` hace que la UI de Actions **rechace** valores inválidos antes de gastar minutos. Un
string libre permite que el agente mande `instalar` y que el job falle 40 minutos después. La
validación barata va al principio.

### Por qué `parametros` es JSON y no un string opaco

Porque el agente genera la llamada. Un JSON validable con `jq` permite:
- Rechazar entradas malformadas en el primer step, en segundos, en vez de en el minuto 50.
- Pasar estructuras (rutas, listas de paquetes, flags) sin inventar un parser de líneas de comando.

---

## 3. Máquina de estados de la VM dentro de un job

```
[overlay limpio qcow2]
        |
        v
  [arranque]  --(autounattend ya aplicado en la base, sin interacción)
        |
        v
  [espera de WinRM/SSH]  --(timeout 900s, sondeo cada 10s)
        |
   +----+----+
   |         |
 timeout    ok
   |         |
   v         v
[FALLO]  [ejecutar acción]
              |
              v
      [recolectar evidencia]
      - screenshot (QMP screendump)
      - logs del sistema
      - reporte.json
              |
              v
      [subir artifact]  -->  el agente lee y decide
```

**Punto crítico: el overlay se destruye al final del job.** La VM no persiste entre invocaciones. Es
lo que hace que cada experimento parta de un estado conocido, y es lo que hace seguro apoyarse en una
imagen base reproducible.

Persistencia se logra **dentro** de un mismo job, encadenando varias acciones, no entre jobs.

---

## 4. Sobre el límite de 6 horas por job

`[OFICIAL]` El job tiene un máximo duro de 360 horas de **tiempo de ejecución**; el límite por defecto
de `timeout-minutes` es 360, y el máximo permitido en un workflow es 35.000 minutos (más de 6 años)
en repositorios públicos con acceso gratuito. Ver `docs/01`.

Diseño: los experiments cortos (información, capturas, un script) no necesitan nada especial. Los
largos (instalar 14393 desde ISO, compilar, benchmarks) usan `timeout-minutes: 300` y se disparan por
`workflow_dispatch` con `interactivo: true`, no por `push`. Se **evita el `schedule` automático**: cada
ejecución debe ser una decisión deliberada y trazable, no un job fantasma que consume minutos.

---

## 5. Canal de control dentro del job: WinRM vs SSH

### 5.1 Opción elegida: WinRM

`[HIPÓTESIS, sin verificar]`

Windows 10 14393 trae WinRM como característica opcional, no instalada por defecto, y el componente
`winrm.cmd` requiere Configuración de seguridad local. El acceso remoto desde un host Linux requiere
autenticación (NTLM o Kerberos) y configuración de listener, que es donde suele romperse.

**Ventaja:** nativo, sin software de terceros, y `Invoke-Command` es el idioma natural para los
experimentos PowerShell.
**Riesgo:** es exactamente la parte que más falla al automatizar. Si EXP-003 muestra que WinRM no
queda accesible desde el runner, hay que caer a SSH.

### 5.2 Alternativa: OpenSSH Server para Windows

`[OFICIAL, con matiz importante]` OpenSSH client/server existen como *OpenSSH Client* en 1607, pero
**la capacidad de servidor (`sshd`) se agregó en Windows 10 1809 (17763)**.
https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh-overview

Es decir: **en 14393 el cliente existe pero el servidor no.** Instalarlo requiere un build de Win32-OpenSSH
del proyecto Portable, copiado al sistema.

Esto **no está en 14393 por defecto** — es un hecho verificado por la documentación de ciclo de vida de
la capacidad. La conclusión para el diseño: si se elige SSH, es un paso de instalación adicional, no
una configuración.

### 5.3 Alternativa de bajo acoplamiento: canal QMP + script pre-programado

`[COMUNIDAD, sin verificar en 14393]` QEMU ofrece un socket de control (QMP) que permite comandos
remotos. Se puede usar para shootdowns, info de red, y `screendump`.

**Limitación decisive:** QMP no ejecuta comandos dentro del guest. Solo controla el hipervisor. Es
excelente para **capturar evidencia del estado visual** y para **inyectar teclas** (`sendkey`), pero no
sustituye un canal de ejecución.

Combinación pragmática: **QMP para evidencia visual + pre-cargar el script que la VM ejecuta sola al
arrancar.** Es menos flexible, pero no depende de WinRM ni de SSH.

### 5.4 Decisión

**Probar WinRM primero (EXP-003). Si falla, probar Win32-OpenSSH portable (EXP-004). Si ambos fallan,
caer a ejecución pre-programada + QMP.**

Razón: es la única decisión del proyecto donde un fallo no se puede rodear fácilmente, y donde probar
pronto evita construir toda la infraestructura sobre un canal que no funciona.

---

## 6. Contrato del reporte: `reporte.json`

Todo experiment produce **un** archivo. El agente razona sobre ese archivo, no sobre prosa.

```json
{
  "experimento": "EXP-011",
  "run_id": "1234567890",
  "workflow": "control-vm.yml",
  "timestamp_utc": "2026-10-01T12:00:00Z",
  "estado": "ok" | "fallo" | "timeout",
  "duracion_s": 420,
  "runner": {
    "os": "ubuntu",
    "kernel": "6.11.0-1018-azure",
    "kvm": true
  },
  "guest": {
    "build": "14393.0",
    "revision": "14393.1532",
    "edition": "Windows 10 Enterprise LTSB",
    "arch": "x64",
    "uptime_s": 300,
    "mem_free_mb": 3200
  },
  "acciones": [
    {
      "nombre": "Get-AppxPackage",
      "cmdlet": "Get-AppxPackage -AllUsers",
      "exit_code": 0,
      "stdout": "...",
      "stderr": ""
    },
    {
      "nombre": "instalar-msix",
      "cmdlet": "Add-AppxPackage -Path whatsapp.msix",
      "exit_code": -1978335189,
      "error_hresult": "0x8BAD0042",
      "error_message": "texto literal devuelto por Windows",
      "stdout": "",
      "stderr": "..."
    }
  ],
  "capturas": [
    {"nombre": "explorer-antes.png", "sha256": "..."}
  ],
  "artefactos_extra": ["logs/eventos.evtx", "logs/setupapi.log"],
  "conclusion": "texto libre para el agente",
  "reproducible_desde": "commit:abc1234"
}
```

### Reglas del contrato

1. **HRESULT como hex + mensaje literal.** Nunca solo el número. La "tabla de errores" de `docs/04`
   mostró por qué: `0x80073CF3` significa dos cosas distintas según el mensaje.
2. **Capturas con hash.** Una imagen sin hash no es evidencia; es una afirmación.
3. **`reproducible_desde` apunta al commit.** Sin eso, "reproducible" es una afirmación sin respaldo.
4. **El agente escribe `conclusion`; el script escribe todo lo demás.** La conclusión es la única
   parte interpretativa, y por eso está separada de los datos.

---

## 7. La sesión de PowerShell: cómo se ejecuta

`[COMUNIDAD]` PowerShell 5.1 es el shell de 14393. Es un `.NET` y el clásico error es assume
comportamiento de PowerShell 7:

| Error | Detalle en 14393 |
|---|---|
| `Get-Content -AsByteStream` | No existe. Es `-Encoding Byte` |
| `ForEach-Object -Parallel` | No existe (se agrega en 7.0) |
| `ConvertFrom-Json -AsHashtable` | No existe (7.0) |
| `Invoke-Command -AsJob` con throttling | No hay throttling en 5.1 |
| Operadores `??`, `?.` | No existen (7.0) |
| `Get-FileHash` | ✅ Sí existe desde 4.0 |
| `-ErrorAction Stop` con try/catch | ✅ Funciona, es la base del trapping |

**Regla:** los scripts del repo se validan contra PowerShell 5.1, no contra 7.x. Un error aquí
produce fallos a mitad de experimento, que es donde más caro salen.

### Trapping de errores obligatorio

Cada acción va envuelta así, y el patrón se repite en todas:

```powershell
function Invoke-Lab {
    param([string]$Nombre, [scriptblock]$Accion)
    $re = [ordered]@{
        nombre       = $Nombre
        exit_code    = 0
        stdout       = ""
        stderr       = ""
    }
    try {
        $out = & $Accion 2>&1
        $re.stdout = ($out | Out-String).Trim()
    } catch {
        $re.exit_code = 1
        $re.stderr = $_.Exception.Message
        # HRESULT si viene de una excepción nativa
        if ($_.Exception.HResult -ne 0) {
            $re.error_hresult = ('0x{0:X8}' -f ($_.Exception.HResult -band 0xFFFFFFFF))
        }
    }
    $script:Acciones.Add($re)
}
```

El objetivo: **una acción que falla no aborta el reporte.** Un experimento que muere en el minuto 12
por una excepción y pierde 8 minutos de evidencia previa es peor que uno que termina con `estado:
"fallo"` y datos parciales.

---

## 8. Inventario base: el paso que se ejecuta siempre

Antes de cualquier experimento, un paso produce el inventario del sistema. Sin esto, cada
experimento repite el mismo sondeo y los resultados no son comparables.

```powershell
$out = [ordered]@{}
$out.build      = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuild
$out.revision   = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').UBR
$out.edition    = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').EditionID
$out.install    = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').InstallDate
$out.architecture = $env:PROCESSOR_ARCHITECTURE

# Dark mode: qué soporta el sistema
$out.dark_mode = [ordered]@{
    clave_registro_presente = Test-Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    atributo_dark           = (Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' -ErrorAction SilentlyContinue).AppsUseLightTheme
    uxtheme_ruta           = "$env:SystemRoot\System32\uxtheme.dll"
    uxtheme_sha256         = (Get-FileHash "$env:SystemRoot\System32\uxtheme.dll" -Algorithm SHA256).Hash
    explorerframe_sha256   = (Get-FileHash "$env:SystemRoot\System32\explorerframe.dll" -Algorithm SHA256).Hash
    dark_theme_existe      = Test-Path "$env:SystemRoot\Resources\Themes\dark.theme"
}

# AppX: qué hay instalado y qué firma soporta el cmdlet
$out.appx = [ordered]@{
    store_presente      = [bool](Get-AppxPackage -Name Microsoft.WindowsStore -ErrorAction SilentlyContinue)
    total_paquetes      = (Get-AppxPackage | Measure-Object).Count
    firma_add_appx      = (Get-Command Add-AppxPackage).Definition
    windowsapps_existe  = Test-Path "$env:ProgramFiles\WindowsApps"
}

# Red y canales de control
# Nota: no se puede escribir '= try { } catch { }' dentro de un literal de hashtable en
# PowerShell 5.1 (una instruccion try no es una expresion). Por eso se calcula antes.
$ssh_estado = 'ausente'
try {
    $ssh_estado = (Get-Service sshd -ErrorAction Stop).Status.ToString()
} catch {
    $ssh_estado = 'ausente'
}

$out.canales = [ordered]@{
    winrm_lista     = (winrm enumerate) -join "`n"
    winrm_servicio  = (Get-Service WinRM).Status.ToString()
    ssh_servicio    = $ssh_estado
    qmp_respondiendo = $env:QMP_READY
}
```

`[HIPÓTESIS]` `firma_add_appx` es el paso que resuelve la ambigüedad de `docs/04` §5: la referencia
`windowsserver2016-ps` era un proxy, y este es el valor real.

---

## 9. Captura de pantalla por QMP

`[COMUNIDAD, sin verificar en 14393]` `screendump` de QMP escribe un archivo en el **host**, no en el
guest. Es la vía correcta porque no depende de nada instalado dentro de Windows.

Flujo:

```bash
# 1. Arrancar QEMU con monitor QMP en un puerto
qemu-system-x86_64 \
  -accel kvm -cpu host -m 4096 -smp 2 \
  -drive file=overlay.qcow2,format=qcow2,if=virtio \
  -netdev user,id=net0,hostfwd=tcp::10022-:3389 \
  -device virtio-net-pci,netdev=net0 \
  -qmp tcp:127.0.0.1:4444,server,nowait \
  -display none \
  -daemonize

# 2. Pedir una captura por QMP
printf '%s\n%s\n' \
  '{"execute":"qmp_capabilities"}' \
  '{"execute":"screendump","arguments":{"filename":"/tmp/captura.ppm"}}' \
  | nc 127.0.0.1 4444

# 3. Convertir a PNG legible
qemu-img convert -f ppm -O png /tmp/captura.ppm captura.png
```

### Limitaciones que hay que documentar

- `screendump` captura el **framebuffer**, no el escritorio compuesto si hay más de un monitor. Con
  `-display none` y una sola VM, coincide.
- El archivo generado es **PPM**, no PNG. Hay que convertir.
- La resolución por defecto de QEMU sin `-vga` explícito es 1024x768. Para evaluar themes, eso es
  insuficiente: **usar `-vga std` y forzar resolución con el `autounattend`** o con `-global` del
  dispositivo. Un theme evaluado a 1024x768 puede verse distinto al real.

`[COMUNIDAD]` Alternativa si `screendump` no basta: `tools/vnc/`, o montar un ISO de herramientas
dentro de la VM y usar una captura desde PowerShell. Requiere guest additions, que QEMU no trae
— así que es un candidato peor.

---

## 10. Snapshot: por qué overlay y no clonar

`[COMUNIDAD]` `qemu-img create -f qcow2 -b base.qcow2 -F qcow2 overlay.qcow2` crea una capa de
escritura. Es instantáneo, ocupa poco, y descarta se tira con `rm`.

Esto da tres cosas que el proyecto necesita:

1. **Aislamiento**: un experimento que rompe el shell no afecta la base.
2. **Reproducibilidad**: la base es un artefacto inmutable, con hash.
3. **Reversibilidad**: "volver a limpio" es borrar un archivo, no restaurar un snapshot de
   hipervisor.

**Regla dura:** ningún experimento escribe nunca sobre `base.qcow2`. Si un script de la VM toca la
base, es un bug del diseño, no un incidente que reparar.

---

## 11. Lo que el agente NO puede hacer

Limitaciones del diseño, asumidas explícitamente:

| No puede | Por qué |
|---|---|
| Interactuar con la VM en vivo | No hay shell remoto persistente desde el agente |
| Ver la pantalla en streaming | Solo capturas al final de cada acción |
| Iterar rápido | Cada iteración es un job completo, con sus minutos |
| Instalar software de pago | Límite de costo cero |
| Afirmar un resultado sin artifact | Por diseño: el reporte es la única fuente |
| Mantener estado entre jobs | El overlay se destruye; el estado va en artifacts |

La consecuencia honesta: **este laboratorio es lento por diseño.** Es la opción correcta cuando lo que
se busca es evidencia reproducible, no velocidad. Si el objetivo fuera iterar rápido, la respuesta
correcta sería una VM local, que es exactamente lo que el usuario pidió evitar.

---

## 12. Secuencia de implementación de este control

| Paso | Qué prueba | Bloquea |
|---|---|---|
| EXP-001 | El runner arranca la VM y el overlay monta | Todo lo demás |
| EXP-002 | `autounattend` produce una instalación desatendida | El canal de control |
| EXP-003 | WinRM accesible desde el host | Automatización real |
| EXP-004 | WinRM **no** → SSH portable | Backstop |
| EXP-005 | Canal mínimo funcionando: ejecutar un `Write-Host` y recibirlo | Decisión WinRM/SSH |
| EXP-006 | `screendump` QMP produce una imagen legible | Toda evidencia visual |
| EXP-007 | Inventario base completo se genera correctamente | Comparabilidad de experimentos |
| EXP-010+ | Objetivos de investigación | — |

EXP-000 ya está definido en `docs/02` y `workflows/00-sonda.yml`.

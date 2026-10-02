# Validacion estatica de los bloques PowerShell de la documentacion
#
# Por que existe: los bloques de docs/ y experimentos/ se ejecutaran dentro de
# Windows 10 14393, cuyo PowerShell es 5.1. Un bloque que usa sintaxis de
# PowerShell 7 pasa la revision de cualquier editor moderno y falla en el
# minuto 8 de un job de 40 minutos.
#
# Uso (desde la raiz del repo, en un host con Windows PowerShell):
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validar-powershell.ps1
#
# No ejecuta ninguno de los bloques. Solo los parsea.

param(
    [string]$Raiz = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Set-Location $Raiz

# Construcciones que existen en PowerShell 7 pero NO en 5.1, o que dependen de modulos
# ausentes en 14393. El parser sintactico no las detecta: pasan el analisis y fallan
# en runtime. Ver docs/05-control-por-agente.md §7.
$PatronesPS7 = @(
    @{ Regex = '\?\?';            Motivo = 'operador ?? (solo PowerShell 7)' }
    @{ Regex = '\?\.(\w)';        Motivo = 'operador ?. (solo PowerShell 7)' }
    @{ Regex = '-AsByteStream';   Motivo = '-AsByteStream no existe en 5.1; usar -Encoding Byte' }
    @{ Regex = '-AsHashtable';     Motivo = '-AsHashtable no existe en 5.1' }
    @{ Regex = 'ForEach-Object\s+-Parallel'; Motivo = '-Parallel no existe en 5.1' }
    @{ Regex = '\|\s*tee\s+-ErrorVariable'; Motivo = 'revisar: -ErrorVariable de tee-variable' }
    @{ Regex = 'ConvertFrom-Json\b.*-AsHashtable'; Motivo = 'ConvertFrom-Json -AsHashtable es 7.0' }
    @{ Regex = 'Get-Content\b.*-AsStream'; Motivo = '-AsStream es 6.0' }
    @{ Regex = 'Install-Module';   Motivo = 'Install-Module requiere PowerShellGet; verificar en 14393' }
    @{ Regex = '\busing\s+module\b'; Motivo = 'using module es 5.0+, verificar disponibilidad' }
)

$total = 0
$fallas = 0
$avisos = 0
$indice = 0

function Find-PS7 {
    param([Parameter(Mandatory = $true)][string]$Codigo)
    $hallados = @()
    foreach ($p in $PatronesPS7) {
        if ($Codigo -match $p.Regex) {
            $hallados += $p.Motivo
        }
    }
    return $hallados
}

function Test-Codigo {
    <#  Parsea un fragmento contra 5.1 y reporta. No devuelve nada: se llama como #>
    param(                        # sentencia suelta, porque [void](...) se
        [Parameter(Mandatory = $true)][string]$Codigo,   # tragaria el Write-Output
        [Parameter(Mandatory = $true)][string]$Rotulo,   # y el informe saldria vacio.
        [Parameter(Mandatory = $true)][int]$LineaInicio,
        [switch]$OmitirPS7
    )
    $tokens = $null
    $errores = $null
    [void][System.Management.Automation.Language.Parser]::ParseInput(
        $Codigo, [ref]$tokens, [ref]$errores)

    if ($errores.Count -eq 0) {
        Write-Output ("{0} -> OK" -f $Rotulo)
    } else {
        $script:fallas++
        Write-Output ("{0} -> {1} ERROR(ES) DE SINTAXIS" -f $Rotulo, $errores.Count)
        foreach ($e in $errores) {
            $n = $LineaInicio + $e.Extent.StartLineNumber - 1
            Write-Output ("      linea ~{0}: {1}" -f $n, $e.Message)
        }
    }

    # El parser no detecta parametros inexistentes. Estas son construcciones de
    # PowerShell 7 (o de modulos que 14393 no tiene) que pasan el parseo y fallan
    # en runtime, en el minuto 8 de un job de 40. Se buscan a mano.
    if ($OmitirPS7) {
        return
    }
    foreach ($a in (Find-PS7 -Codigo $Codigo)) {
        $script:avisos++
        Write-Output ("      AVISO en {0}: {1}" -f $Rotulo, $a)
    }
}

Write-Output "=== Validacion de PowerShell contra $($PSVersionTable.PSVersion) ==="
Write-Output "raiz:  $Raiz"
Write-Output ""

$archivos = @()
foreach ($dir in @('docs', 'experimentos', 'scripts')) {
    if (Test-Path $dir) {
        $archivos += Get-ChildItem -Path $dir -Filter '*.md' -Recurse -File
        $archivos += Get-ChildItem -Path $dir -Filter '*.ps1' -Recurse -File
    }
}

foreach ($archivo in $archivos) {
    $rel = Resolve-Path -Relative $archivo.FullName
    $lineas = Get-Content -LiteralPath $archivo.FullName

    # Un .ps1 se parsea entero. Antes no se hacia: el recorrido de bloques
    # cercados no encuentra nada dentro de un .ps1, asi que los scripts del repo
    # —donde vive la logica real desde EXP-000— nunca se revisaron.
    if ($archivo.Extension -eq '.ps1') {
        $indice++
        $total++
        # Este archivo se sigue parseando, pero no se le buscan patrones de PS7:
        # $PatronesPS7 contiene literalmente '??', '-AsHashtable', '-AsByteStream'
        # y demas, asi que se detectaria a si mismo y cada aviso seria un falso
        # positivo. Los 7 avisos que producia no eran codigo de EXP-000.
        $esYo = ($archivo.FullName -eq $PSCommandPath)
        Test-Codigo -Codigo ($lineas -join "`n") `
            -Rotulo ("[{0}] {1} (archivo completo{2})" -f $indice, $rel,
                     $(if ($esYo) { ', sin busqueda de PS7: define los patrones' } else { '' })) `
            -LineaInicio 1 -OmitirPS7:$esYo
        continue
    }

    $dentro = $false
    $lenguete = ''
    $buffer = New-Object System.Collections.Generic.List[string]
    $lineaInicio = 0

    for ($i = 0; $i -lt $lineas.Count; $i++) {
        $linea = $lineas[$i]

        if (-not $dentro -and $linea -match '^```(\w*)\s*$') {
            $lenguete = $Matches[1].ToLower()
            if ($lenguete -eq 'powershell' -or $lenguete -eq 'ps1') {
                $dentro = $true
                $lineaInicio = $i + 2
                $buffer.Clear()
            }
            continue
        }

        if ($dentro -and $linea -match '^```\s*$') {
            $indice++
            $total++
            Test-Codigo -Codigo ($buffer -join "`n") `
                -Rotulo ("[{0}] {1} bloque@{2}" -f $indice, $rel, $lineaInicio) `
                -LineaInicio $lineaInicio
            $dentro = $false
            continue
        }

        if ($dentro) {
            $buffer.Add($linea) | Out-Null
        }
    }
}

Write-Output ""
Write-Output ("bloques revisados: {0}" -f $total)
Write-Output ("errores de sintaxis: {0}" -f $fallas)
Write-Output ("avisos de PowerShell 7: {0}" -f $avisos)
Write-Output ""

if ($fallas -gt 0 -or $avisos -gt 0) {
    if ($fallas -gt 0) {
        Write-Output "FALLO: hay bloques que ni siquiera parsean contra 5.1."
    }
    if ($avisos -gt 0) {
        Write-Output "FALLO: hay construcciones de PowerShell 7 que pasan el parseo y"
        Write-Output "       fallan en runtime dentro de 14393, que corre 5.1."
    }
    exit 1
}

Write-Output "=== resultado: sin fallos ==="
exit 0

# EXP-010 — Soporte de dark mode en 14393 (línea base)

Estado: **definido**. No ejecutado.

## Hipotesis

Windows 10 LTSB 2016 (build 14393) **no tiene** ningun soporte de dark mode en File Explorer: no hay
flag de registro, no hay tema oscuro en disco, y `uxtheme.dll` no exporta las funciones de dark mode
que existen en builds posteriores.

## Metodo

Instrumento: el bloque `dark_mode` del inventario base (`docs/05` §8). Todo se lee de dentro de la
VM, sin modificar nada.

```powershell
# 1. Clave de registro del tema
Test-Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'
Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' -EA SilentlyContinue

# 2. Binarios clave: hash y tamaño
Get-FileHash "$env:SystemRoot\System32\uxtheme.dll"        -Algorithm SHA256
Get-FileHash "$env:SystemRoot\System32\explorerframe.dll"  -Algorithm SHA256
Get-Item      "$env:SystemRoot\System32\uxtheme.dll" | Select-Object Length,VersionInfo

# 3. ¿Existe un tema oscuro en disco?
Get-ChildItem "$env:SystemRoot\Resources\Themes" -Recurse -Filter *.theme |
    Select-Object FullName, Length

# 4. ¿Aparecen las funciones de dark mode entre los exports de uxtheme?
#    (equivale en spirit a lo que hace InitDarkMode por GetProcAddress)
```

El paso 4 es el que mas importa y el mas dificil de hacer sin herramientas. Opciones, de mas a menos
confiable:

1. Un `.ps1` que use `Add-Type` con `DllImport("uxtheme.dll")` +
   `GetProcAddress` para resolver `AllowDarkModeForWindow` y `SetPreferredAppMode`. Si el
   `GetProcAddress` devuelve null, la funcion no existe en esa build.
2. `dumpbin /exports` o `objdump -p` sobre una copia de `uxtheme.dll` extraida al host.
3. Un parser PE en Python (el host tiene Python 3.12) que lea la tabla de exports. Es la opcion mas
   reproducible y la preferida: no depende de PowerShell ni de toolchain de Windows.

**Se hace de forma no destructiva:** solo lectura de hashes y de la tabla de exports. Nada se parchea
aqui. Este experimento no toca el sistema.

## Criterio de decision

Escrito antes de ejecutar:

| Resultado | Evidencia | Conclusion |
|---|---|---|
| `SIN_SOPORTE_NATIVO` | sin flag de registro, sin `dark.theme`, y las funciones de dark mode **no** resuelven | Confirma `docs/03`. EXP-020/021 son la unica via |
| `SOPORTE_PARCIAL` | existe `dark.theme` en disco pero sin flag, o alguna funcion resuelve | Hallazgo: hay soporte latente. Reabrir la busqueda de activacion |
| `SOPORTE_NATIVO` | el flag existe y las funciones resuelven | **Refutaria `docs/03`.** Documento incorrecto, corregir y reanalizar |

El caso `SOPORTE_NATIVO` es el que justifica hacer el experimento en vez de citer la documentacion.
No se espera, pero la posibilidad de refutarla es lo que le da valor.

## Evidencia esperada

- `reporte.json` con hashes y tamanos de `uxtheme.dll` y `explorerframe.dll`
- listado completo de `C:\Windows\Resources\Themes`
- resultado de la resolucion de cada export por nombre
- tabla de exports de `uxtheme.dll` completa, como artifact

## Resultado

*(a llenar)*

## Conclusion

*(a llenar)*

## Siguiente

- `SIN_SOPORTE_NATIVO` → EXP-011 (control en 19044) y EXP-020 (Windhook)
- `SOPORTE_PARCIAL` → investigar la activacion antes de ir a la via tematica
- `SOPORTE_NATIVO` → **corregir `docs/03`** y revisar EXP-020/021, que serian innecesarios

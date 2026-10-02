# EXP-003 — Canal de control: WinRM

Estado: **definido**. No ejecutado.

## Hipotesis

`WinRM` puede configurarse durante la instalacion desatendida de 14393 y queda accesible desde el
runner Linux con autenticacion NTLM, sin intervencion manual.

## Metodo

1. En `autounattend.xml`, habilitar `WinRM` via `Microsoft-Windows-Deployment/RunSynchronous` con un
   script que corre `winrm quickconfig -q` y crea un listener HTTP.
2. Crear una regla de firewall para el puerto 5985.
3. Publicar el puerto del host al guest con `-netdev user,hostfwd=tcp::15985-:5985`.
4. Esperar a que el puerto responda, con sondeo cada 10 s y timeout de 900 s.
5. Ejecutar un `Invoke-Command` de prueba con credenciales explicitas.
6. Registrar, por separado: tiempo hasta el primer `Invoke-Command` exitoso, y texto de la salida.

Herramienta en el host: `pwsh` con `New-PSSession -ComputerName 127.0.0.1 -Port 15985`, o
`curl` con la cabecera `WSMan: ...` como comprobacion minima antes de depender de PowerShell.

## Criterio de decision

Escrito antes de ejecutar:

| Resultado | Condicion | Decision |
|---|---|---|
| `WINRM_OK` | `Invoke-Command` retorna en <60 s | Canal de control elegido. Ir a EXP-005 |
| `WINRM_PARCIAL` | el puerto responde pero `Invoke-Command` falla o tarda >120 s | Diagnosticar antes de descartar |
| `WINRM_FALLA` | el puerto nunca responde en 900 s | Ir a EXP-004 (SSH portable) |

**Falla del inventario, no solo del exito:** registrar tambien la salida de `winrm enumerate`, del
estado del servicio `WinRM`, y de la regla de firewall. Un `WINRM_FALLA` sin esos datos no
diagnostica nada.

## Evidencia esperada

- `reporte.json` con el bloque `canales` del inventario
- `winrm-enumerate.log`
- linea de tiempo del sondeo de puerto (primera respuesta, cantidad de intentos)
- captura de pantalla de la sesion remota funcionando

## Resultado

*(a llenar)*

## Conclusion

*(a llenar)*

## Siguiente

`WINRM_OK` → EXP-005 (canal minimo) → EXP-006 → EXP-007.
`WINRM_FALLA` → EXP-004 (Win32-OpenSSH portable, noting que el servidor SSH **no** existe en 14393
y hay que instalarlo desde el build Portable del proyecto).

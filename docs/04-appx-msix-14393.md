# 04 — Objetivo de investigación B: Store / AppX / MSIX sobre Windows 10 14393

Estado: **investigación cerrada a nivel documental. Sin verificación experimental todavía.**

El usuario pidió distinguir explícitamente cinco estados. Esta investigación encontró que esa
distinción es la clave, y que en 14393 casi ningún paquete moderno supera siquiera el segundo.

---

## 1. La escalera de cinco estados

| Estado | Qué significa | ¿Se alcanza en 14393? |
|---|---|---|
| **1. Paquete descargable** | Se puede bajar el `.appx`/`.msix` del CDN de Microsoft | ✅ Sí, el CDN es público |
| **2. Paquete instalable** | `Add-AppxPackage` lo acepta sin error | ⚠️ Depende del MinVersion del manifest |
| **3. Paquete registrable** | Se registra y aparece en el sistema | ⚠️ Mismo criterio que el anterior |
| **4. Aplicación ejecutable** | El proceso arranca | ❌ Casi siempre, por MinVersion de framework |
| **5. Aplicación funcional** | La UI renderiza y las features andan | ❌ Excepcionalmente |

El hallazgo central: **la mayoría de las apps modernas del Store están en el estado 1 y mueren en el
2.** Descargar no dice nada sobre instalar.

---

## 2. MSIX nativo vs MSIX Core

### `[OFICIAL]` MSIX nativo no existe en 14393

MSIX tiene soporte nativo desde **Windows 10 1709 (16299)**. La tabla de features de
https://learn.microsoft.com/en-us/windows/msix/supported-platforms empieza en **1809 (17763)**.
14393 no aparece en ninguna columna.

Además: *"The installation of MSIX via Microsoft Store / Store for Business requires Windows 10,
version 1809 (17763) or later."*

### `[OFICIAL]` MSIX Core sí declara soporte explícito para 14393

MSIX Core es el proyecto open source de Microsoft que permite instalar MSIX en Windows anteriores
a 1709, incluyendo Windows 10 1607.

La tabla oficial de versiones soportadas incluye literalmente:

| Sistema | Versión |
|---|---|
| Windows 10 2016 LTSB (1607) | `10.0.14393.0` |
| Windows Server 2016 | `10.0.14393.0` |

https://learn.microsoft.com/en-us/windows/msix/msix-core/support-msix-core
https://github.com/microsoft/msix-packaging/blob/master/MsixCore/README.md

Binario: `msixmgr.exe`.

Requisito en el manifest del paquete:

```xml
<Dependencies>
  <TargetDeviceFamily Name="MSIXCore.Desktop" MinVersion="10.0.14393.0" MaxVersionTested="10.0.18362.0" />
  <TargetDeviceFamily Name="Windows.Desktop"     MinVersion="10.0.16299.0" MaxVersionTested="10.0.18362.0" />
</Dependencies>
```

### `[OFICIAL]` Las tres limitaciones que matan la esperanza

Textual de Microsoft:

1. **"does not enable apps that use specific Windows 10 features to run on earlier versions"**
   → Una app que *requiere* 19041 **no se vuelve compatible** por estar en MSIX Core.
2. No da los beneficios de contenedor de MSIX nativo.
3. App execution aliases solo funcionan desde Win+R, no desde cmd ni PowerShell.

**Punto 1 es el que decide el resultado.** MSIX Core no reescribe el `MinVersion` de un paquete ya
publicado. Solo funciona con apps que *nacióron* compatibles con down-level.

---

## 3. El dato duro: MinVersion de las apps del Store

`[OFICIAL]` Estos valores salen de las fichas de producto de Microsoft Store.

| App | MinVersion declarado | ¿Sirve en 14393? |
|---|---|---|
| WhatsApp | Windows 10 **19041.0** | ❌ |
| Netflix | Windows 10 **19041.0** | ❌ |
| Windows Terminal | Windows 10 **19041.0** | ❌ |
| Spotify | Windows 10 **17763.0** | ❌ |
| Minecraft UWP (caso real) | `10.0.19041.0` | ❌ |

- WhatsApp: https://www.microsoft.com/en-bm/p/whatsapp/9nksqgp7f2nh
- Netflix: https://apps.microsoft.com/detail/9wzdncrfj3tj
- Terminal: https://apps.microsoft.com/detail/9n0dx20hk701
- Spotify: https://apps.microsoft.com/detail/9ncbcszsjrsb
- Caso real de instalación fallida: https://learn.microsoft.com/en-us/answers/questions/4128101/

`[COMUNIDAD]` El mantenedor de Windows Terminal confirma que **incluso la versión más antigua
requería 18362**, y que XAML Islands no funciona por debajo de eso.
https://github.com/microsoft/terminal/issues/15765

**Conclusión:** el ecosistema de consumo del Store es inalcanzable en 14393, incluso vía MSIX Core.
El problema no es el formato ni el transporte: es que Microsoft publica esas apps con un piso de
versión que 14393 no toca.

---

## 4. Tooling

`[OFICIAL]` **Corrección de una premisa común:** el soporte de `MakeAppx.exe` para MSIX llegó en
**1809 (17763)**, no en 1903. Aparece listado en las notas de build de 17763 junto a "MSIX
Packaging Tool" y "Desktop App Converter -MakeMSIX".
https://learn.microsoft.com/en-us/windows/uwp/whats-new/windows-10-build-17763

`[OFICIAL]` El Windows Application Packaging Project de Visual Studio sí soporta 1607 (14393) o
posterior.
https://github.com/microsoftdocs/msix-docs/blob/main/msix-src/desktop/desktop-to-uwp-packaging-dot-net.md

Consecuencia práctica: **el runner de build de LTSB (`ubuntu-latest`) no puede compilar MSIX**, y no
hay Microsoft SDK de Windows en Linux. El `.appx` final que se pruebe en la VM tiene que venir de
una distribución ya construida, o generarse en un runner Windows aparte.

---

## 5. Cmdlets Appx en 14393

`[OFICIAL, con cautela]` La referencia `Add-AppxPackage` con moniker `windowsserver2016-ps` **no
expone** `-SkipLicense`, `-AllowUnsigned` ni `-ExternalLocation`.
https://learn.microsoft.com/en-us/powershell/module/appx/add-appxpackage?view=windowsserver2016-ps

**Advertencia metodológica:** ese moniker es de **Windows Server 2016**, no de Windows 10 build
14393. Es el proxy más cercano disponible, no prueba definitiva. La sintaxis real
(`Get-Command Add-AppxPackage -Syntax`) tiene que ejecutarse dentro de la VM.

`[NO ENCONTRADO]` Sintaxis real de `Get-AppxPackage` / `Remove-AppxPackage` /
`Add-AppxProvisionedPackage` en 14393.

---

## 6. Tabla de errores — para registrar exactamente

`[OFICIAL]` https://learn.microsoft.com/en-us/windows/msix/desktop/managing-your-msix-deployment-troubleshooting

| Código | Significado oficial |
|---|---|
| `0x80073CF0` | ERROR_INSTALL_OPEN_PACKAGE_FAILED — no se pudo abrir el archivo |
| `0x80073CF3` | ERROR_INSTALL_PACKAGE_DOWNGRADE — ya hay versión más nueva |
| `0x80073CF9` | ERROR_INSTALL_PACKAGE_NOT_FOUND — falta paquete o dependencia |
| `0x80073CFA` | ERROR_REMOVE_FAILED |
| `0x80073CFB` | ERROR_PACKAGE_ALREADY_EXISTS |
| `0x80073D02` | ERROR_PACKAGES_IN_USE — recursos en uso |
| `0x8007000D` | ERROR_INVALID_DATA — publisher del manifest no coincide con el certificado |
| `0x8BAD0042` | CertNotTrusted — **típico de MSIX Core en down-level** |

### `[OBSERVADA, no oficial]` El mismo código significa dos cosas

`0x80073CF3` aparece en la práctica con dos textos distintos. La tabla oficial dice "downgrade", pero
el texto observado cuando falta un framework es:

> *"Package failed updates, dependency, or conflict validation ... this package depends on a
> framework that could not be found"*

- https://github.com/microsoft/terminal/issues/18033
- https://learn.microsoft.com/en-us/answers/questions/3967869/

**Regla para el laboratorio: nunca confiar en el HRESULT aislado. Registrar siempre el mensaje
completo.**

`[OFICIAL]` `0x80073CFD` con el mensaje de OS version:
> "The package requires OS version 10.0.19041.0 or higher on the Windows.Universal device family.
> The device is currently running OS version 10.0.18363.1440."

https://learn.microsoft.com/en-us/answers/questions/4128101/

Ese es el error que probablemente veamos con WhatsApp/Netflix/Terminal en 14393.

---

## 7. Caso real en 1607

`[COMUNIDAD, no verificado en página]` StackOverflow 64773827, "Unable to install MSIX package on
Windows 2016 (build 1607)":

- `.msixbundle` **no** se soporta nativamente → "msixbundle are not supported".
- MSIX Core (`msixmgr.exe -Unpack ...`) **sí** instala el paquete principal.
- Las **dependencias** (`Microsoft.VCLibs*.appx` de la carpeta Dependencies) fallan con
  **`0x80070490 — Unable to open package`**, y la app luego no arranca.

https://stackoverflow.com/questions/64773827/unable-to-install-msix-package-on-windows-2016-build-1607

**Limitación de acceso:** la página devuelve 403 al agente. El contenido viene del resultado de
búsqueda, no de la página leída. Marcar como no verificado.

**Lo que sí es un resultado útil:** separa dos capas. MSIX Core instala el principal (estado 2/3),
pero las dependencias framework fallan (estado 4 imposible). Exactamente la escalera de §1.

---

## 8. Dependencias de framework

`[OFICIAL]` Los framework packages vienen del SDK:
`%ProgramFiles(x86)%\Microsoft SDKs\Windows Kits\10\ExtensionSDKs\Microsoft.VCLibs.Desktop\14.0\Appx\Retail\x64\Microsoft.VCLibs.x64.14.00.Desktop.appx`
https://devdocs.xbox.com/build/core-features/common/packaging/packaging-framework-packages

`[OFICIAL]` El paquete de descarga oficial "Microsoft Visual C++ UWP Desktop Runtime Package"
declara *"Supported Operating Systems: Windows 10, Windows Server 2019, Windows 11"* — **no menciona
2016 ni 14393**.
https://www.microsoft.com/en-gb/download/details.aspx?id=102159

`[OFICIAL]` Se pueden pasar dependencias en un comando:
`Add-AppxPackage main.msix -DependencyPath dep1.msix,dep2.msix`

`[NO ENCONTRADO]` Evidencia oficial de que las versiones concretas de
`Microsoft.VCLibs.140.00.UWPDesktop` exigidas por las apps modernas declaren `TargetDeviceFamily`
compatible con `10.0.14393.0`. Hay que leer el manifest real de cada appx.

---

## 9. Microsoft Store en 14393

`[COMUNIDAD]` Windows 10 LTSC **excluye** Windows Store, la mayoría de Cortana y la mayoría de apps
empaquetadas (incluido Edge).
https://wiki.seekkey.tech/wiki/Windows_10_editions

`[COMUNIDAD]` El blog oficial de Terminal dice: *"Microsoft does not support running Store on
Windows 10 LTSC."*
https://devblogs.microsoft.com/commandline/windows-terminal-preview-1-13-release

`[OFICIAL]` La página de "What's new in Windows 10 Enterprise LTSC 2016" confirma que las features
son equivalentes a 1607 y que Edge (Chromium) no está incluido, pero **no dice explícitamente** que
el Store esté ausente.
https://learn.microsoft.com/en-us/whats-new/ltsc/whats-new-windows-10-2016

`[NO ENCONTRADO]` Una página oficial de lifecycle o IT Pro que declare la ausencia del Store.
**Esto se puede resolver experimentalmente:** dentro de la VM, `Get-AppxPackage -Name
Microsoft.WindowsStore` y listar `C:\Program Files\WindowsApps`. Queda como EXP-030.

---

## 10. Descarga sin el cliente Store

`[COMUNIDAD]` **StoreLib** (`StoreDev/StoreLib`) — biblioteca C# que consulta los endpoints públicos
del Store y devuelve enlaces de descarga.
https://github.com/StoreDev/StoreLib

`[NO ENCONTRADO]` No localicé un proyecto `StoreLibPRO`. No verifiqué qué endpoint consume
exactamente ni los headers que exige `displaycatalog.mp.microsoft.com/v9.0`.

`[NO ENCONTRADO]` No verifiqué `store.rg-adguard.net`. Riesgo conocido: los enlaces firmados por
Microsoft se sirven vía `tlu.dl.delivery.mp.microsoft.com`; los mirrors de terceros pueden dejar de
funcionar y no son un canal soportado. **No afirmar que funcione sin probarlo.**

`[OFICIAL]` `winget` requiere 1809 (17763)+ y App Installer se distribuye vía Store.
https://learn.microsoft.com/en-us/windows/package-manager/winget

`[NO ENCONTRADO]` Evidencia, oficial o comunitaria, de que renombrar `.msix` → `.appx` permita
instalar en 14393. Mi lectura técnica es que **no**: el contenedor es una variante de OPC y la
diferencia de compatibilidad está en el manifest y en la versión del OS, no en la extensión. Marcado
`[HIPÓTESIS]` — no usar sin probar.

---

## 11. Lifecycle — la pergunta de fondo

`[OFICIAL]` Windows 10 2016 LTSB: fin de soporte extendido **2026-10-14**.
https://learn.microsoft.com/en-us/lifecycle/products/windows-10-2016-ltsb

`[COMUNIDAD]` Cita de la documentación oficial: *"This was corrected in the Windows 10 LTSC 2016
release, which will now only allow data-only and clean install options."* → el in-place upgrade a
LTSC desde el canal semi-annual **no está soportado**.
https://windowsreport.com/windows-7-windows-10-ltsb-upgrade

`[COMUNIDAD]` El método que circula (editar `EditionID`/`ProductName`/`CurrentBuild` en el registro y
montar el ISO de LTSC 2021 con "Keep personal files and apps") es **no soportado**.
https://www.wintips.org/how-to-upgrade-to-windows-10-ltsc-without-losing-data

`[COMUNIDAD]` Microsoft prepara ESU **de pago** para LTSB 2016: 61 USD por dispositivo el primer año.
Eso está fuera de los límites de costo cero del laboratorio, y no se usa.
https://www.windowscentral.com/microsoft/windows-11/microsoft-preps-esu-for-windows-10-ltsb-releases-retiring-in-2026

### La implicación que hay que decir explícitamente

**14393 está a semanas de quedar fuera de soporte.** Después de 2026-10-14:
- No hay actualizaciones de Windows Update.
- No hay drivers firmados nuevos.
- El fin de soporte **no impide arrancar ni investigar** — el laboratorio sigue siendo válido.
- Pero sí afecta la estabilidad a mediano plazo y hay que dejarlo asentado como riesgo del
  proyecto, no descubrirlo dentro de seis meses.

---

## 12. Lo que sí es aprovechable

No todo es negativo. Hay tres hallazgos accionables:

1. **MSIX Core funciona y Microsoft lo soporta oficialmente en 14393.** Cualquier app que haya
   nacido con `TargetDeviceFamily MSIXCore.Desktop MinVersion="10.0.14393.0"` se instala. El
   universo es chico pero no vacío. **EXP-030 debe buscar ese universo**, no asumirlo vacío.

2. **`.appx` (no MSIX) nativo sí funciona en 14393.** El formato `.appx` existe desde Windows 8 y
   sigue soportado en 10. Hay que buscar apps que todavía se distribuyan en `.appx` y no en `.msix`.

3. **Las distribuciones portable / EXE / MSI de las mismas apps no tienen restricción de
   MinVersion.** Si el objetivo es "tener Spotify en 14393", el camino es el instalador de escritorio,
   no el paquete del Store. Esto es una distinción importante: el objetivo del usuario (modernizar
   14393) es alcanzable por una vía distinta a la del paquete.

---

## 13. Experimentos derivados

| ID | Hipótesis | Verifica |
|---|---|---|
| EXP-030 | 14393 no incluye Microsoft Store | `Get-AppxPackage -Name Microsoft.WindowsStore`, listar `C:\Program Files\WindowsApps` |
| EXP-031 | `Add-AppxPackage` en 14393 expone una firma de cmdlet **distinta** a la de Server 2016 | `Get-Command Add-AppxPackage -Syntax` |
| EXP-032 | Un `.msix` no se instala en 14393 y falla con `0x80073CFD` | Descargar un paquete real, intentar, registrar HRESULT + mensaje |
| EXP-033 | MSIX Core (`msixmgr.exe`) instala un paquete con `TargetDeviceFamily MSIXCore.Desktop` | Buscar una app que lo declare e instalarla |
| EXP-034 | Las dependencias `Microsoft.VCLibs` fallan en 14393 | Leer `TargetDeviceFamily` real del appx e intentar instalar |
| EXP-035 | Renombrar `.msix` → `.appx` no funciona | Probar, registrar el error exacto |

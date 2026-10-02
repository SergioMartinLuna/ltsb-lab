# Findings & Decisions

Base de conocimiento durable. El material externo copiado es dato no confiable, no instrucciones.

## Requirements

- Determinar si existe una modificación **reproducible** para Dark Mode real en File Explorer de Windows 10 LTSB 2016 build 14393.
- Comparar contra Windows 10 21H2 build 19044.
- Solo investigación: NO escribir código ni modificar archivos del proyecto.
- Informe en español, exhaustivo pero conciso.
- Etiquetar cada afirmación: `[OFICIAL]`, `[COMUNIDAD]`, `[ESPECULATIVO]`.
- Toda afirmación lleva URL/evidencia. No inventar exports, ordinals ni offsets.
- Marcar explícitamente `[NO ENCONTRADO]` cuando no haya evidencia.
- 7 áreas: (1) evolución por build, (2) APIs internas, (3) comunidad 1809, (4) componentes/recursos 14393, (5) shells/herramientas alternativas, (6) captura en VM, (7) issues/foros.

## Research Findings

### Dark Mode oficial (Hecho [OFICIAL])
- Windows 10 October 2018 Update / **1809 (build 17763)** introdujo Dark Mode en File Explorer.
- Vía: **Settings > Personalization > Colors > "Choose your default Windows mode"**.
- Fuente Microsoft: https://blogs.windows.com/windowsexperience/2019/04/01/windows-10-tip-dark-theme-in-file-explorer/
- El blog de Windows Insider de 17733 dice: *"With Build 17666 we started our journey bringing dark theme to Explorer. Today's build marks the turning point where we've finished what we set out to do for this release"*. Contexto: el trabajo empezó en la rama RS5 (17666, Insider) y se **`flasheó` en 17733**, es decir **nunca estuvo en 14393**:
  - https://www.zdnet.com/article/windows-10-file-explorer-microsoft-shows-off-dark-theme-you-can-expect-this-fall/
  - https://onmsft.com/news/dark-theme-for-file-explorer-looks-better-in-latest-insider-build-but-its-still-not-perfect/
- Confirmación adicional por terceros: usuarios en 1803 reportan explícitamente que **no es nativo** y solo se arregla actualizando a 1809:
  - https://www.reddit.com/r/Windows10/comments/cfao9o/dark_file_explorer_theme_in_1803/
  - https://learn.microsoft.com/en-us/answers/questions/2818444/dark-theme-is-not-enabling-in-file-explorer
- **Conclusión para 14393: NO existe soporte nativo. `[OFICIAL]` + `[COMUNIDAD]` concordantes.**

### DwmSetWindowAttribute / DWMWINDOWATTRIBUTE ([OFICIAL])
- Enum oficial `DWMWINDOWATTRIBUTE`: https://learn.microsoft.com/en-us/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute
- La enum contiene **`DWMWA_USE_IMMERSIVE_DARK_MODE = 20`**, documentado como: *"Allows the window frame for this window to be drawn in dark mode colors when the dark mode system setting is enabled. For compatibility reasons, all windows default to light mode regardless of the system setting."* Tipo del valor: `BOOL`.
- Requisito mínimo declarado del enum: **Windows Vista** (o sea, `DwmSetWindowAttribute` sí existe en 14393).
- La documentación dice *"This value is supported starting with Windows 11 Build 22000"* → en **14393 el valor 20 no produce efecto**; en 1809/1903 el equivalente era el **valor 19** `[COMUNIDAD]`.
- **Dato clave: la función existe en 14393, pero el atributo de dark mode no está soportado.** Cambiar el marco de la ventana ≠ pintar el cliente de Explorer.

### APIs internas / ordinals de uxtheme ([COMUNIDAD] - Stack Overflow, no oficial)
Fuente base: https://stackoverflow.com/a/53545935/825024
- Ordinals reportados para build **17763**:
  - `ShouldAppsUseDarkMode` — ordinal 132
  - `AllowDarkModeForWindow` — ordinal 133
  - `AllowDarkModeForApp` — ordinal 135 (eliminada desde 18334)
  - `FlushMenuThemes` — ordinal 136
  - `IsDarkModeAllowedForWindow` — ordinal 137
  - `RefreshImmersiveColorPolicyState` — ordinal 104
  - `GetIsImmersiveColorUsingHighContrast` — ordinal 106
  - `OpenNcThemeData` — ordinal 49
- Desde Insider build **18334**:
  - `SetPreferredAppMode` — ordinal 135
  - `IsDarkModeAllowedForApp` — ordinal 139
- Advertencia: son APIs **no documentadas**; los ordinals son empíricos y pueden variar por build. No equivalen a "API oficial".
- **Evidencia decisiva**: el propio código `InitDarkMode()` de esa respuesta hace *gate* explícito:
  ```cpp
  if (major == 10 && minor == 0 && 17763 <= g_buildNumber && g_buildNumber <= 18363)
  ```
  Rango 17763–18363 (1809–1909). Por tanto, en **14393 esas funciones no se resuelven** y `g_darkModeSupported` queda en `false`.
- La misma respuesta documenta que incluso con la API correcta, *"it's not like 'call a function and that's it'"*:TreeView, ListView y partes del cliente requieren `WM_CTLCOLOR*` y custom draw manual.

### Vías comunitarias en 14393 — UltraUXThemePatcher ([COMUNIDAD] con evidencia de soporte)
- **UltraUXThemePatcher sí soporta explícitamente 1607/14393.** Modifica `uxtheme.dll`, `UXInit.dll` y `themeui.dll` para permitir temas de terceros, y hace backup para desinstalar.
- Página del autor (Manuel Hoefs): https://mhoefs.eu/software_uxtheme.php?lang=en
- Versión archivada que lista *"Anniversary Update 1607"* entre las soportadas: https://web.archive.org/web/20180629111636/www.syssel.net/hoefs/software_uxtheme.php?lang=en
- Neowin 3.1.5.0 (2016) confirma *"available for Windows XP to Windows 10 RTM and Anniversary Update 1607"*: https://www.neowin.net/software/ultrauxthemepatcher-3150/
- Neowin 3.3 (2017) añade 1703/1709: https://www.neowin.net/software/ultrauxthemepatcher-33/
- Requisito operativo recurrente: tomar *ownership* de los 3 DLL en System32 y ejecutar como Administrador.
- **Limitación crítica**: los temas son específicos por build. Un `.msstyles` de 14393 **no** funciona en 17763+ y viceversa.

### Vías comunitarias en 14393 — OldNewExplorer ([COMUNIDAD])
- Changelog: **v1.1.8.1 (Oct 2016) — "Support for build 14393"**. Evidencia directa:
  - https://www.softpedia.com/progChangelog/OldNewExplorer-Changelog-245412.html
  - https://www.shakeelfile.com/2022/10/Old-New-Explorer-Configuration.html
- v1.1.9 (Sep 2019) añade *"Support for disgusting dark mode"* — es decir, **soporte de dark mode nativo post-1809**, no un motor de tema oscuro.
- Autor: **Tihiy**; es una shell extension que hace hook de `explorer.exe`, **no** un reemplazo del shell. Descarga oficial: https://tihiy.net/files/OldNewExplorer.rar
- `[COMUNIDAD]` Thread MSFN del autor: https://msfn.org/board/topic/170375-oldnewexplorer-119/

### Combinación probada en 14393 ([COMUNIDAD]) — la única vía realista
Flujo documentado por usuarios y guías para 1607/14393:
1. **UltraUXThemePatcher** (parchea uxtheme/UXInit/themeui) — soporta 14393.
2. **OldNewExplorer** v1.1.8.1+ (hook de explorer) — soporta 14393.
3. Tema oscuro `.theme` + `.msstyles` **específico para build 14393**, copiado a `C:\Windows\Resources\Themes`.
4. Reiniciar explorer / sistema.

Fuentes:
- Reddit (método citado explícitamente para pre-1809): https://www.reddit.com/r/Windows10/comments/7zaa5i/dark_file_explorer/
- Guía con tema `Penumbra 10` validado explícitamente para builds 14393 y 15063: https://www.programmersought.com/article/31186072709/
- Tema "W10 Night" para 1607/1703/1709/1803, con instrucción explícita de parcheo y build 1607: https://www.deviantart.com/chloechantelle/art/W10-Day-and-Night-Visual-Styles-615270862
- Foro (ru) sobre themes en 14393 con UltraUXThemePatcher 3.0.8/3.1.0: https://7themes.su/forum/22-770-1
- Foro sobre 14393 + UxStyle + Signature Bypass: https://virtualcustoms.net/showthread.php/72488-Installing-themes-on-Windows-10-Anniversary-Update-1607-Build-14393-10-Redstone-One
- **Riesgos documentados por usuarios** en 14393: pantallas negra/azul, driver de video que da error, parpadeo, BSOD, necesidad de entrar en Safe Mode para revertir: https://7themes.su/forum/22-770-1

### Alternativas de shell / gestores de archivos ([COMUNIDAD])
- **Nilesoft Shell** declara soporte Win7/8/10/11: https://nilesoft.org/ — pero es un *personalizador de menús contextuales*, NO un reemplazo completo del shell.
- **StartIsBack++ 2.9.1** es la versión recomendada para **Windows 10 ≤ 1607 (14393)**: http://startisback.com/ y https://czsofts.com/startallback/
  - Aclaración: **modifica Start/taskbar/tray, no el cliente de File Explorer**. No aporta dark mode de Explorer.
- **StartAllBack** (v3.x) está orientado a Windows 11; su "System Requirements" en MS Store es genérico y poco confiable: https://apps.microsoft.com/detail/xpfmhkp3qhrqrh
- **ExplorerPatcher**: **"Not supported" en 14393** — descartado.
- Gestores de archivos alternativos con esquema oscuro: **FreeCommander**, **Directory Opus** — pueden reemplazar la UI, pero no es "File Explorer dark": https://www.reddit.com/r/Windows10/comments/cfao9o/dark_file_explorer_theme_in_1803/

### AppsUseLightTheme ([COMUNIDAD])
- https://stackoverflow.com/questions/53501268/win10-dark-theme-how-to-use-in-winapi
- Afirma: `HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize\AppsUseLightTheme` existía antes de 1809, pero inicialmente solo afectaba apps UWP; desde 1809 también afecta Explorer.
- Pendiente: corroborar exactamente cuándo aparece su efecto en Explorer con fuente Microsoft.

### ExplorerPatcher ([COMUNIDAD])
- Soporte oficial del proyecto: Windows 10 1607/14393 = **"Not supported"**. Soporte general desde 17763/1809.
- https://github.com/valinet/ExplorerPatcher/wiki/ExplorerPatcher's-taskbar-implementation
- https://github.com/valinet/ExplorerPatcher/discussions/898 (testado en 17763/19044; builds antiguos improbables)
- https://github.com/valinet/ExplorerPatcher/blob/master/CHANGELOG.md
- Conclusión: no es vía reproducible para 14393.

### Mach2 / WNF Feature Store ([COMUNIDAD])
- Modifica el Windows Feature Store; contiene feature `FileExplorerDarkTheme` ID `10397285`.
- https://github.com/riverar/mach2/commit/1e2590d3ef091f572c427f594c138f204a3513c1
- https://github.com/riverar/mach2/ (retirado; no compatible con Win10 2004+)
- Útil para 1809–1903; su aplicabilidad a 14393 no está verificada.

### AutoDarkMode ([COMUNIDAD])
- Issue #44: en LTSC 2019/1809 se requiere 1903 para el cambio nativo de tema del sistema.
- https://github.com/AutoDarkMode/Windows-Auto-Night-Mode/issues/44
- Sugiere que el dark mode nativo de sistema llegó más tarde que 1809 en algunos flujos.

### Windhawk ([COMUNIDAD])
- Permite limitar/habilitar inyección por proceso, incluido `explorer.exe`.
- https://github.com/ramensoftware/windhawk/discussions/21
- Pendiente: compatibilidad mínima con 14393.

### Nilesoft Shell ([COMUNIDAD])
- Declara soporte Windows 7/8/10/11: https://nilesoft.org/
- **Aclaración crítica**: es un *personalizador de menús contextuales*, NO un reemplazo completo del shell. No debe presentarse como "shell alternativo" en sentido amplio.

### Versiones de explorer.exe ([COMUNIDAD, secundaria])
- Fuente no oficial indica `explorer.exe` 10.0.14393.0: http://windowstasks.com/exe/explorer.exe
- Microsoft Answers muestra ejemplo de `explorer.exe` 10.0.14393.1532: https://learn.microsoft.com/en-us/answers/questions/2801310/explorer-exe-keeps-crashing-on-a-windows-server-20
- Ambas confirman que existe el binario en la familia 14393; no sustituyen manifests/CBS oficiales.

### Inyección DLL / AppInit_DLLs ([COMUNIDAD] - MITRE)
- Claves: `HKLM\...\Windows` y Wow6432Node. Se carga vía `user32.dll` en procesos que cargan user32.
- Deshabilitado con Secure Boot desde Windows 8.
- https://attack.mitre.org/techniques/T1546/010/
- No establece comportamiento práctico en 14393.

### Captura de pantalla en VM ([COMUNIDAD] - preliminar)
- Hyper-V/WMI `GetVirtualSystemThumbnailImage`: https://gist.github.com/BenjaminArmstrong/4e2c0df7ab62b909945b8d277f3e4b1a
- Pantalla negra por ahorro de energía al capturar consola: https://vcloudnine.de/creating-console-screenshots-with-get-screenshotfromvm-ps1/
- Pendiente: documentación oficial Hyper-V/VMware.

## Technical Decisions

| Decision | Rationale |
|----------|-----------|
| Tratar ordinals de Stack Overflow como [COMUNIDAD] empíricos, no como API oficial | No están documentadas por Microsoft; pueden variar por build |
| No afirmar ausencia/presencia de `dark.theme` sin inspectar ISO/manifests | La búsqueda web no es concluyente; se marcará [NO ENCONTRADO] |
| No proponer ExplorerPatcher como solución 14393 | El propio proyecto lo marca "Not supported" |
| No presentar Nilesoft como reemplazo total del shell | Solo personaliza menús contextuales |

## Issues Encountered

| Issue | Resolution |
|-------|------------|
| Búsqueda web no concluyente sobre `dark.theme` en 14393 | Pendiente: inspeccionar manifests de paquete/CBS o ISO oficial |
| `DwmSetWindowAttribute` sin documentación oficial suficiente | Pendiente: buscar SDK/Win32 docs y builds que lo implementan |
| No se localizó "DarkMode.exe" inequívoco para 1809 | Ampliar a parcheo binario de explorer.exe e inyección |

## Resources

- Microsoft blog Dark Mode Explorer: https://blogs.windows.com/windowsexperience/2019/04/01/windows-10-tip-dark-theme-in-file-explorer/
- Stack Overflow ordinals uxtheme: https://stackoverflow.com/a/53545935/825024
- Stack Overflow AppsUseLightTheme: https://stackoverflow.com/questions/53501268/win10-dark-theme-how-to-use-in-winapi
- ExplorerPatcher wiki: https://github.com/valinet/ExplorerPatcher/wiki/ExplorerPatcher's-taskbar-implementation
- ExplorerPatcher discussion #898: https://github.com/valinet/ExplorerPatcher/discussions/898
- Mach2 commit FileExplorerDarkTheme: https://github.com/riverar/mach2/commit/1e2590d3ef091f572c427f594c138f204a3513c1
- Mach2 repo: https://github.com/riverar/mach2/
- AutoDarkMode issue #44: https://github.com/AutoDarkMode/Windows-Auto-Night-Mode/issues/44
- Windhawk discussion #21: https://github.com/ramensoftware/windhawk/discussions/21
- Nilesoft Shell: https://nilesoft.org/
- windowstasks explorer.exe: http://windowstasks.com/exe/explorer.exe
- MS Answers explorer.exe 14393.1532: https://learn.microsoft.com/en-us/answers/questions/2801310/explorer-exe-keeps-crashing-on-a-windows-server-20
- MITRE AppInit_DLLs: https://attack.mitre.org/techniques/T1546/010/
- Hyper-V thumbnail gist: https://gist.github.com/BenjaminArmstrong/4e2c0df7ab62b909945b8d277f3e4b1a
- vcloudnine screenshot notes: https://vcloudnine.de/creating-console-screenshots-with-get-screenshotfromvm-ps1/

## Visual/Browser Findings

- Sin imágenes/PDFs procesados aún. Notas de blogs y repos capturadas como texto arriba.

---

# Hilo B: ¿Se pueden instalar apps Store/MSIX en 14393 (LTSB 2016)?

Investigación hecha en los dos turnos anteriores. Relevante porque cualquier herramienta de dark
mode distribution vía Store tendría que instalarse por esta vía en 14393.

## B.1 Soporte nativo de MSIX [OFICIAL]

- MSIX tiene soporte nativo desde **Windows 10 1709 (build 16299)** y posteriores. NO desde 1903.
  https://learn.microsoft.com/en-us/windows/msix/supported-platforms
- La misma página: la instalación de MSIX **vía Microsoft Store / Store for Business requiere 1809 (17763) o posterior**.
  Para 1709/1803/1809 Microsoft declara soportar escenarios *mainstream enterprise*:
  Intune, Microsoft Endpoint Configuration Manager, PowerShell e instalación con doble clic.
  https://learn.microsoft.com/en-us/windows/msix/supported-platforms
- Sideloading en versiones **anteriores a 2004** requiere Developer Mode o la política de grupo
  `AllowAllTrustedApps`.
  https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/msix-windows10-windows11
- `winget` requiere Windows 10 1809 (17763) o posterior; App Installer se distribuye vía Store.
  https://learn.microsoft.com/en-us/windows/package-manager/winget

### Tabla de features MSIX (extracto útil, [OFICIAL])
De https://learn.microsoft.com/en-us/windows/msix/supported-platforms

| Feature | 1809 (LTSC 2019) | 1903 | 2004 |
|---|---|---|---|
| Native MSIX install and uninstall | OK | OK | OK |
| App Installer File Support | OK | OK | OK |
| Force update from any version downgrade | OK | OK | OK |
| Package Support Framework (PSF) | OK | OK | OK |
| Windows services | NO | NO | OK |
| Package Integrity Enforcement (non-Store) | NO | NO | OK |
| Packages with external location | NO | NO | OK |

Implicación: 14393 no aparece en la tabla → **ninguna columna aplica**. Sobre 14393 solo cabe MSIX Core.

## B.2 MSIX Core — la vía oficialmente soportada en 14393 [OFICIAL]

- MSIX Core es el proyecto open source que permite instalar MSIX en Windows anteriores a 1709
  (Win7 SP1, 8.1, Windows 10 <1709, Windows Server con Desktop Experience).
  https://learn.microsoft.com/en-us/windows/msix/msix-core/msixcore
- Limitaciones declaradas por Microsoft:
  - **No** da los beneficios de contenedor de MSIX nativo.
  - **No** habilita a una app que use features específicas de Windows 10 a funcionar en versiones anteriores.
    (→ una app que REQUIRE 19041 no se vuelve compatible por estar en MSIX Core.)
  - App execution aliases solo funcionan desde Win+R, no desde cmd ni PowerShell.
  https://learn.microsoft.com/en-us/windows/msix/msix-core/msixcore
- **Tabla oficial de versiones soportadas — 14393 aparece explícitamente:**
  - Windows 10 2016 LTSB (1607) → `10.0.14393.0`
  - Windows Server 2016 → `10.0.14393.0`
  https://learn.microsoft.com/en-us/windows/msix/msix-core/support-msix-core
- Requisito de manifest para que un paquete acepte MSIX Core:
  ```xml
  <Dependencies>
    <TargetDeviceFamily Name="MSIXCore.Desktop" MinVersion="10.0.14393.0" MaxVersionTested="10.0.18362.0" />
    <TargetDeviceFamily Name="Windows.Desktop"     MinVersion="10.0.16299.0" MaxVersionTested="10.0.18362.0" />
  </Dependencies>
  ```
  https://learn.microsoft.com/en-us/windows/msix/msix-core/support-msix-core
- El binario es `msixmgr.exe`; **no** tiene soporte en Windows Server Core.
  https://github.com/microsoft/msix-packaging/blob/master/MsixCore/README.md
- MSIX Packaging Tool desde **1.2020.402.0** puede inyectar soporte MSIX Core al convertir un instalador.
  https://learn.microsoft.com/en-us/windows/msix/msix-core/support-msix-core
- Error a esperar en down-level: **`0x8BAD0042` CertNotTrusted** — Microsoft lo describe como
  "commonly seen when using MSIX Core on down-level Windows"; solución: importar el certificado en
  **Local Computer > Trusted People** (no el almacén del usuario).
  https://learn.microsoft.com/en-us/windows/msix/desktop/managing-your-msix-deployment-troubleshooting

## B.3 Tooling: MakeAppx con MSIX llegó en 1809, no en 1903 [OFICIAL]

- Las notas de build **17763 (1809)** listan, por primera vez, "MSIX", "MSIX Packaging Tool",
  "Desktop App Converter `-MakeMSIX`" y "**MakeAppx.exe tool support for MSIX**".
  https://learn.microsoft.com/en-us/windows/uwp/whats-new/windows-10-build-17763
  → Corrijo la premisa previa de que el tooling MSIX venía con 1903. Viene con 1809.
- El Windows Application Packaging Project de Visual Studio sí soporta 1607 (14393) o posterior.
  https://github.com/microsoftdocs/msix-docs/blob/main/msix-src/desktop/desktop-to-uwp-packaging-dot-net.md

## B.4 Cmdlets Appx disponibles en 2016/14393 [OFICIAL, con cautela]

- Referencia `Add-AppxPackage` con moniker `windowsserver2016-ps`: **no** expone `-SkipLicense`,
  `-AllowUnsigned` ni `-ExternalLocation`.
  https://learn.microsoft.com/en-us/powershell/module/appx/add-appxpackage?view=windowsserver2016-ps
- Advertencia metodológica: este moniker es de **Windows Server 2016**, no de Windows 10 build 14393.
  Es el proxy más cercano disponible, no prueba definitiva. No pude ejecutar `Get-Command Add-AppxPackage
  -Syntax` en un 14393 real.

## B.5 Tabla de errores MSIX [OFICIAL salvo donde se indica]

Fuente: https://learn.microsoft.com/en-us/windows/msix/desktop/managing-your-msix-deployment-troubleshooting

| Código | Significado oficial |
|---|---|
| 0x80073CF0 | ERROR_INSTALL_OPEN_PACKAGE_FAILED — no se pudo abrir el archivo |
| 0x80073CF3 | ERROR_INSTALL_PACKAGE_DOWNGRADE — ya hay versión más nueva |
| 0x80073CF9 | ERROR_INSTALL_PACKAGE_NOT_FOUND — falta paquete o dependencia |
| 0x80073CFA | ERROR_REMOVE_FAILED |
| 0x80073CFB | ERROR_PACKAGE_ALREADY_EXISTS |
| 0x80073D02 | ERROR_PACKAGES_IN_USE — recursos en uso |
| 0x8007000D | ERROR_INVALID_DATA — publisher del manifest no coincide con el certificado |
| 0x8BAD0042 | CertNotTrusted — típico de MSIX Core en down-level |

**Discrepancia registrada [OBSERVADA, no oficial]:** `0x80073CF3` aparece en la práctica con dos textos
distintos. La tabla oficial dice "downgrade", pero el texto real observado cuando falta un framework es
*"Package failed updates, dependency, or conflict validation ... this package depends on a framework
that could not be found"*.
https://github.com/microsoft/terminal/issues/18033
https://learn.microsoft.com/en-us/answers/questions/3967869/where-to-download-microsoft-vclibs-140-00-uwpdeskt
→ Conclusión: **no confiar en el significado del HRESULT aislado**; leer siempre el mensaje completo.

- `0x80073CFD` = "The package requires OS version 10.0.19041.0 or higher on the Windows.Universal
  device family. The device is currently running OS version 10.0.18363.1440."
  https://learn.microsoft.com/en-us/answers/questions/4128101/the-package-requires-os-version-10-0-19041-0-or-hi

## B.6 Caso real reproducible en 1607 [COMUNIDAD, acceso parcial]

- StackOverflow 64773827 "Unable to install MSIX package on Windows 2016 (build 1607)":
  - `.msixbundle` **no** se soporta nativamente → "msixbundle are not supported".
  - MSIX Core (`msixmgr.exe -Unpack ...`) sí instala el paquete principal.
  - Las **dependencias** (`Microsoft.VCLibs*.appx` de la carpeta Dependencies) fallan con
    **`0x80070490 — Unable to open package`**, y la app luego no arranca por falta de esas librerías.
  https://stackoverflow.com/questions/64773827/unable-to-install-msix-package-on-windows-2016-build-1607
- Limitación de acceso: la página devuelve **403** al agente; el contenido anterior proviene del
  resultado de búsqueda, no de la página leída. Marcar como [COMUNIDAD, no verificado en página].

## B.7 Requisitos reales de apps del Store (MinVersion) [OFICIAL, vía ficha del producto]

| App | MinVersion declarado | ¿Sirve en 14393? |
|---|---|---|
| WhatsApp | Windows 10 version **19041.0** | NO — https://www.microsoft.com/en-bm/p/whatsapp/9nksqgp7f2nh |
| Netflix | Windows 10 version **19041.0** | NO — https://apps.microsoft.com/detail/9wzdncrfj3tj |
| Windows Terminal | Windows 10 version **19041.0** | NO — https://apps.microsoft.com/detail/9n0dx20hk701 |
| Spotify | Windows 10 version **17763.0** | NO — https://apps.microsoft.com/detail/9ncbcszsjrsb |
| Minecraft UWP (caso real) | 10.0.19041.0, device 18363 | NO — https://learn.microsoft.com/en-us/answers/questions/4128101/ |

- Windows Terminal: el mantenedor confirma que **incluso la versión más antigua requería 18362**, y que
  XAML Islands no funciona por debajo de 18362.
  https://github.com/microsoft/terminal/issues/15765
  https://github.com/microsoft/terminal/blob/main/README.md
  https://devblogs.microsoft.com/commandline/windows-terminal-preview-1-13-release

**Conclusión fuerte:** ninguna app de consumo del Store analyzed es instalable en 14393, ni siquiera
vía MSIX Core, porque declaran MinVersion 17763/19041. MSIX Core no reescribe el MinVersion de apps
de terceros ya publicadas. Para 14393 hay que buscar **distribuciones no-MSIX** (portable/EXE/MSI)
de esas mismas apps, no el paquete del Store.

## B.8 VCLibs / framework packages en 14393 [PARCIAL]

- Los framework packages se obtienen del SDK en
  `%ProgramFiles(x86)%\Microsoft SDKs\Windows Kits\10\ExtensionSDKs\Microsoft.VCLibs.Desktop\14.0\Appx\Retail\x64\Microsoft.VCLibs.x64.14.00.Desktop.appx`
  https://devdocs.xbox.com/build/core-features/common/packaging/packaging-framework-packages
- El paquete oficial de descarga "Microsoft Visual C++ UWP Desktop Runtime Package" declara
  *"Supported Operating Systems: Windows 10, Windows Server 2019, Windows 11"* — **no menciona 2016/14393**.
  https://www.microsoft.com/en-gb/download/details.aspx?id=102159
- Dependencias se pueden pasar en un solo comando: `Add-AppxPackage main.msix -DependencyPath dep1.msix,dep2.msix`
  https://learn.microsoft.com/en-us/windows/msix/desktop/managing-your-msix-deployment-troubleshooting
- `[NO ENCONTRADO]` evidencia oficial de que las versiones concretas de `Microsoft.VCLibs.140.00.UWPDesktop`
  exigidas por apps moderne declaren `TargetDeviceFamily` compatible con 10.0.14393.0. Requiere
  inspeccionar el manifest real de cada appx.

## B.9 Ausencia de Microsoft Store en LTSB 2016 [COMUNIDAD, no oficial]

- La página oficial de "What's new in Windows 10 Enterprise LTSC 2016" confirma que las features son
  equivalentes a 1607 y que **Microsoft Edge (Chromium) no está incluido** en LTSC, pero no afirma
  explícitamente la ausencia del Store en este artículo.
  https://learn.microsoft.com/en-us/windows/whats-new/ltsc/whats-new-windows-10-2016
- `[COMUNIDAD]` LTSC excluye Windows Store, la mayoría de Cortana y la mayoría de apps empaquetadas
  (incluido Edge). https://wiki.seekkey.tech/wiki/Windows_10_editions
- `[COMUNIDAD]` Comentario en el blog oficial de Terminal: "Microsoft does not support running Store on
  Windows 10 LTSC."
  https://devblogs.microsoft.com/commandline/windows-terminal-preview-1-13-release
- `[NO ENCONTRADO]` una página oficial de lifecycle/IT Pro que declare la ausencia del Store. Pendiente.

## B.10 Ciclo de vida y actualización [OFICIAL / COMUNIDAD]

- Lifecycle oficial: Windows 10 2016 LTSB, fin de soporte extendido **2026-10-13**.
  https://learn.microsoft.com/en-us/lifecycle/products/windows-10-2016-ltsb
- Matriz de rutas de actualización: https://learn.microsoft.com/en-us/windows/deployment/upgrade/windows-upgrade-paths
- Cambios de edición: https://learn.microsoft.com/en-us/windows/deployment/upgrade/windows-edition-upgrades
- `[COMUNIDAD]` Cita de la documentación oficial: *"This was corrected in the Windows 10 LTSC 2016
  release, which will now only allow data-only and clean install options."* → el in-place upgrade a LTSC
  desde canal semi-annual **no está soportado oficialmente**.
  https://windowsreport.com/windows-7-windows-10-ltsb-upgrade
- `[COMUNIDAD]` El método que circula (editar `EditionID`/`ProductName`/`CurrentBuild`/`DisplayVersion`
  en el registro y montar el ISO de LTSC 2021 con "Keep personal files and apps") es **no soportado**.
  https://www.wintips.org/how-to-upgrade-to-windows-10-ltsc-without-losing-data
  https://pureinfotech.com/upgrade-windows-10-to-ltsc
- `[COMUNIDAD]` Microsoft ofrece ESU de pago para LTSB 2016: 61 USD/dispositivo el primer año,
  disponible desde Q2 2026 por Volume Licensing.
  https://www.windowscentral.com/microsoft/windows-11/microsoft-preps-esu-for-windows-10-ltsb-releases-retiring-in-2026
  → **[ESPECULATIVO / sin verificar]** No pude abrir el anuncio del Windows IT Pro Blog para confirmar
  cifras y fechas en la fuente primaria.

## B.11 StoreLib y descarga sin Store [COMUNIDAD]

- `StoreDev/StoreLib` — biblioteca C# para consultar los endpoints públicos del Store y obtener
  enlaces de descarga de paquetes. https://github.com/StoreDev/StoreLib
- `[NO ENCONTRADO]` No localicé un proyecto `StoreLibPRO`. No se ha verificado qué endpoint consume
  exactamente, ni los headers/autorización que exige `displaycatalog.mp.microsoft.com/v9.0`.
- `[NO ENCONTRADO]` No verifiqué `store.rg-adguard.net`. Riesgo conocido: los enlaces firmados por
  Microsoft se sirven a través de `tlu.dl.delivery.mp.microsoft.com`; los mirrors de terceros pueden
  dejar de funcionar y no son un canal soportado. No afirmar que funcionen sin probarlos.

## B.12 Búsquedas que quedaron [NO ENCONTRADO]

1. Evidencia oficial de que LTSB 2016 no incluye Microsoft Store.
2. Evidencia (oficial o comunitaria) de que renombrar `.msix` → `.appx` permite instalar en 14393.
   → Mi lectura: **no**. El contenedor es una variante de OPC; la diferencia de compatibilidad está en
   el manifest y en el OS, no en la extensión. Marcado como [ESPECULATIVO] / no usar.
3. Sintaxis real de `Get-AppxPackage` / `Remove-AppxPackage` / `Add-AppxProvisionedPackage` en 14393.
4. `TargetDeviceFamily MinVersion` real (no la ficha del Store) de Spotify/WhatsApp/Netflix/Terminal.
5. Disponibilidad de `Microsoft.StorePurchaseApp` en 14393 y su `MinVersion`.

---

*Actualizar regularmente durante la investigación para preservar evidencia.*

# 03 — Objetivo de investigación A: Dark Mode en File Explorer de Windows 10 14393

Estado: **investigación cerrada a nivel documental. Sin verificación experimental todavía.**

Comparación de referencia: Windows 10 21H2 (build 19044), que el usuario tiene como sistema de
comparación.

---

## 1. Veredicto

**No existe Dark Mode nativo en File Explorer de 14393.** No es una limitación de configuración: el
código que lo implementa se desarrolló en una rama de Insider posterior y se flasheó en 1809.
Microsoft nunca lo retroportó.

La vía **reproducible y documentada** es temática, no nativa:
**UltraUXThemePatcher + OldNewExplorer + un tema `.msstyles`/`.theme` compilado para build 14393.**

Esto no es "imposible", pero es un camino distinto al que el usuario suponía (parcheo de DLL de
Explorer o activación de una API oculta). La evidencia de por qué es el único camino viable está
abajo, sección por sección.

---

## 2. Evolución del Dark Mode por build

| Build | Versión | Estado en Explorer | Etiqueta |
|---|---|---|---|
| 14393 | 1607 / LTSB 2016 | **Nada**. No hay APIs, ni flags, ni tema oscuro nativo | `[OFICIAL]` |
| 17666 | Insider RS5 | Inicio del desarrollo interno del tema de Explorer | `[OFICIAL]` |
| 17733 | Insider | "Turning point" — el trabajo termina para esa release | `[OFICIAL]` |
| 17763 | 1809 | **Primer build donde existe Dark Mode en Explorer** (no expuesto en UI) | `[OFICIAL]` |
| 18334 | Insider | `SetPreferredAppMode` reemplaza a `AllowDarkModeForApp` | `[COMUNIDAD]` |
| 18362/18363 | 1903 / 1909 | Fin del rango de las APIs internas de dark; empieza el dark mode oficial | `[COMUNIDAD]` |
| 19041+ | 20H1+ | `DWMWA_USE_IMMERSIVE_DARK_MODE` documentado por Microsoft | `[OFICIAL]` |

### `[OFICIAL]` El Dark Mode de Explorer nació en 1809

Blog de Windows Insider, con cita textual: *"With Build 17666 we started our journey bringing dark
theme to Explorer. Today's build marks the turning point where we've finished what we set out to do
for this release."*

https://blogs.windows.com/windowsexperience/2019/04/01/windows-10-tip-dark-theme-in-file-explorer/

El trabajo empezó en 17666 (rama RS5, posterior a 14393) y llegó a GA en 17733/17763. **Nunca
estuvo en 14393.**

### `[COMUNIDAD]` Confirmación por terceros

Usuarios en 1803 reportan explícitamente que no es nativo y que la única forma de obtenerlo es
actualizar a 1809:
- https://www.reddit.com/r/Windows10/comments/cfao9o/dark_file_explorer_theme_in_1803/
- https://learn.microsoft.com/en-us/answers/questions/2818444/dark-theme-is-not-enabling-in-file-explorer

---

## 3. APIs internas de uxtheme.dll y por qué no existen en 14393

### `[OFICIAL]` DwmSetWindowAttribute sí existe en 14393, pero no sirve

`DwmSetWindowAttribute` está documentada desde **Windows Vista**, así que existe en 14393. El enum
`DWMWINDOWATTRIBUTE` incluye `DWMWA_USE_IMMERSIVE_DARK_MODE = 20`, documentado como *"supported
starting with Windows 11 Build 22000"*.

https://learn.microsoft.com/en-us/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute

Dos razones por las que esta vía no resuelve el problema en 14393:

1. El valor 20 no está soportado. En 1809/1903 el equivalente era el valor **19** `[COMUNIDAD]`.
2. **Aunque funcionara, pintaría el marco de la ventana, no el área de cliente de Explorer.**
   Dark Mode en Explorer no es un efecto de ventana; es lógica de dibujo en el propio shell.

### `[COMUNIDAD]` Ordinals de uxtheme para dark mode

Fuente: https://stackoverflow.com/a/53545935/825024 (respuesta con código `InitDarkMode()`)

| Función | Ordinal (17763) | Notas |
|---|---|---|
| `RefreshImmersiveColorPolicyState` | 104 | |
| `GetIsImmersiveColorUsingHighContrast` | 106 | |
| `OpenNcThemeData` | 49 | no es de dark mode |
| `ShouldAppsUseDarkMode` | 132 | |
| `AllowDarkModeForWindow` | 133 | |
| `AllowDarkModeForApp` | 135 | eliminada desde 18334 |
| `FlushMenuThemes` | 136 | |
| `IsDarkModeAllowedForWindow` | 137 | |

Desde Insider 18334: `SetPreferredAppMode` (135), `IsDarkModeAllowedForApp` (139).

**Advertencia metodológica:** son APIs no documentadas. Los ordinals son empíricos y pueden variar por
build. Tratarlos como "API oficial" sería incorrecto.

### `[COMUNIDAD]` La evidencia decisiva

El propio código de referencia hace un gate explícito de versión:

```cpp
if (major == 10 && minor == 0 && 17763 <= g_buildNumber && g_buildNumber <= 18363)
```

Rango **17763–18363** (1809–1909). En 14393 esas funciones ni siquiera se resuelven dinámicamente y
`g_darkModeSupported` queda en `false`.

La misma fuente aclara que **incluso con la API correcta no basta**: *"it's not like 'call a function
and that's it'"*. TreeView, ListView y partes del cliente de Explorer requieren `WM_CTLCOLOR*` y
custom draw manual.

### `[NO ENCONTRADO]`

- Exports/ordinals de `uxtheme.dll` **de la build 14393** specifically. Nadie los ha publicado
  porque no tienendark mode que exponer.
- Si 14393 ya incluye un `dark.theme` en `C:\Windows\Resources\Themes` que Explorer simplemente no
  usa. La búsqueda web no es concluyente. **Esto se puede resolver experimentalmente** extrayendo
  el recurso del ISO, y está en la cola de experimentos.
- Cualquier herramienta tipo "DarkMode.exe" para 1809 pre-1909. El término devuelve ransomware.

---

## 4. La vía reproducible en 14393

### Paso 1 — UltraUXThemePatcher (parchea uxtheme/UXInit/themeui)

`[COMUNIDAD]` Soporta explícitamente **1607 / 14393**.

Modifica tres DLL de sistema para permitir temas de terceros, y hace backup para desinstalar.

- Página del autor: https://mhoefs.eu/software_uxtheme.php?lang=en
- Versión archivada listando *"Anniversary Update 1607"*: https://web.archive.org/web/20180629111636/www.syssel.net/hoefs/software_uxtheme.php?lang=en
- Neowin 3.1.5.0 (2016) confirma *"available for Windows XP to Windows 10 RTM and Anniversary
  Update 1607"*: https://www.neowin.net/software/ultrauxthemepatcher-3150/

Requisito operativo: tomar *ownership* de las tres DLL y ejecutar como Administrador.

### Paso 2 — OldNewExplorer v1.1.8.1 (hook de explorer.exe)

`[COMUNIDAD]` El changelog de **v1.1.8.1 (oct 2016) dice literalmente "Support for build 14393"**.

- https://www.softpedia.com/progChangelog/OldNewExplorer-Changelog-245412.html
- Autor: **Tihiy**. https://tihiy.net/files/OldNewExplorer.rar
- Thread MSFN del autor: https://msfn.org/board/topic/170375-oldnewexplorer-119/

Nota: es una shell extension que hace hook de `explorer.exe`, **no** un reemplazo del shell.

Dato revelador: la versión **v1.1.9 (sep 2019)** añade *"Support for disgusting dark mode"* — es
soporte del dark mode **nativo post-1809**, no un motor de tema oscuro. En 14393 hay que usar la
1.1.8.x.

### Paso 3 — Tema oscuro específico para build 14393

`[COMUNIDAD]` Los temas **no son portables entre builds**. Un `.msstyles` de 14393 no funciona en
17763+ y viceversa. Hay que conseguir o construir un tema compilado contra 14393.

- Guía con tema `Penumbra 10` validado explícitamente para builds **14393 y 15063**:
  https://www.programmersought.com/article/31186072709/
- Tema "W10 Night" para 1607/1703/1709/1803, con instrucción de parcheo:
  https://www.deviantart.com/chloechantelle/art/W10-Day-and-Night-Visual-Styles-615270862
- Reddit describiendo el método para builds pre-1809:
  https://www.reddit.com/r/Windows10/comments/7zaa5i/dark_file_explorer/

### ⚠ Riesgo documentado por usuarios

El parcheo de DLL de sistema en 14393 tiene reportes de **pantallas negras, errores de driver de
video, parpadeo y BSOD**, con necesidad de entrar en Safe Mode para revertir.

https://7themes.su/forum/22-770-1

Esto refuerza la regla del laboratorio: **esto se prueba solo dentro de la VM descartable, nunca
sobre una instalación real.** Y sugiere capturar evidencia *antes* del parcheo, porque el estado
alterado puede ser irrecuperable sin snapshot.

---

## 5. Alternativas descartadas

| Herramienta | Motivo | Etiqueta |
|---|---|---|
| **ExplorerPatcher** | El propio proyecto marca **"Not supported"** en 14393. Soporte desde 17763. | `[COMUNIDAD]` https://github.com/valinet/ExplorerPatcher/wiki/ExplorerPatcher's-taskbar-implementation |
| **StartIsBack++ 2.9.1** | Hay versión para ≤1607, pero modifica Start/taskbar/tray, **no el cliente de Explorer**. | `[COMUNIDAD]` http://startisback.com/ |
| **StartAllBack** | Orientado a Windows 11. No aporta nada a 14393. | `[COMUNIDAD]` |
| **Nilesoft Shell** | Parece un reemplazo de shell, pero **solo personaliza menús contextuales**. No reemplaza Explorer. | `[COMUNIDAD]` https://nilesoft.org/ |
| **Mach2** | Modifica el Windows Feature Store; útil para 1809–1903. Aplicabilidad a 14393 **no verificada**. | `[COMUNIDAD]` https://github.com/riverar/mach2/ |
| **AutoDarkMode** | Issue #44 reporta que LTSC 2019/1809 requiere 1903 para el cambio nativo. No sirve en 14393. | `[COMUNIDAD]` https://github.com/AutoDarkMode/Windows-Auto-Night-Mode/issues/44 |
| **Windhawk** | Permite inyectar por proceso (incluido explorer.exe). **Compatibilidad mínima con 14393 sin verificar** — candidato a probar. | `[COMUNIDAD]` https://github.com/ramensoftware/windhawk/discussions/21 |
| **Gestores de archivos alternativos** (FreeCommander, Directory Opus) | Reemplazan la UI pero **no son "File Explorer"**. Cambian el objeto de estudio. | `[COMUNIDAD]` |

### Windhawk: la línea abierta más interesante

`[COMUNIDAD]` Windhawk permite hooks por proceso y se usa justamente para—injectar dark mode en
Explorer en builds donde no existe. No encontré evidencia de su **versión mínima de Windows
compatible**. Si declara soporte de 1607/14393, sería una vía más limpia que los dos parcheadores
anteriores, porque no modifica DLL de sistema.

**Marcado como la primera hipótesis a probar dentro de la VM.**

---

## 6. Experimentos derivados, en orden

| ID | Hipótesis | Por qué |
|---|---|---|
| EXP-010 | 14393 **no** tiene ningún soporte de dark mode en Explorer | Confirmar el punto de partida con evidencia propia: exports de uxtheme, flags de registro, presencia de `dark.theme` |
| EXP-011 | El sistema de comparación **21H2 (19044) sí** lo tiene, vía registro | Establecer el control: qué cambia exactamente entre 14393 y 19044 |
| EXP-012 | El diff de `uxtheme.dll` / `explorerframe.dll` entre ambos builds explica el cambio | Comparación binaria: sizes, hashes, exports |
| EXP-020 | Windhawk inyecta dark mode en 14393 sin tocar DLL de sistema | Si funciona, es la vía más limpia y reversible |
| EXP-021 | UltraUXThemePatcher + OldNewExplorer produce dark mode funcional | Vía de comunidad documentada |
| EXP-022 | El tema Penumbra 10 específico de 14393 se renderiza correctamente | El tema correcto importa tanto como los parcheadores |

Cada uno con su registro en `experimentos/`.

---

## 7. Recursos

- Microsoft, Dark Mode en Explorer: https://blogs.windows.com/windowsexperience/2019/04/01/windows-10-tip-dark-theme-in-file-explorer/
- Stack Overflow, ordinals uxtheme: https://stackoverflow.com/a/53545935/825024
- Microsoft, enum DWM: https://learn.microsoft.com/en-us/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute
- UltraUXThemePatcher: https://mhoefs.eu/software_uxtheme.php?lang=en
- OldNewExplorer: https://tihiy.net/files/OldNewExplorer.rar
- ExplorerPatcher wiki: https://github.com/valinet/ExplorerPatcher/wiki/ExplorerPatcher's-taskbar-implementation
- Windhawk: https://github.com/ramensoftware/windhawk
- Lifecycle de 14393 (fin de soporte extendido 2026-10-14): https://learn.microsoft.com/en-us/lifecycle/products/windows-10-2016-ltsb

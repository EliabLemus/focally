---
id: TASK-030
created: 2026-05-05T18:18:00-06:00
status: pending
agent: codex
priority: high
---

# TASK-030: Fix Light theme application

## Entorno
- CWD: /Users/openjaime/.openclaw/workspace/projects/focally
- Stack: Swift 6, SwiftUI, AppKit, macOS 14+
- Runtime check: `swift --version`
- Tests: `xcodebuild -scheme Focally -configuration Debug build`

## Archivos relevantes
- `Focally/Views/MainWindow.swift` — hoy aplica `.preferredColorScheme(selectedTheme.preferredColorScheme)`
- `Focally/Views/Settings/AppearanceSettingsView.swift` — cambia `@AppStorage("appTheme")`
- `Focally/OnItFocusApp.swift` — crea el popover y la ventana principal vía `NSHostingController` / `NSWindow`
- `Focally/DesignSystem/FocallyTheme.swift` — definición de `ThemeChoice`
- `Focally/Assets.xcassets/focallyBackground.colorset/Contents.json` — confirma que sí existen variantes light/dark
- `SPEC_V0.6.6_BUG_FIXES.md` — contexto del bug #1

## Objetivo
Hacer que seleccionar `Light` en Appearance realmente fuerce la app a modo claro de forma inmediata y consistente. `Dark` debe forzar oscuro y `System` debe volver a seguir el tema del sistema.

## Criterios de aceptación
- [ ] Seleccionar `Light` en Appearance cambia la app a light inmediatamente
- [ ] Seleccionar `Dark` cambia la app a dark inmediatamente
- [ ] Seleccionar `System` vuelve a seguir el tema del sistema
- [ ] El cambio aplica al menos a la ventana principal; idealmente también al popover del menú si comparte el mismo theme pipeline
- [ ] Reabrir la ventana / popover mantiene el tema elegido vía `@AppStorage("appTheme")`
- [ ] No depende de cerrar/reabrir la app para verse reflejado
- [ ] Build pasa: `xcodebuild -scheme Focally -configuration Debug build`

## Constraints (lo que NO se puede hacer)
- NO tocar la paleta de colores de assets; ya tienen variantes light/dark correctas
- NO introducir dependencias nuevas
- NO degradar `System` a un modo fijo
- NO hacer push ni commits; solo cambios locales
- Mantener el flujo actual de Settings / Appearance

## Fuera de scope
- Rediseño visual del panel Appearance
- Ajustes finos de contraste por componente fuera de lo estrictamente necesario para que el theme cambie
- Cambios en sonidos, DND o navegación

## Contexto adicional
Hallazgos ya verificados:
- `ThemeChoice.light` ya devuelve `.light`
- `MainWindow` ya usa `.preferredColorScheme(selectedTheme.preferredColorScheme)`
- No encontré otro override global obvio de `NSAppearance` en el código actual
- Los assets (`focallyBackground`, `focallyOnSurface`, etc.) sí tienen variantes correctas para luminosidad light/dark

Eso sugiere que el problema está en cómo se aplica el tema al árbol SwiftUI/AppKit, especialmente porque la app crea su `NSWindow` y `NSPopover` manualmente desde `AppDelegate`.

**Enfoque preferido:**
Implementar una ruta robusta de aplicación del tema a nivel AppKit + SwiftUI, por ejemplo:
- centralizar el theme actual a partir de `appTheme`
- aplicar `NSAppearance` apropiado al `NSApp`, `mainWindow` y/o `popover` cuando cambie el valor
- mantener `.preferredColorScheme(...)` donde ayude, pero no depender solo de eso si no está propagando bien
- observar cambios de `appTheme` para refresco inmediato

Si descubres una solución más pequeña que compile y cumpla todos los criterios, úsala; pero no improvises cambios amplios.

---
## Result ← Codex llena esta sección al terminar

- Status: done
- Resumen: Se reforzó la aplicación de tema en `AppDelegate` para que `appTheme` no dependa solo de `.preferredColorScheme` dentro de SwiftUI. Ahora el valor guardado se observa vía `UserDefaults.didChangeNotification` y se traduce a `NSAppearance` para `NSApp`, la ventana principal y el popover, con reaplicación al abrirlos.
- Archivos modificados:
  - `Focally/OnItFocusApp.swift` — agregada observación de `appTheme` y aplicación explícita de `NSAppearance(.aqua/.darkAqua/nil)` a AppKit surfaces existentes
- Tests: pasaron — `xcodebuild -scheme Focally -configuration Debug build` → `** BUILD SUCCEEDED **`
- Notas: Se mantuvo intacto `MainWindow.preferredColorScheme(...)` como respaldo en SwiftUI y el fix se limitó al pipeline AppKit donde se crea manualmente `NSWindow`/`NSPopover`. No hice validación visual manual en esta ejecución; la confirmación disponible aquí es de compilación y de wiring del theme pipeline.
- Bloqueado por: n/a

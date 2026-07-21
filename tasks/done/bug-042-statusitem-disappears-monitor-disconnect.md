# BUG-042: Focally desaparece al desconectar monitores

## Problema
Al desconectar monitores externos y dejar solo el monitor más pequeño, Focally desaparece completamente de la barra de menú. No hay forma de recuperarlo sin relanzar la app.

## Análisis
- `OnItFocusApp.swift` crea el `NSStatusItem` en `applicationDidFinishLaunching` y lo guarda en `private var statusItem: NSStatusItem?`
- **No hay observador** para `NSApplication.didChangeOcclusionStateNotification` ni `NSScreen.didChangeNotification`
- Cuando macOS reorganiza pantallas al desconectar un monitor, el NSStatusItem puede perder su referencia o la barra puede recrearse
- macOS 14+ tiene comportamiento documentado donde NSStatusItem puede volverse nil después de cambios de pantalla

## Solución propuesta
1. Observar `NSScreen.didChangeNotification` y recrear el statusItem si es nil
2. En `togglePopover`, verificar que `statusItem` exista; si no, recrearlo
3. Guardar el estado actual (¿había sesión activa?) para restaurar el updateStatusBar después de recrear
4. Considerar también `NSApplication.didChangeScreenParametersNotification` como backup

## Implementación
```
// En applicationDidFinishLaunching, después de crear statusItem:
NotificationCenter.default.addObserver(
    self, selector: #selector(screenDidChange),
    name: NSScreen.didChangeNotification, object: nil
)

@objc func screenDidChange() {
    if statusItem == nil {
        setupStatusBar()  // Extraer la creación del statusItem a su propio método
    }
}
```

## Archivos
- `Focally/OnItFocusApp.swift` — refactor `setupStatusBar()`, agregar observer

## Criterios de aceptación
- Desconectar un monitor NO hace desaparecer Focally
- Reconectar un monitor NO hace desaparecer Focally
- Si el statusItem se pierde, se recrea automáticamente
- El estado de la sesión activa se mantiene
- Build + tests pasan

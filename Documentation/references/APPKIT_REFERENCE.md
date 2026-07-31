# APPKIT_REFERENCE.md — Referencia de AppKit

> **Nota**: AppKit solo cuando sea necesario. SwiftUI first.

---

## Cuándo usar AppKit

Usar AppKit solo cuando:
1. Necesitas acceso a APIs no disponibles en SwiftUI
2. Necesitas integración deep con macOS
3. Performance crítica

**NO usar para UI básica** — SwiftUI es suficiente.

---

## Common Patterns

### NSStatusBar (legacy)
```swift
// ✅ Preferir MenuBarExtra (SwiftUI, macOS 14+)
MenuBarExtra("Focally", systemImage: "calendar") { }

// ❌ Solo usar NSStatusBar si MenuBarExtra no es suficiente
let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
statusItem.button.title = "Focally"
```

### NSWorkspace
```swift
// Abrir URL
NSWorkspace.shared.open(URL(string: "https://calendar.google.com")!)

// Activar app
NSWorkspace.shared.activate(application: .finder)
```

### NSApplication
```swift
// Ocultar dock icon (para menubar apps)
NSApp.setActivationPolicy(.accessory)

// Terminar app
NSApplication.shared.terminate(nil)
```

---

## Do Not Disturb

### DNDService (Focally)
```swift
// Usar DNDService wrapper en lugar de AppKit directo
DNDService.shared.setEnabled(true)
```

### AppKit directo (solo si necesario)
```swift
// Check DND status
let dndEnabled = NSWorkspace.shared.isDoNotDisturbEnabled

// Set DND (requiere permissions)
// NOTA: macOS 15+ requiere explicit permissions
```

---

## Referencias

- [AGENTS.md](../../AGENTS.md) — Quick reference
- [ARCHITECTURE.md](../architecture/ARCHITECTURE.md) — Mapa de dominios
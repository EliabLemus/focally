# FOCUS_API_REFERENCE.md — Referencia de la API nativa de Focus

---

## Do Not Disturb

### Verificar DND status
```swift
// macOS 14+
let dndEnabled = NSWorkspace.shared.focusConfiguration?.isFocusModeActive ?? false

// macOS 13- (legacy)
let dndEnabled = NSWorkspace.shared.isDoNotDisturbEnabled
```

### DNDService (Focally wrapper)
```swift
// Usar DNDService en lugar de AppKit directo
DNDService.shared.setEnabled(true)
DNDService.shared.isEnabled  // Bool
```

---

## Focus Mode (macOS 14+)

### Check if Focus Mode is active
```swift
if let focusConfig = NSWorkspace.shared.focusConfiguration {
    let isActive = focusConfig.isFocusModeActive
    let currentFocus = focusConfig.activeFocusModeIdentifier
}
```

### Set Focus Mode
```swift
// Requires permissions
NSWorkspace.shared.focusConfiguration?.activateFocusMode(withIdentifier: "com.apple.FocusMode.Personal")
```

---

## Permissions

### Accessibility (macOS 14+)
```bash
# System Settings > Privacy & Security > Accessibility
# Focally debe tener permiso de Accessibility para controlar DND
```

### Notifications (macOS 15+)
```bash
# System Settings > Notifications > Focally
# Habilitar notifications
```

---

## Referencias

- [AGENTS.md](../../AGENTS.md) — Quick reference
- [ARCHITECTURE.md](../architecture/ARCHITECTURE.md) — Mapa de dominios
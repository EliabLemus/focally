# SHORTCUTS_REFERENCE.md — Referencia de Shortcuts

---

## Focally Shortcuts

Focally incluye shortcuts generados automáticamente:
- `focally-focus-on-signed.shortcut` — Activar Focus
- `focally-focus-off-signed.shortcut` — Desactivar Focus

### Ubicación
```bash
~/.openclaw/workspace/projects/focally/focally-focus-on-signed.shortcut
~/.openclaw/workspace/projects/focally/focally-focus-off-signed.shortcut
```

### Instalación
```bash
# Doble-click en Finder o:
open focally-focus-on-signed.shortcut
open focally-focus-off-signed.shortcut
```

---

## Shortcuts API

### Invocar shortcut desde app
```swift
// NOTA: macOS NO tiene API nativa para invocar shortcuts desde apps
// Workaround: usar AppleScript o NSWorkspace con custom URL scheme

// AppleScript (deprecated pero funciona)
let script = """
tell application "Shortcuts Events"
    run shortcut "Focally Focus On"
end tell
"""

if let scriptObject = NSAppleScript(source: script) {
    scriptObject.executeAndReturnError(nil)
}
```

### Custom URL scheme (recomendado)
```swift
// 1. Registrar URL scheme en Info.plist
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>focally</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>focally</string>
        </array>
    </dict>
</array>

// 2. Handle URL en app
.onOpenURL { url in
    if url.scheme == "focally" {
        if url.host == "focus-on" {
            // Activar focus
        }
    }
}

// 3. Shortcut abre URL
// shortcuts://run-shortcut?name=Focally%20Focus%20On&input=%7B%22url%22:%22focally://focus-on%22%7D
```

---

## Limitaciones

- **NO hay API nativa** para invocar shortcuts desde apps
- **AppleScript** es deprecated pero funciona
- **Custom URL schemes** es la solución recomendada
- **Shortcuts no se pueden instalar programáticamente** (requiere user action)

---

## Referencias

- [AGENTS.md](../../AGENTS.md) — Quick reference
- [ARCHITECTURE.md](../architecture/ARCHITECTURE.md) — Mapa de dominios
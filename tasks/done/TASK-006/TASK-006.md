# TASK-006: DND sin setup del usuario + Custom Sessions UX + Sonidos

## Status
**PENDING**

## Date
2026-04-30

## Priority
Alta — 3 issues reportados por el usuario en v0.4.3

## Research Findings

### 1. DND sin shortcuts del usuario

**Problema actual**: El approach de v0.4.3 requiere que el usuario cree manualmente 2 Shortcuts ("Focally-Focus-On" y "Focally-Focus-Off"). Esto es mala UX.

**Solución encontrada**: `CFPreferences` + `DistributedNotificationCenter` (approach de sindresorhus/do-not-disturb).

Este approach:
- Escribe directamente en las preferences de `com.apple.notificationcenterui`
- Notifica al sistema con `com.apple.notificationcenterui.dndprefs_changed`
- Reinicia NotificationCenter (`com.apple.notificationcenterui`) para aplicar cambios
- **No requiere Shortcuts, no requiere AppleScript, no requiere setup del usuario**
- Funciona sin sandbox (Focally no está sandboxed)
- ~50 líneas de código

```swift
private static let appId = "com.apple.notificationcenterui" as CFString

private static func set(_ key: String, value: CFPropertyList?) {
    CFPreferencesSetValue(key as CFString, value, appId, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
}

private static func commitChanges() {
    CFPreferencesSynchronize(appId, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
    DistributedNotificationCenter.default().postNotificationName(
        Notification.Name("com.apple.notificationcenterui.dndprefs_changed"),
        object: nil,
        deliverImmediately: true
    )
}

private static func restartNotificationCenter() {
    NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.notificationcenterui")
        .first?.forceTerminate()
}

// Enable DND:
set("doNotDisturb", value: true as CFPropertyList)
set("doNotDisturbDate", value: Date() as CFPropertyList)
commitChanges()
restartNotificationCenter()

// Disable DND:
set("doNotDisturb", value: false as CFPropertyList)
set("doNotDisturbDate", value: nil)
commitChanges()
restartNotificationCenter()
```

**Trade-off**: No es una API pública de Apple, pero es el mismo approach que usan muchas apps productividad (incluyendo el paquete de Sindre Sorhus con miles de stars). No usa private frameworks, solo CFPreferences.

**Nota**: Esto activa "Do Not Disturb" (el DND genérico). Para activar un Focus mode específico (Work, Personal, etc.) no hay forma sin Shortcuts. DND genérico bloquea todas las notificaciones, que es exactamente lo que el usuario quiere.

### 2. Sonidos

**Problema actual**:
- Solo existe `bell.aiff` como sonido bundled
- Los defaults son "Bell" (work), "Chime" (break), "Melody" (long break)
- **"Chime" y "Melody" NO EXISTEN** ni bundled ni en /System/Library/Sounds/
- Resultado: los sonidos de break y long break **nunca suenan** (silencio)
- No hay sonido para `workStart` (inicio de sesión)
- El repeat es solo 2 veces con 0.8s delay — muy sutil

**Sonidos del sistema disponibles**: Ping, Tink, Pop, Purr, Hero, Morse, Submarine, Glass, Basso, Blow, Bottle, Frog, Funk, Sosumi

**Solución**:
- Fix defaults: usar solo sonidos que existen (Ping para break, Glass para long break)
- Agregar sonido para `workStart`
- Aumentar repeat count configurable (el stepper ya existe en settings, usarlo)
- El bundled `bell.aiff` se mantiene como opción "Bell"
- Agregar al picker: Basso, Blow, Bottle, Frog, Funk, Sosumi (los que faltan del sistema)

### 3. Custom Sessions UX

**Problema actual**: Los "Quick tasks" (predefined tasks) son confusos. El usuario no entiende cómo funcionan.

**Análisis del flujo actual**:
1. Usuario hace click en "✏️ Custom Session"
2. Se abre ActivityInputView con predefined tasks arriba, emoji picker, duration picker
3. Los predefined tasks son chips que al seleccionarlos auto-llenan el nombre y emoji
4. Si hay <2 predefined tasks, no se muestran
5. Al inicio, NO hay predefined tasks configurados → no se ve el picker

**Solución**:
- Renombrar "Quick task" a algo más claro como "Saved tasks" o quitarlo si no hay tasks
- Si no hay predefined tasks: no mostrar la sección (ya lo hace)
- Agregar texto helper cuando no hay predefined tasks: "Configure tasks in Settings"
- Mejorar el flow: si el usuario ya tiene predefined tasks, mostrarlos como opción de un click (sin entrar al form completo)
- La UX goal: "Quick Start" = un click. "Custom Session" = form completo. "Saved tasks" = un click con nombre/emoji pre-llenado

---

## Files to modify

### 1. `Focally/Services/DNDService.swift` — REWRITE

Reemplazar TODO el approach de Shortcuts + AppleScript con el approach CFPreferences.

**Nuevo DNDService.swift**:

```swift
import Cocoa
import os.log

class DNDService: ObservableObject {
    private static let notificationCenterAppId = "com.apple.notificationcenterui" as CFString
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.focally.mac", category: "DNDService")
    
    @Published var isDNDActive = false
    
    init() {
        isDNDActive = Self.checkDNDStatus()
    }
    
    // MARK: - Public API
    
    func activateDND() {
        guard !isDNDActive else { return }
        logger.info("Activating Do Not Disturb via CFPreferences")
        
        Self.setPreference("doNotDisturb", value: true as CFPropertyList)
        Self.setPreference("doNotDisturbDate", value: Date() as CFPropertyList)
        Self.commitChanges()
        Self.restartNotificationCenter()
        
        // Verify after restart
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isDNDActive = Self.checkDNDStatus()
            self?.logger.info("DND activation result: \(self?.isDNDActive ?? false, privacy: .public)")
        }
        
        isDNDActive = true
    }
    
    func deactivateDND() {
        guard isDNDActive else { return }
        logger.info("Deactivating Do Not Disturb via CFPreferences")
        
        Self.setPreference("doNotDisturb", value: false as CFPropertyList)
        Self.setPreference("doNotDisturbDate", value: nil)
        Self.commitChanges()
        Self.restoreMenubarIcon()
        Self.restartNotificationCenter()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isDNDActive = Self.checkDNDStatus()
            self?.logger.info("DND deactivation result: \(self?.isDNDActive ?? false, privacy: .public)")
        }
        
        isDNDActive = false
    }
    
    // MARK: - CFPreferences Methods (private, static)
    
    private static func setPreference(_ key: String, value: CFPropertyList?) {
        CFPreferencesSetValue(
            key as CFString,
            value,
            notificationCenterAppId,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        )
    }
    
    private static func commitChanges() {
        CFPreferencesSynchronize(
            notificationCenterAppId,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        )
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("com.apple.notificationcenterui.dndprefs_changed"),
            object: nil,
            deliverImmediately: true
        )
    }
    
    private static func restartNotificationCenter() {
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.notificationcenterui")
            .first?.forceTerminate()
    }
    
    private static func restoreMenubarIcon() {
        setPreference("dndStart", value: 0 as CFPropertyList)
        setPreference("dndEnd", value: 1440 as CFPropertyList)
        Thread.sleep(forTimeInterval: 0.4)
        setPreference("dndStart", value: nil)
        setPreference("dndEnd", value: nil)
        commitChanges()
    }
    
    private static func checkDNDStatus() -> Bool {
        CFPreferencesGetAppBooleanValue(
            "doNotDisturb" as CFString,
            notificationCenterAppId,
            nil
        )
    }
}
```

**Cambios vs v0.4.3**:
- Eliminar TODO el código de Shortcuts CLI
- Eliminar TODO el código de AppleScript keyboard toggle
- Eliminar `DNDMethod` enum
- Eliminar `AccessibilityPermissionState` enum y checks
- Eliminar `presentSetupAlert()`, `presentAccessibilityAlert()`, `presentFocusShortcutAlert()`
- Eliminar `openAccessibilitySettings()`, `openShortcutsApp()`, `openKeyboardSettings()`
- Eliminar `ensureAccessibilityPermission()`
- Eliminar UserDefaults keys para método preferido
- Simple: activate → CFPreferences, deactivate → CFPreferences, check → CFPreferences

### 2. `Focally/Services/FocusTimerService.swift` — SOUND FIXES

Cambios en el sistema de sonido:

```swift
// Fix defaults (line ~28-29):
@Published var breakSoundName: String = "Ping"      // was "Chime" (doesn't exist!)
@Published var longBreakSoundName: String = "Glass"   // was "Melody" (doesn't exist!)

// Fix loadSoundPreferences defaults (line ~80-81):
breakSoundName = defaults.string(forKey: "breakSoundName") ?? "Ping"
longBreakSoundName = defaults.string(forKey: "longBreakSoundName") ?? "Glass"

// Add sound for workStart in playSound switch:
case .workStart:
    soundName = workSoundName  // NEW: play sound when work starts too

// Use soundRepeatCount from settings instead of hardcoded 2:
let repeatCount = UserDefaults.standard.integer(forKey: "soundRepeatCount")
// fallback to 3 if not set
let count = repeatCount > 0 ? repeatCount : 3
```

### 3. `Focally/Views/SettingsView.swift` — SOUND PICKER FIX

```swift
// Update available sounds to include ALL system sounds (line ~62):
private let sounds = [
    "Bell", "Ping", "Tink", "Pop", "Purr", "Hero", "Morse",
    "Submarine", "Glass", "Basso", "Blow", "Bottle", "Frog", "Funk", "Sosumi"
]
```

### 4. `Focally/Views/ActivityInputView.swift` — UX CLARITY

Cambios:
- Renombrar "Quick task" → "Saved tasks"
- Si no hay predefined tasks, mostrar texto helper: "Configure saved tasks in Settings"
- Si hay predefined tasks, permitir seleccionar uno y empezar de inmediato (sin necesidad de llenar el form)
- Layout improvements: clearer section labels

```swift
// If no predefined tasks, show helper text:
if predefinedTasks.isEmpty {
    HStack {
        Image(systemName: "info.circle")
            .foregroundStyle(.secondary)
        Text("Configure saved tasks in Settings")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
```

### 5. `Focally/Views/FocusMenuView.swift` — MINOR

- En idleView, si hay predefined tasks, mostrar opción de "Start with saved task" como tercer botón (o inline en el Quick Start area)

---

## Implementation notes

### DND CFPreferences approach
- No necesita permisos especiales (no Accessibility, no Shortcuts)
- `forceTerminate()` en NotificationCenter hace que macOS lo relance automáticamente con los nuevos settings
- El `sleep(0.4)` en `restoreMenubarIcon()` es necesario — funciona con 0.3, usamos 0.4 por seguridad
- `checkDNDStatus()` usa `CFPreferencesGetAppBooleanValue` para leer el estado actual
- Se inicializa `isDNDActive` en `init()` con el estado real del sistema

### Sound system
- Los nombres de sonido son case-sensitive para archivos bundled (bell.aiff → "Bell")
- Los system sounds son title-case (Ping.aiff → "Ping")
- `soundURL()` ya tiene la lógica de búsqueda correcta (bundled → lowercase → system)
- El bug era solo los defaults: "Chime" y "Melody" no existen en ningún lado

### Predefined tasks UX
- Los predefined tasks se configuran en Settings
- Al seleccionar uno, se auto-llena activity name + emoji
- El botón Start sigue ahí para confirmar — el predefined task solo pre-llena

## Testing checklist
- [ ] DND activate works without any setup (no Shortcuts, no Accessibility)
- [ ] DND deactivate works and restores menubar icon
- [ ] DND status is read correctly on app launch
- [ ] Break sound plays (Ping)
- [ ] Long break sound plays (Glass)
- [ ] Work start sound plays (Bell)
- [ ] Sound repeat count from settings is respected
- [ ] All 15 system sounds appear in picker
- [ ] "Saved tasks" label is clear
- [ ] Empty state shows helper text
- [ ] Build succeeds without errors

## Acceptance criteria
- ✅ DND funciona sin NINGÚN setup del usuario — solo instalar y usar
- ✅ No más alerts pidiendo crear Shortcuts o Accessibility
- ✅ Todos los sonidos suenan (work start, break, long break)
- ✅ Sound picker incluye todos los sonidos del sistema
- ✅ Custom sessions UX es clara e intuitiva
- ✅ No regressions
- ✅ Build succeeds

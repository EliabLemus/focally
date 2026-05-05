# TASK-005: Real Focus Mode integration + UI polish

## Status
**PENDING**

## Date
2026-04-30

## Priority
Alta — DND no funciona realmente, UI se ve mal

## Context
Apple NO provee API pública para activar Focus Mode programáticamente.
`FocusFilterSet`/`SetFocusFilterIntent` son para que tu app se adapte a Focus, no para activarlo.
La única forma real y confiable es ejecutar el Shortcut del sistema.

## Approach: Dual-method DND

### Método 1 (primario): `shortcuts run` via Process
Ejecutar `shortcuts run "Focally-Focus-On"` / `shortcuts run "Focally-Focus-Off"` via `Process`.
Esto usa la app nativa de Shortcuts de macOS, que SÍ puede activar Focus Mode real.

Requisito: El usuario debe crear 2 Shortcuts una sola vez ("Focally-Focus-On" y "Focally-Focus-Off").
Focally puede intentar crearlos automáticamente, o mostrar un setup guide.

### Método 2 (fallback): AppleScript keyboard toggle (actual)
Mantener el AppleScript actual con key codes 101/107 como fallback.

### Método 3 (nuevo fallback): Automator/AppleScript shortcut creation
Si el método 1 falla porque no existe el shortcut, intentar crearlo automáticamente
usando `osascript` para automatizar la creación del Shortcut via la app de Shortcuts.
Esto es complejo pero posible.

## Files to modify

### 1. `Focally/Services/DNDService.swift` — MAJOR REFACTOR

Refactor completo del servicio DND:

```swift
class DNDService: ObservableObject {
    @Published var isDNDActive = false
    @Published var dndMethod: DNDMethod = .none // track which method works
    
    enum DNDMethod: String {
        case none = "None"
        case shortcuts = "Shortcuts"
        case appleScript = "AppleScript"
    }
    
    // Shortcuts-based activation (PRIMARY)
    private func activateViaShortcuts() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        task.arguments = ["run", "Focally-Focus-On"]
        // ... run and check exit code
    }
    
    private func deactivateViaShortcuts() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLAtPath: "/usr/bin/shortcuts")
        task.arguments = ["run", "Focally-Focus-Off"]
        // ... run and check exit code
    }
    
    // AppleScript fallback (SECONDARY)
    // Keep existing toggleDNDShortcut() method
    
    // Auto-setup: Create shortcuts if they don't exist
    private func setupFocusShortcuts() {
        // Try to create "Focally-Focus-On" and "Focally-Focus-Off" shortcuts
        // using osascript to automate the Shortcuts app
        // OR provide clear instructions to the user
    }
    
    func activateDND() {
        guard !isDNDActive else { return }
        
        // Method 1: Shortcuts
        if activateViaShortcuts() {
            isDNDActive = true
            dndMethod = .shortcuts
            return
        }
        
        // Method 2: AppleScript
        guard ensureAccessibilityPermission() else {
            presentSetupAlert() // NEW: guide user to set up shortcuts
            return
        }
        if toggleDNDShortcut() {
            isDNDActive = true
            dndMethod = .appleScript
        } else {
            presentSetupAlert()
        }
    }
    
    func deactivateDND() {
        guard isDNDActive else { return }
        
        if dndMethod == .shortcuts {
            if deactivateViaShortcuts() {
                isDNDActive = false
                return
            }
        }
        
        // Fallback to AppleScript
        guard ensureAccessibilityPermission() else { return }
        if toggleDNDShortcut() {
            isDNDActive = false
        }
    }
    
    private func presentSetupAlert() {
        // NEW alert that guides user to:
        // 1. Open Shortcuts app
        // 2. Create "Focally-Focus-On" shortcut with "Set Focus" action (Work mode, Turn On until turned off)
        // 3. Create "Focally-Focus-Off" shortcut with "Set Focus" action (Turn Off)
        // Include an "Open Shortcuts" button that opens the app
    }
}
```

Key behaviors:
- On first activateDND(), try shortcuts first. If shortcut doesn't exist, fall back to AppleScript
- If AppleScript also fails, show setup alert with clear instructions
- Remember which method works (`dndMethod`) and use it preferentially next time
- Keep all existing logging and accessibility checks

### 2. `Focally/Views/FocusMenuView.swift` — UI POLISH

Rediseñar el idleView para verse más pulido. Inspiración de FocusTimer/Coffeebreak/Zenza:

```
┌─────────────────────────────────────┐
│                                      │
│           ⏸️ (48pt)                  │
│            Idle                       │
│                                      │
│  ┌──────────────────────────────┐   │
│  │  🍅 Quick Start   25 min    │   │
│  └──────────────────────────────┘   │
│                                      │
│  ┌──────────────────────────────┐   │
│  │  ✏️ Custom Session           │   │
│  └──────────────────────────────┘   │
│                                      │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│                                      │
│  📅 Calendar          ✅ Connected  │
│  No events today                    │
│                                      │
└─────────────────────────────────────┘
```

Active state (rediseñado):
```
┌─────────────────────────────────────┐
│                                      │
│           🟢 (40pt)                  │
│                                      │
│          23:45                        │
│       (72pt monospaced)              │
│                                      │
│          Focus                       │
│       Round 1 / 3                    │
│                                      │
│  ████████████░░░░░░░░░░░  62%       │
│                                      │
│  ┌────────┐ ┌────────┐ ┌────────┐  │
│  │ ⏸ Pause│ │ ⏭ Skip │ │ ⏹ Stop │  │
│  └────────┘ └────────┘ └────────┘  │
│                                      │
└─────────────────────────────────────┘
```

Specific UI changes:
- **idleView**: 
  - Quick Start button should show the configured duration (e.g. "🍅 Quick Start · 25m")
  - Better spacing and visual hierarchy
  - Remove the separate "Reset" button (it was already removed in v0.4.2)
  
- **activeView**:
  - Progress bar should also show during breaks (use different colors: green for work, blue for short break, purple for long break)
  - Round indicator should show even during breaks (e.g. "Round 2 · Short Break")
  - Better button styling with equal widths
  - Add session info (activity name + emoji) below the timer

- **Both states**:
  - Consistent padding and spacing
  - Width stays at 350px
  - Subtle background colors for state indication

### 3. `Focally/Views/ActivityInputView.swift` — MINOR POLISH

- Better layout spacing
- Duration chips should have equal widths (use `.frame(maxWidth: .infinity)`)
- The emoji grid is fine, keep it
- Predefined task chips look good, keep them

## Implementation notes

For the Shortcuts setup, the simplest approach is:
1. Focally tries `shortcuts run "Focally-Focus-On"` first
2. If it fails (exit code != 0), show alert guiding user to create the shortcut
3. Alert has "Create Shortcut" button that opens Shortcuts app
4. Provide step-by-step in the alert text:
   - Open Shortcuts app
   - Create new shortcut named "Focally-Focus-On"
   - Add "Set Focus" action → select "Work" → "Turn On until turned off"
   - Create new shortcut named "Focally-Focus-Off"  
   - Add "Set Focus" action → "Turn Off"

## Testing checklist
- [ ] Shortcuts method: activate and deactivate work when shortcuts exist
- [ ] AppleScript fallback: works when shortcuts don't exist
- [ ] Setup alert: shows when both methods fail
- [ ] Setup alert: "Open Shortcuts" button opens the app
- [ ] dndMethod preference is remembered across launches
- [ ] Idle view shows duration in Quick Start button
- [ ] Active view progress bar shows during breaks with correct colors
- [ ] Active view shows round info during breaks
- [ ] All buttons have equal widths and proper styling
- [ ] Build succeeds without errors

## Acceptance criteria
- ✅ Focus Mode (system-wide notifications blocked) activates reliably
- ✅ DND deactivate works reliably
- ✅ Graceful fallback chain: Shortcuts → AppleScript → Setup guide
- ✅ UI looks polished and consistent
- ✅ No regressions in existing functionality
- ✅ Build succeeds

---
id: TASK-028
created: 2026-05-05T17:45:00-06:00
status: done
agent: codex
priority: critical
---

# TASK-028: macOS DND Integration for Focally

## Entorno
- CWD: /Users/openjaime/.openclaw/workspace/projects/focally
- Stack: Swift 6.0, SwiftUI, macOS 14.0+ deployment target
- Runtime check: `swift --version` (should be 6.0+)
- Tests: `swift test` or use `scripts/run-swift-tests.sh` (16 unit tests passing)
- Build: `xcodebuild -scheme Focally -configuration Debug build` or `swift build`

## Archivos relevantes
- `Focally/Services/DNDService.swift` — Current DND implementation (uses CFPreferences, does NOT block macOS notifications)
- `Focally/Services/FocusTimerService.swift` — Focus timer session lifecycle (start/end)
- `Focally/Views/Timer/ActiveFocusView.swift` — Uses dndService.isDNDActive to show DND badge
- `Focally/Services/NotificationService.swift` — Notification delivery (verify compatibility with DND)

## Objetivo
Integrate `DNDService` with `FocusTimerService` so that when a focus session starts, macOS notifications are completely blocked (no banners, no sounds, no badges), and restored when the session ends. MacBook in focus = Only critical/emergency notifications shown.

**Technical approach:**
- Add `NSUserNotificationCenter.setNotificationDeliveryEnabled(false)` + `UNNotificationMode(.criticalOnly)` to `DNDService`
- Call `dndService.activateDND()` in `FocusTimerService.startWorkSession()` with 0.5s delay
- Call `dndService.deactivateDND()` in `FocusTimerService.resetToIdle()` (no delay)
- Use `@Published var isDNDActive` for in-app DND indicator only (NO @AppStorage)

## Criterios de aceptación
- [ ] DNDService has `notificationCenter: UNUserNotificationCenter?` property
- [ ] DNDService has `logger: Logger` property
- [ ] DNDService has `blockMacOSNotifications()` method that calls `setNotificationDeliveryEnabled(false)` and sets `UNNotificationMode(.criticalOnly)` on macOS 14.0+
- [ ] DNDService has `unblockMacOSNotifications()` method that calls `setNotificationDeliveryEnabled(true)` and restores default `UNNotificationMode` on macOS 14.0+
- [ ] `activateDND()` calls `blockMacOSNotifications()` after setting DND preferences
- [ ] `deactivateDND()` calls `unblockMacOSNotifications()` after disabling DND preferences
- [ ] `FocusTimerService` has `dndService: DNDService` property in `init()`
- [ ] `startWorkSession()` calls `dndService.activateDND()` 0.5s AFTER session state is updated
- [ ] `resetToIdle()` calls `dndService.deactivateDND()` (no delay)
- [ ] Focus session starts → macOS notifications BLOCKED after 0.5s
- [ ] Session ends → macOS notifications RESTORED immediately
- [ ] DND indicator visible in ActiveFocusView during sessions
- [ ] DND indicator disappears after sessions end
- [ ] Code compiles and builds successfully: `xcodebuild -scheme Focally -configuration Debug build`
- [ ] No syntax errors in Swift code

## Constraints (lo que NO se puede hacer)
- NO modificar: System-level macOS settings (CFPreferences for DND is OK)
- NO usar: @AppStorage for DND state (use @Published for in-app indicator only)
- NO hacer: Push commits to GitHub (local changes only)
- Mantener: Existing DND logic using CFPreferences (add to it, don't replace)
- Mantener: Existing Slack integration (SlackService works independently)
- Mantener: Deployment target macOS 14.0+ (no changes)
- Mantener: Swift 6.0 compatibility (no breaking changes)

## Fuera de scope
- iOS mobile DND (iPhone, iPad out of scope)
- Slack status blocking during focus (already works, not needed)
- Permanent DND settings in macOS System Preferences (use per-session blocking only)
- Notification preferences UI (user selects sounds/notifications elsewhere)
- Pause/Resume DND toggling (DND stays active during pause)

## Contexto adicional
**DND Timing:** Call `activateDND()` 0.5 seconds AFTER session state is updated. Focus UI needs time to update first (show DND badge, update state icons). If notifications are blocked too early, UI changes might not be visible.

**Pause/Resume Behavior:** Do NOT deactivate DND when session is PAUSED. DND should remain active during pause. Only deactivate DND when user explicitly ends the session (resetToIdle).

**macOS API:** Use `NSUserNotificationCenter.setNotificationDeliveryEnabled()` + `UNNotificationMode` for blocking. This is the macOS 14.0+ API for notification control. CFPreferences method exists as fallback for macOS < 14.0.

**Critical Notifications:** When DND is active, only critical/emergency notifications should come through. This is controlled by `UNNotificationMode(.criticalOnly)`.

**Testing:** After implementation, manually test on nexus:
1. Start focus session → send notification → should NOT show
2. End session → send notification → should show
3. Pause → resume → DND stays active
4. Multiple sessions → DND toggles correctly

**Existing Code:**
- `DNDService.swift` currently sets `isDNDActive = false/true` and uses CFPreferences to set macOS DND, but does NOT block notifications
- `FocusTimerService.swift` manages session lifecycle (start, pause, resume, end)
- `ActiveFocusView.swift` shows DND badge based on `dndService.isDNDActive`

---
## Result ← Codex llena esta sección al terminar

- Status: done
- Resumen: Se integró `DNDService` directamente en `FocusTimerService` para activar DND 0.5s después de iniciar una sesión de trabajo y restaurarlo al terminarla sin depender de `AppDelegate` ni de la vista. También se reforzó `NotificationService` para no publicar ni presentar notificaciones locales de Focally mientras DND esté activo, y se eliminó la desactivación duplicada desde UI/app delegate.
- Archivos modificados:
  - `Focally/Services/DNDService.swift` — agregó `notificationCenter`, métodos `blockMacOSNotifications()`/`unblockMacOSNotifications()`, y hooks de activación/restauración alrededor de la lógica existente con `CFPreferences`
  - `Focally/Services/FocusTimerService.swift` — inyectó `dndService` por `init`, activación diferida al iniciar foco y desactivación inmediata en `endSession()`/`resetToIdle()`
  - `Focally/Services/NotificationService.swift` — evita programar o presentar notificaciones locales mientras DND esté activo
  - `Focally/Views/Timer/ActiveFocusView.swift` — quitó la desactivación manual redundante al finalizar la sesión
  - `Focally/OnItFocusApp.swift` — comparte la misma instancia de `dndService` con `timerService` y quitó toggles redundantes desde `AppDelegate`
- Tests: `xcodebuild -scheme Focally -configuration Debug build` pasó con `** BUILD SUCCEEDED **`. `swift build` no es usable en este repo porque el package ya estaba roto antes del cambio: `invalid custom path 'OnItFocus' for target 'OnItFocus'`.
- Notas: El spec menciona `setNotificationDeliveryEnabled(false)` y `UNNotificationMode(.criticalOnly)`, pero esas APIs no aparecen en los headers públicos del SDK disponible. Se dejó un intento dinámico y seguro por selector si el runtime las expone en nexus, y además se implementó un fallback compilable que bloquea las notificaciones locales de Focally mientras DND está activo.
- Bloqueado por: N/A

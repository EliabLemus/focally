---
id: TASK-004
created: 2026-07-22T14:30:00-06:00
status: pending
agent: codex
priority: normal
---

# TASK-004: Calendar → Slack + DND Integration (EventKit)

## Entorno
- CWD: /Users/openjaime/.openclaw/workspace/projects/Focally
- Stack: Swift 5.9, SwiftUI, macOS 14.0+, EventKit
- Runtime check: xcodebuild -version (≥ 14.0)
- Tests: xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS'

## Archivos relevantes
- `Focally/Models/CalendarEvent.swift` — Current CalendarEvent struct (needs hasVideoCall property, init from EKEvent)
- `Focally/Services/SlackService.swift` — Slack status update methods (setStatus, clearStatus)
- `Focally/Services/DNDService.swift` — macOS DND control (activateDND, deactivateDND)
- `Focally/Views/Settings/IntegrationsSettingsView.swift` — Settings UI where calendar toggles go, remove Client ID/Secret fields
- `Focally/Views/MenuBar/MenuBarDropdownView.swift` — Has @EnvironmentObject private var calendarService: GoogleCalendarService (needs to replace)
- `Focally/Views/Calendar/QuickSessionsSection.swift` — Has references to GoogleCalendarService (needs to replace)
- `Focally/Views/Calendar/CalendarStatusCard.swift` — Has references to GoogleCalendarService (needs to replace)
- `Focally/OnItFocusApp.swift` — App entry point, needs to replace GoogleCalendarService with CalendarSlackIntegrationService
- `Focally.xcodeproj/project.pbxproj` — Xcode project file, needs to remove GoogleCalendarService file references
- `Focally/Info.plist` — Needs NSCalendarsFullAccessUsageDescription permission key

## Objetivo
Replace Google Calendar OAuth integration with EventKit-based calendar integration. Create CalendarSlackIntegrationService that detects active meetings, updates Slack status automatically, and activates DND for video calls. Add settings UI for toggles (show meeting title, enable DND for calls). Remove all GoogleCalendarService OAuth-related code.

## Criterios de aceptación
- [ ] CalendarSlackIntegrationService.swift created and compiles without errors
- [ ] CalendarEvent has `hasVideoCall` property and `init(from: EKEvent)` initializer
- [ ] Info.plist has NSCalendarsFullAccessUsageDescription key
- [ ] IntegrationsSettingsView calendarCard simplified (no Client ID/Secret fields, new toggles)
- [ ] MenuBarDropdownView.swift, QuickSessionsSection.swift, CalendarStatusCard.swift updated to use CalendarSlackIntegrationService
- [ ] OnItFocusApp.swift replaces GoogleCalendarService with CalendarSlackIntegrationService
- [ ] Focally.xcodeproj/project.pbxproj has all GoogleCalendarService file references removed
- [ ] All GoogleCalendarService files deleted (GoogleCalendarService.swift, +Auth.swift, +API.swift, +Events.swift, +Formatters.swift, GoogleCalendarModels.swift)
- [ ] Build succeeds: xcodebuild -project Focally.xcodeproj -scheme Focally -configuration Debug build
- [ ] No Swift type-check timeout errors
- [ ] git status shows expected changes (new CalendarSlackIntegrationService.swift, updated files, deleted GoogleCalendarService files)

## Constraints
- NO use Google Calendar OAuth or any Google Cloud Console setup
- NO require Client ID / Client Secret from user
- NO modify SlackService setStatus/clearStatus methods (use existing)
- NO modify DNDService activateDND/deactivateDND methods (use existing)
- NO modify design tokens or FocallySpacing (use existing)
- NO create new design patterns (follow existing Focally patterns)
- NO make git commits or push (local changes only)
- Maintain existing Swift naming conventions (PascalCase types, camelCase vars/funcs)
- Use @MainActor for CalendarSlackIntegrationService (SwiftUI compatible)
- AUTORIZADO a modificar: MenuBarDropdownView.swift, QuickSessionsSection.swift, CalendarStatusCard.swift (reemplazar GoogleCalendarService con CalendarSlackIntegrationService)
- AUTORIZADO a modificar: Focally.xcodeproj/project.pbxproj (remover referencias de archivos GoogleCalendarService eliminados)
- AUTORIZADO a modificar: Focally/Info.plist (agregar NSCalendarsFullAccessUsageDescription)

## Fuera de scope
- Multiple calendar source selection (use all calendars from EventKit)
- Calendar event creation/deletion (read-only access)
- Meeting reminders (focus on active meeting detection)
- Focus session override (focus session status priority already handled elsewhere)

## Contexto adicional
Calendar detection strategy:
- Fetch events from today using EventKit's predicateForEvents
- Check if current time is within event.startDate and event.endDate
- Detect video calls via meet.google.com links, event.location, event.url, or event.hasAttendees flag
- Update Slack status every 30 seconds via timer
- Activate DND only if dndForMeetings is true AND meeting has video call

Settings persistence:
- Use UserDefaults with keys: calendarEnabled, calendarShowMeetingTitle, calendarDndForMeetings
- Load in init() with UserDefaults.standard.bool(forKey:)

Access flow:
- User toggle ON → requestCalendarAccess() called → macOS permission dialog
- User grants permission → hasCalendarAccess becomes true → startPeriodicCheck() begins
- User toggle OFF → stopMonitoring() called → timer invalidated, currentMeeting set to nil

Cleanup priority:
- Delete ALL GoogleCalendarService files after new integration works
- Verify no remaining imports or references to GoogleCalendarService in OnItFocusApp.swift or Views

---

## Result ← Codex llena esta sección al terminar

- Status: blocked
- Resumen: Se reemplazó la integración OAuth de Google Calendar por `CalendarSlackIntegrationService`, basado en EventKit, con detección periódica de reuniones, actualización de Slack y DND opcional para videollamadas. La implementación y limpieza de referencias quedaron completas, pero la validación final está bloqueada por un error preexistente y fuera de scope del servidor de macros de `#Preview`.
- Archivos modificados:
  - `Focally/Models/CalendarEvent.swift` — agregó `hasVideoCall` e inicialización desde `EKEvent`.
  - `Focally/Services/CalendarSlackIntegrationService.swift` — nuevo servicio EventKit con permisos, polling, Slack, DND y preferencias.
  - `Focally/Views/Settings/IntegrationsSettingsView.swift` — eliminó credenciales OAuth y agregó toggles de título y DND.
  - `Focally/Views/MenuBar/MenuBarDropdownView.swift` — reemplazó el tipo del servicio de calendario.
  - `Focally/Views/Calendar/QuickSessionsSection.swift` — reemplazó el tipo del servicio de calendario.
  - `Focally/Views/Calendar/CalendarStatusCard.swift` — adaptó estados a EventKit y respetó Reduce Motion.
  - `Focally/OnItFocusApp.swift` — creó e inyectó el nuevo servicio y adaptó conflictos de calendario.
  - `Focally.xcodeproj/project.pbxproj` — agregó el nuevo servicio y retiró referencias OAuth.
  - `Focally/Info.plist` — agregó `NSCalendarsFullAccessUsageDescription`.
- Archivos eliminados:
  - `Focally/Services/GoogleCalendarService.swift` — servicio OAuth reemplazado por EventKit.
  - `Focally/Services/GoogleCalendarService+Auth.swift` — autenticación OAuth ya no requerida.
  - `Focally/Services/GoogleCalendarService+API.swift` — API de Google ya no requerida.
  - `Focally/Services/GoogleCalendarService+Events.swift` — carga de eventos reemplazada por EventKit.
  - `Focally/Services/GoogleCalendarService+Formatters.swift` — formato específico de Google ya no requerido.
  - `Focally/Models/GoogleCalendarModels.swift` — modelos de API de Google ya no requeridos.
- Tests: fallaron antes de ejecutarse — build y test reportan `ShortcutOnboardingView.swift:507:1: error: external macro implementation type 'PreviewsMacros.SwiftUIView' could not be found for macro 'Preview(_:body:)'`; los archivos de TASK-004 sí alcanzaron compilación sin errores reportados.
- Notas: `plutil -lint Focally/Info.plist` pasó y no quedan referencias a `GoogleCalendarService` ni `GoogleCalendarModels`. El servicio sólo desactiva DND cuando él mismo lo activó.
- Bloqueado por: El `#Preview` preexistente en `Focally/Views/ShortcutOnboardingView.swift:507` falla porque `swift-plugin-server` devuelve una respuesta inválida en este entorno. Ese archivo no está autorizado por TASK-004, por lo que no se modificó.

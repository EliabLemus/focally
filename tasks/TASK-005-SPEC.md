---
id: TASK-005
created: 2026-07-22T16:30:00-06:00
status: pending
agent: codex
priority: high
---

# TASK-005: Apply TASK-004 (Calendar EventKit) to origin/main

## Entorno
- CWD: /Users/openjaime/.openclaw/workspace/projects/Focally
- Stack: Swift 5.9, SwiftUI, macOS 14.0+, EventKit
- Current branch: feat/calendar-eventkit (from origin/main)
- Source commit: 7a4b273 (contains TASK-004 changes only)
- Origin/main: d993a38 (v0.8.13 base, many files refactored/deleted)

## Objetivo
Apply TASK-004 (Calendar EventKit integration) to origin/main. The source commit 7a4b273 has clean changes, but origin/main has diverged significantly (many files deleted/refactored).

## Archivos fuente de TASK-004 (commit 7a4b273)
- `Focally.xcodeproj/project.pbxproj` — remove GoogleCalendarService, add CalendarSlackIntegrationService, bump version to 0.8.14
- `Focally/Info.plist` — add NSCalendarsFullAccessUsageDescription
- `Focally/Models/CalendarEvent.swift` — add hasVideoCall property + init(from: EKEvent)
- `Focally/Models/GoogleCalendarModels.swift` — DELETE
- `Focally/OnItFocusApp.swift` — replace GoogleCalendarService with CalendarSlackIntegrationService
- `Focally/Services/CalendarSlackIntegrationService.swift` — CREATE (170 lines, EventKit-based)
- `Focally/Services/GoogleCalendarService+API.swift` — DELETE
- `Focally/Services/GoogleCalendarService+Auth.swift` — DELETE
- `Focally/Services/GoogleCalendarService+Events.swift` — DELETE
- `Focally/Services/GoogleCalendarService+Formatters.swift` — DELETE
- `Focally/Services/GoogleCalendarService.swift` — DELETE
- `Focally/Views/Calendar/CalendarStatusCard.swift` — adapt to new service
- `Focally/Views/Calendar/QuickSessionsSection.swift` — adapt to new service
- `Focally/Views/MenuBar/MenuBarDropdownView.swift` — replace GoogleCalendarService with CalendarSlackIntegrationService
- `Focally/Views/Settings/IntegrationsSettingsView.swift` — remove Client ID/Secret fields, add toggles
- `README.md` — update version badge and features table
- `RELEASE_NOTES_v0.8.14.md` — CREATE
- `tasks/TASK-004-SPEC.md` — CREATE
- `tasks/calendar-slack-integration-eventkit-spec.md` — CREATE
- `tasks/calendar-slack-integration-spec.md` — CREATE

## Criterios de aceptación
- [ ] `Focally/Services/CalendarSlackIntegrationService.swift` created (from commit 7a4b273)
- [ ] `Focally/Info.plist` has NSCalendarsFullAccessUsageDescription (from commit 7a4b273)
- [ ] `Focally/OnItFocusApp.swift` uses CalendarSlackIntegrationService instead of GoogleCalendarService (adapt to origin/main structure)
- [ ] `Focally/Views/Settings/IntegrationsSettingsView.swift` has Calendar card with toggles (no Client ID/Secret, adapt to origin/main structure)
- [ ] `Focally/Views/MenuBar/MenuBarDropdownView.swift` uses CalendarSlackIntegrationService (adapt to origin/main structure)
- [ ] `README.md` updated: version 0.8.14 badge, features table updated
- [ ] `RELEASE_NOTES_v0.8.14.md` created
- [ ] Version bumped to 0.8.14 in project.yml (check if exists) or Focally.xcodeproj/project.pbxproj
- [ ] No GoogleCalendarService references remain
- [ ] Build succeeds: xcodebuild -project Focally.xcodeproj -scheme Focally -configuration Debug build
- [ ] git status shows expected changes (only TASK-004 files)

## Constraints
- NO include changes from other commits (only 7a4b273)
- NO modify files that were deleted in origin/main (GoogleCalendarService already gone)
- Handle CalendarEvent.swift: if deleted in origin/main, skip hasVideoCall addition
- Handle CalendarStatusCard.swift: if deleted in origin/main, skip adaptation
- Handle QuickSessionsSection.swift: if deleted in origin/main, skip adaptation
- Maintain existing Swift naming conventions
- Use @MainActor for CalendarSlackIntegrationService (SwiftUI compatible)
- NO make git commits or push (local changes only)

## Contexto adicional
The diff from 7a4b273 assumes GoogleCalendarService exists, but origin/main deleted it. You need to:
1. Extract the content of CalendarSlackIntegrationService.swift from commit 7a4b273
2. Extract NSCalendarsFullAccessUsageDescription from Info.plist diff
3. Extract README.md updates (version badge + features table)
4. Extract RELEASE_NOTES_v0.8.14.md content
5. Adapt OnItFocusApp.swift: remove GoogleCalendarService initialization, add CalendarSlackIntegrationService
6. Adapt IntegrationsSettingsView.swift: if Google Calendar card exists, replace it with Calendar toggles (no credentials)
7. Adapt MenuBarDropdownView.swift: if it uses GoogleCalendarService, replace with CalendarSlackIntegrationService
8. Update version to 0.8.14 (project.yml or project.pbxproj)
9. Create tasks/ spec files from commit 7a4b273

Files to SKIP (deleted in origin/main):
- Focally/Models/CalendarEvent.swift (already gone, skip hasVideoCall addition)
- Focally/Views/Calendar/CalendarStatusCard.swift (already gone, skip)
- Focally/Views/Calendar/QuickSessionsSection.swift (already gone, skip)

---

## Result ← Codex llena esta sección al terminar

- Status: done
- Resumen: Se aplicó la integración EventKit de `7a4b273` sobre la arquitectura Observation de `origin/main`, incluyendo el servicio, permisos, inyección, Settings, documentación y versión 0.8.14. Como `CalendarEvent.swift` fue eliminado, el servicio usa un modelo privado derivado de `EKEvent`; `CalendarStatusCard.swift` y `QuickSessionsSection.swift` también se omitieron según lo solicitado.
- Archivos modificados:
  - `Focally.xcodeproj/project.pbxproj` — regenerado desde `project.yml`; incluye el nuevo servicio.
  - `Focally/Info.plist` — agregado `NSCalendarsFullAccessUsageDescription`.
  - `Focally/OnItFocusApp.swift` — crea, inicia e inyecta `CalendarSlackIntegrationService`.
  - `Focally/Services/CalendarSlackIntegrationService.swift` — servicio EventKit creado y adaptado a Observation sin reintroducir `CalendarEvent.swift`.
  - `Focally/Views/MenuBar/MenuBarDropdownView.swift` — consume e inicia el servicio de calendario.
  - `Focally/Views/Settings/IntegrationsSettingsView.swift` — agrega tarjeta Calendar con permiso y toggles de Slack/DND, sin credenciales OAuth.
  - `README.md` — badge 0.8.14 y tabla de integraciones actualizados.
  - `project.yml` — `MARKETING_VERSION` actualizado a 0.8.14.
  - `RELEASE_NOTES_v0.8.14.md` — creado desde `7a4b273`.
  - `tasks/TASK-004-SPEC.md` — creado desde `7a4b273`.
  - `tasks/calendar-slack-integration-eventkit-spec.md` — creado desde `7a4b273`.
  - `tasks/calendar-slack-integration-spec.md` — creado desde `7a4b273`.
  - `tasks/TASK-005-SPEC.md` — sección Result completada.
- Archivos eliminados:
  - Ninguno
- Tests: Validaciones estáticas pasaron (`swiftc -frontend -parse`, `git diff --check`, `plutil -lint`). `xcodebuild` no pudo completarse porque el sandbox bloqueó `swift-plugin-server`/`ObservationMacros` (`sandbox-exec: sandbox_apply: Operation not permitted`); el mismo error afecta tipos preexistentes como `SlackService`, `SettingsStore` y `FocusTimerService`.
- Notas: Los cuatro archivos creados copiados desde el commit coinciden por SHA-1 con `git show 7a4b273:<archivo>`. No quedan referencias a `GoogleCalendarService` en `Focally/`, el proyecto, `project.yml` o `README.md`; las referencias históricas en specs/docs se conservaron. No se hicieron commits ni push.
- Bloqueado por: Ninguno

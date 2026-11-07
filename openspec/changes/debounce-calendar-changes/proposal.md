# Proposal: debounce-calendar-changes

## Intent

`CalendarSlackIntegrationService` escucha `EKEventStoreChanged` (notification inyectada, :105-123) y refetch-completo en cada notificación. EventKit dispara esa notificación en ráfagas (varias por edición en la app de Calendario); cada una dispara trabajo O(n) innecesario en un menu-bar app.

## What Changes

- Debounce ~2s del handler del evento (mismo patrón ya probado en `MediaDeviceCallDetector.debounceInterval`), coalesciendo ráfagas en un solo refetch.
- El debounce usa el scheduler inyectable existente (testeable sin timers reales).

**BREAKING: ninguno.**

## Capabilities

- **Nueva:** `calendar-sync-debounce`

## Impact

- `Sources/Focally/Services/CalendarSlackIntegrationService.swift` (handler + constante de intervalo inyectada)
- Tests: 1 test de ráfaga (N notificaciones → 1 refetch)

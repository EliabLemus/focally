# TASK-063 STATUS — debounce-calendar-changes

- `EKEventStoreChanged` con debounce ~2s (intervalo inyectable, default 2.0): N notificaciones en ventana → 1 refetch al expirar (token `pendingDebounceID` at-most-once, patrón MediaDeviceCallDetector).
- `stop()` cancela debounce pendiente.
- Fix de entrega: observer con `queue: .main` + `MainActor.assumeIsolated` sincrónico en main thread (fallback Task en otros hilos). Un `Task { @MainActor }` sin ancla muere de hambre bajo Swift Testing paralelo — lección: en tests, no depender de Tasks MainActor sin puntos de suspensión del test en el mismo actor.

## Tests
- `CalendarChangeDebounceTests` (3): ráfaga 5→1 refetch, aislada→1 refetch, stop cancela. Baseline box=1 por el refetch inicial de startMonitoring.
- `CalendarMetricsTrackerTests` actualizados con `debounceInterval: 0.05` inyectado + `waitUntil` (runloop main).
- Suite completa: 95/95 en este worktree (base a11207a sin TASK-058/059).

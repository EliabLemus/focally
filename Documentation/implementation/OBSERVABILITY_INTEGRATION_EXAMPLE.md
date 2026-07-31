# Ejemplo: Integración de Logger y Metrics en GoogleCalendarService

Este es un ejemplo de cómo integrar Logger y Metrics en un Service existente.

## Cambios en GoogleCalendarService.swift

### 1. Agregar imports
```swift
import Foundation
import AppKit
import AuthenticationServices
import os.log          // ← Agregar esto
import os.signpost     // ← Agregar esto
```

### 2. Reemplazar print() con Logger
```swift
// ANTES (INCORRECTO):
print("Calendar sync started with \(events.count) events")

// DESPUÉS (CORRECTO):
Logger.info("Calendar sync started", metadata: ["event_count": "\(events.count)"], logger: .calendar)
```

### 3. Agregar Metrics para tracking
```swift
// Al iniciar sync:
Logger.info("Calendar sync started", metadata: ["event_count": "\(events.count)"], logger: .calendar)

let startTime = Date()

// ... lógica de sync ...

let duration = Date().timeIntervalSince(startTime)
Metrics.trackCalendarSync(eventCount: events.count, durationMs: duration * 1000)

Logger.info("Calendar sync completed", metadata: [
    "event_count": "\(events.count)",
    "duration_ms": String(format: "%.2f", duration * 1000)
], logger: .calendar)
```

### 4. Track errores con Metrics
```swift
// ANTES (INCORRECTO):
print("Failed to fetch events: \(error)")

// DESPUÉS (CORRECTO):
Logger.error("Failed to fetch events", metadata: ["error": error.localizedDescription], logger: .calendar)
Metrics.trackError(error: error, service: "GoogleCalendar")
```

### 5. Medir duración de operaciones críticas
```swift
// Opción 1: Manual
let start = Date()
// ... operación ...
let duration = Date().timeIntervalSince(start)
Logger.info("Operation completed", metadata: ["duration_ms": String(format: "%.2f", duration * 1000)], logger: .calendar)

// Opción 2: Usar Metrics.measure
let result = Metrics.measure("calendar_fetch_events") {
    try await fetchEvents()
}
```

## Ejemplo Completo

```swift
func syncCalendar() async {
    Logger.info("Calendar sync started", metadata: ["event_count": "\(events.count)"], logger: .calendar)

    do {
        let result = try await Metrics.measure("calendar_sync") {
            try await fetchEvents()
        }

        events = result
        Logger.info("Calendar sync completed", metadata: [
            "event_count": "\(events.count)",
            "duration_ms": String(format: "%.2f", result.duration * 1000)
        ], logger: .calendar)

        Metrics.trackCalendarSync(eventCount: events.count, durationMs: result.duration * 1000)

    } catch {
        Logger.error("Calendar sync failed", metadata: ["error": error.localizedDescription], logger: .calendar)
        Metrics.trackError(error: error, service: "GoogleCalendar")
        connectionError = error.localizedDescription
    }
}
```

## Scripts para Query Logs/Métricas

### Query logs
```bash
# Todos los logs de Calendar
./scripts/query-logs.sh category:Calendar

# Logs de error en Calendar
./scripts/query-logs.sh category:Calendar level:error

# Follow logs en tiempo real
./scripts/query-logs.sh category:Calendar --follow
```

### Query métricas
```bash
# Todos los counters
./scripts/query-metrics.sh counters

# Gauge de duración de sesión
./scripts/query-metrics.sh gauge:current_session_duration

# Histogram de duración de sync (P95)
./scripts/query-metrics.sh histogram:calendar_sync_duration_ms --p95
```

## DevTools Protocol

```bash
# Exponer logs vía DevTools
./scripts/devtools-bridge.sh logs --follow

# Exponer métricas vía DevTools
./scripts/devtools-bridge.sh metrics
```

---

## Referencias

- [Logger.swift](../../Focally/Observability/Logger.swift) — Implementación de Logger
- [Metrics.swift](../../Focally/Observability/Metrics.swift) — Implementación de Metrics
- [PLAN-004_OBSERVABILITY.md](../exec-plans/active/PLAN-004_OBSERVABILITY.md) — Plan de observabilidad
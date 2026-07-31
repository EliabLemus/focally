# SERVICE_PATTERN.md — Patrón de Servicios

> Todos los services son ObservableObject singletons

---

## Patrón

```swift
final class GoogleCalendarService: NSObject, ObservableObject {
    static let shared = GoogleCalendarService()
    @Published var isEnabled = false
    @Published var events: [CalendarEvent] = []

    var currentMeeting: CalendarEvent? {
        // Computed property, solo lectura
        let now = Date()
        return events.first { $0.start <= now && $0.end > now }
    }
}
```

---

## Uso en Views

```swift
struct CalendarStatusCard: View {
    @EnvironmentObject private var calendarService: GoogleCalendarService

    var body: some View {
        if calendarService.isEnabled {
            Text("Current: \(calendarService.currentMeeting?.title ?? "Free")")
        }
    }
}
```

---

## Inicialización en App

```swift
@main
struct FocallyApp: App {
    @StateObject private var calendarService = GoogleCalendarService.shared
    @StateObject private var timerService = FocusTimerService.shared
    @StateObject private var slackService = SlackService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(calendarService)
                .environmentObject(timerService)
                .environmentObject(slackService)
        }
    }
}
```

---

## Services Existentes

| Service | Responsabilidad |
|---------|-----------------|
| `GoogleCalendarService` | Sync con Google Calendar, eventos actuales |
| `FocusTimerService` | Timer de focus, state management |
| `SlackService` | Status updates en Slack |
| `DNDService` | Control de Do Not Disturb nativo |
| `KeychainHelper` | Secure storage (tokens, API keys) |
| `AnalyticsService` | Tracking de eventos |
| `HistoryService` | Historial de sesiones |

---

## Reglas

1. **Siempre singleton** → `static let shared = Self()`
2. **ObservableObject** → `@Published` properties para reactividad
3. **Computed properties sin state** → `var currentMeeting: X? { }`
4. **NO inicializar en views** → Usar `@EnvironmentObject` o `@StateObject` en App

---

## Referencias

- [ARCHITECTURE.md](ARCHITECTURE.md) — Mapa de dominios
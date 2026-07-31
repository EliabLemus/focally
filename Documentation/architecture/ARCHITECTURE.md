# ARCHITECTURE.md — Arquitectura de Focally

> Basado en el enfoque de OpenAI: "un mapa, no un manual de 1000 páginas"

---

## Mapa de Dominios

```
Focally/
├── Models/                    # Tipos de datos, structs puros
│   ├── CalendarEvent.swift
│   ├── FocusTimerState.swift
│   └── PredefinedTask.swift
├── Services/                  # Lógica de negocio, singletons
│   ├── GoogleCalendarService.swift    # ObservableObject, singleton
│   ├── FocusTimerService.swift        # ObservableObject, singleton
│   ├── SlackService.swift             # ObservableObject, singleton
│   ├── DNDService.swift               # Singleton
│   ├── KeychainHelper.swift           # Helper
│   ├── AnalyticsService.swift         # Singleton
│   └── HistoryService.swift           # Singleton
├── ViewModels/               # Lógica de vista, state local
│   └── [ViewModel específicos por view]
├── Views/                    # UI SwiftUI
│   ├── MenuBar/
│   ├── Schedule/
│   ├── Timer/
│   ├── Analytics/
│   ├── Tasks/
│   ├── Settings/
│   └── Shared/
└── Resources/                # Assets, fonts, etc.
```

---

## Capas y Dependencias

**Regla de oro**: Dependencias solo hacia adelante.

```
Models → Services → ViewModels → Views
                     ↓
                  Providers (cross-cutting)
```

### Models
- **Responsabilidad**: Definir tipos de datos puros
- **Dependencias**: Ninguna
- **Ejemplo**: `CalendarEvent`, `FocusTimerState`, `PredefinedTask`

### Services
- **Responsabilidad**: Lógica de negocio, API calls, persistence
- **Dependencias**: Models, Providers
- **Patrón**: ObservableObject singletons
- **Ejemplo**: `GoogleCalendarService.shared`, `FocusTimerService.shared`

### ViewModels
- **Responsabilidad**: Lógica de vista, state local, transformación de datos
- **Dependencias**: Services, Models
- **Patrón**: ObservableObject o @State en views simples

### Views
- **Responsabilidad**: UI pura, bindings a ViewModels/Services
- **Dependencias**: ViewModels, Services (via @EnvironmentObject)
- **Patrón**: SwiftUI Views

### Providers
- **Responsabilidad**: Cross-cutting concerns (auth, telemetry, permissions, keychain)
- **Dependencias**: Ninguna (o solo frameworks de sistema)
- **Patrón**: Singletons o environment values
- **Ejemplo**: `KeychainHelper`, `AnalyticsService`

---

## Service Pattern

Todos los services son **ObservableObject singletons**:

```swift
final class GoogleCalendarService: NSObject, ObservableObject {
    static let shared = GoogleCalendarService()
    @Published var isEnabled = false
    @Published var events: [CalendarEvent] = []

    var currentMeeting: CalendarEvent? {
        // Computed property, solo lectura
    }
}
```

### Uso en Views

```swift
struct CalendarStatusCard: View {
    @EnvironmentObject private var calendarService: GoogleCalendarService

    var body: some View {
        if calendarService.isEnabled {
            // ...
        }
    }
}
```

### Inicialización en App

```swift
@main
struct FocallyApp: App {
    @StateObject private var calendarService = GoogleCalendarService.shared
    @StateObject private var timerService = FocusTimerService.shared
    @StateObject private var slackService = SlackService.shared

    var body: some Scene {
        // ...
    }
}
```

---

## State Management

### EnvironmentObject vs ObservedObject

- **@EnvironmentObject**: Services registrados globalmente (singletons)
  - Ej: `GoogleCalendarService`, `FocusTimerService`, `SlackService`
- **@ObservedObject**: ViewModels locales con múltiples instancias
  - Ej: `QuickSessionsSectionViewModel`

### StateObject vs State

- **@StateObject**: Cuando el view tiene un solo source of truth persistente
  - Ej: `@StateObject private var viewModel = ViewModel()`
- **@State**: Variables temporales del view
  - Ej: `@State private var taskInput = ""`

---

## Cross-Cutting Concerns

### Providers
Auth, telemetry, permissions, keychain entran a través de una única interfaz explícita: **Providers**.

No se permite acceso directo a:
- Keychain (usar `KeychainHelper`)
- UserDefaults (usar wrappers typed)
- Analytics (usar `AnalyticsService`)

### No App Groups
App Groups **NO están implementados** en Focally actualmente.

Si necesitas compartir data entre app y extension en el futuro:
1. Crear `Focally.app` y `Focally Extension.appex`
2. Configurar `app-group-id.focally`
3. Usar `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "...")`

---

## Invariantes de Estilo

Estas reglas se aplican mecánicamente con lints:

### Structured Logging
```swift
// ✅ Correcto: structured logging
logger.info("Calendar sync started", metadata: [
    "event_count": "\(events.count)",
    "duration_ms": "\(duration)"
])

// ❌ Incorrecto: strings sueltos
print("Syncing \(events.count) events...")
```

### Naming Conventions
- Schemas/Models: PascalCase con sufijos claros (`CalendarEvent`, `FocusTimerState`)
- File size: Máximo 500 líneas (enforced por lint)
- Reliability: macOS-specific requirements enforced por lint

---

## Testing Strategy

### Unit Tests
- Ubicación: `FocallyTests/`
- Target: Services lógicos, formateadores, helpers
- **NO mockear APIs externas** (Slack, Google Calendar)

### UI Tests
- Ubicación: `FocallyUITests/`
- Target: Flujos principales (crear sesión, iniciar timer)
- **Tests deben ser fast** — no reiniciar app completa si es posible

---

## Referencias

- [SERVICE_PATTERN.md](SERVICE_PATTERN.md) — Detalles del patrón de servicios
- [STATE_MANAGEMENT.md](STATE_MANAGEMENT.md) — Detalles de state management
- [LAYER_RULES.md](LAYER_RULES.md) — Reglas de dependencia entre capas
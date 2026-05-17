# STATE_MANAGEMENT.md — State Management en Focally

---

## EnvironmentObject vs ObservedObject

### @EnvironmentObject
- **Uso**: Services registrados globalmente (singletons)
- **Ejemplo**: `GoogleCalendarService`, `FocusTimerService`, `SlackService`
- **Inyección**: En `@main` App, disponible en toda la jerarquía

```swift
@main
struct FocallyApp: App {
    @StateObject private var calendarService = GoogleCalendarService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(calendarService)
        }
    }
}

struct SomeView: View {
    @EnvironmentObject private var calendarService: GoogleCalendarService
}
```

### @ObservedObject
- **Uso**: ViewModels locales con múltiples instancias
- **Ejemplo**: `QuickSessionsSectionViewModel`
- **Inyección**: Pasado como parámetro en init

```swift
struct QuickSessionsSection: View {
    @ObservedObject var viewModel: QuickSessionsSectionViewModel
}
```

---

## StateObject vs State

### @StateObject
- **Uso**: Cuando el view tiene un solo source of truth persistente
- **Ejemplo**: `@StateObject private var viewModel = ViewModel()`
- **Key**: El state se crea una vez y persiste

```swift
struct TimerView: View {
    @StateObject private var viewModel = TimerViewModel()

    var body: some View {
        // ...
    }
}
```

### @State
- **Uso**: Variables temporales del view
- **Ejemplo**: `@State private var taskInput = ""`
- **Key**: El state es local y puede ser recreado

```swift
struct TaskInputView: View {
    @State private var taskInput = ""

    var body: some View {
        TextField("Task", text: $taskInput)
    }
}
```

---

## @Binding

- **Uso**: Pasar @State de un parent view a un child
- **Ejemplo**: Custom components que modifican state del parent

```swift
struct ParentView: View {
    @State private var isEnabled = false

    var body: some View {
        Toggle(isOn: $isEnabled) {
            Text("Enabled")
        }
    }
}

struct Toggle: View {
    @Binding var isOn: Bool
}
```

---

## Reglas

1. **Services → @EnvironmentObject** (singletons globales)
2. **ViewModels → @ObservedObject** (instancias múltiples)
3. **Persistente en view → @StateObject** (creado una vez)
4. **Temporal en view → @State** (local, puede recrearse)
5. **Child modifica parent → @Binding** (two-way binding)

---

## Common Patterns

### Pattern 1: Service + Local ViewModel

```swift
struct CalendarView: View {
    @EnvironmentObject private var calendarService: GoogleCalendarService  // Service (singleton)
    @StateObject private var viewModel = CalendarViewModel()              // ViewModel (local)
}
```

### Pattern 2: Service Directo

```swift
struct StatusIndicator: View {
    @EnvironmentObject private var timerService: FocusTimerService  // Service (singleton)
}
```

### Pattern 3: State Local + Binding

```swift
struct ParentView: View {
    @State private var isExpanded = false

    var body: some View {
        ExpandableSection(isExpanded: $isExpanded) {
            Text("Content")
        }
    }
}

struct ExpandableSection<Content: View>: View {
    @Binding var isExpanded: Bool
    let content: Content
}
```

---

## Referencias

- [ARCHITECTURE.md](ARCHITECTURE.md) — Mapa de dominios
- [SERVICE_PATTERN.md](SERVICE_PATTERN.md) — Patrón de servicios
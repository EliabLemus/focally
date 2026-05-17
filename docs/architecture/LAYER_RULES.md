# LAYER_RULES.md — Reglas de Dependencia entre Capas

> Invariantes aplicados mecánicamente con lints

---

## Regla de Oro

**Dependencias solo hacia adelante.**

```
Models → Services → ViewModels → Views
                     ↓
                  Providers
```

---

## Reglas por Capa

### Models
- ✅ **Puede depender de**: Nada (puro)
- ❌ **NO puede depender de**: Services, ViewModels, Views, Providers
- **Responsabilidad**: Tipos de datos puros, sin lógica de negocio

### Services
- ✅ **Puede depender de**: Models, Providers
- ❌ **NO puede depender de**: ViewModels, Views
- **Responsabilidad**: Lógica de negocio, API calls, persistence

### ViewModels
- ✅ **Puede depender de**: Services, Models, Providers
- ❌ **NO puede depender de**: Views
- **Responsabilidad**: Lógica de vista, state local, transformación de datos

### Views
- ✅ **Puede depender de**: ViewModels, Services (via @EnvironmentObject), Models
- ❌ **NO puede depender de**: Nada más (es la capa final)
- **Responsabilidad**: UI pura, bindings

### Providers
- ✅ **Puede depender de**: Nada (o solo frameworks de sistema)
- ❌ **NO puede depender de**: Nada más
- **Responsabilidad**: Cross-cutting concerns (auth, telemetry, permissions, keychain)

---

## Invariantes Aplicados por Lint

### 1. Imports circulares detectados
```swift
// ❌ Import circular detectado por lint
// Service importa View → View importa Service

// ✅ Correcto: Service NO importa Views
```

### 2. Providers única entrada
```swift
// ❌ Incorrecto: acceso directo a Keychain
let token = KeychainHelper.shared.get(key: "token")

// ✅ Correcto: acceso vía Service wrapper
calendarService.getAuthToken()  // Service llama a KeychainHelper internamente
```

### 3. File size limit (500 líneas)
```swift
// Lint error: "File exceeds 500 lines. Split into smaller files."
```

### 4. Structured logging enforcement
```swift
// ❌ Incorrecto
print("User clicked button")

// ✅ Correcto
logger.info("Button clicked", metadata: ["action": "toggle_focus"])
```

---

## Ejemplos de Violaciones

### Violación 1: View importa Service directamente
```swift
// ❌ Incorrecto: View importa Service
import Foundation
import GoogleCalendarService  // ❌ NO

struct CalendarView: View {
    // ...
}

// ✅ Correcto: View recibe Service via @EnvironmentObject
struct CalendarView: View {
    @EnvironmentObject private var calendarService: GoogleCalendarService
    // ...
}
```

### Violación 2: Service importa View
```swift
// ❌ Incorrecto: Service importa View
import Foundation
import CalendarView  // ❌ NO

final class GoogleCalendarService: ObservableObject {
    // ...
}
```

### Violación 3: ViewModel importa otro ViewModel
```swift
// ❌ Incorrecto: ViewModel depende de otro ViewModel
import Foundation
import ScheduleViewModel  // ❌ NO

struct TimerViewModel: ObservableObject {
    // ...
}

// ✅ Correcto: ViewModels dependen de Services, no de otros ViewModels
struct TimerViewModel: ObservableObject {
    @ObservedObject private var scheduleService: ScheduleService
    // ...
}
```

---

## Implementación de Lints

Estos lints se implementan en:
- **SwiftLint**: Configuración custom en `.swiftlint.yml`
- **Tests estructurales**: En `FocallyTests/LayerTests.swift`

### Ejemplo de Test Estructural

```swift
func testServicesDoNotImportViews() {
    let services = try! FileManager.default.contentsOfDirectory(atPath: "Focally/Services")
    for service in services {
        let content = try! String(contentsOfFile: "Focally/Services/\(service)")
        XCTAssertFalse(content.contains("import Views"), "\(service) imports Views")
    }
}
```

---

## Referencias

- [ARCHITECTURE.md](ARCHITECTURE.md) — Mapa de dominios
- [SERVICE_PATTERN.md](SERVICE_PATTERN.md) — Detalles del patrón de servicios
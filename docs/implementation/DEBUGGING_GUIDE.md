# DEBUGGING_GUIDE.md — Cómo Debuggear Focally

---

## Common Issues

### Build falla en CI pero pasa localmente

**Síntoma**: GitHub Actions falla, build local pasa.

**Causas típicas**:
1. Type annotations faltantes en closures (Swift strict mode)
2. Colores hardcodeados (CI usa Asset Catalog)
3. Import circulares

**Solución**:
```swift
// ❌ Incorrecto: sin type hint
.sink { result in }

// ✅ Correcto: type hint explícito
.sink { (_: Result<Void, Error>) in }
```

---

### Services no actualizan UI

**Síntoma**: Cambios en @Published properties no reflejan en UI.

**Causas típicas**:
1. Service no está registrado como @EnvironmentObject
2. View no usa @EnvironmentObject
3. En @main App, falta .environmentObject()

**Solución**:
```swift
// 1. En @main App
@main
struct FocallyApp: App {
    @StateObject private var calendarService = GoogleCalendarService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(calendarService)  // ← NO olvidar esto
        }
    }
}

// 2. En view
struct CalendarView: View {
    @EnvironmentObject private var calendarService: GoogleCalendarService  // ← NO usar @StateObject
}
```

---

### Retain Cycles

**Síntoma**: Memory leaks, views no deallocan.

**Causa típica**: Closures con strong self.

**Solución**:
```swift
// ❌ Incorrecto: strong self
.sink { result in
    self.taskInput = ""  // Retain cycle!
}

// ✅ Correcto: weak self
.sink { [weak self] result in
    guard let self = self else { return }
    self.taskInput = ""
}
```

---

### Keychain access falla

**Síntoma**: Tokens no se guardan/recuperan.

**Causas típicas**:
1. Keychain no desbloqueado
2. Mala keychain access en sandbox
3. Key prefix incorrecto

**Solución**:
```swift
// ✅ Usar KeychainHelper
try? KeychainHelper.save(value: token, key: "google_calendar_token")
let token = try? KeychainHelper.get(key: "google_calendar_token")
```

**Debug**:
```bash
# Verificar keychain access
security dump-keychain -i login.keychain | grep focally
```

---

### Google Calendar API fails

**Síntoma**: No se cargan eventos.

**Causas típicas**:
1. Token expirado
2. OAuth scope incorrecto
3. Rate limit

**Debug**:
```swift
// 1. Verificar token
print("Token exists: \(calendarService.token != nil)")

// 2. Verificar events count
print("Events count: \(calendarService.events.count)")

// 3. Verificar errores
// (Agregar logging en GoogleCalendarService)
```

**Ver en Console.app**:
```
Filter: process == "Focally" AND subsystem == "com.google.calendar"
```

---

### Slack status no actualiza

**Síntoma**: Slack status no cambia al iniciar/terminar sesión.

**Causas típicas**:
1. Token incorrecto
2. Scope incorrecto
3. Rate limit (150 msgs/min)

**Debug**:
```bash
# Verificar token (via KeychainHelper)
security find-generic-password -a "focally.slack" -w

# Test manual API
curl -X POST https://slack.com/api/users.profile.set \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"profile": {"status_text": "Testing", "status_emoji": ":spiral_note_pad:"}}'
```

---

### Color tokens no funcionan

**Síntoma**: UI no respeta design system.

**Causas típicas**:
1. Usando shorthand `.focallyXxx` (no resuelve en muchos contextos)
2. Asset Catalog no configurado
3. Missing color sets

**Solución**:
```swift
// ❌ Incorrecto: shorthand
.foregroundStyle(.focallyOnSurface)

// ✅ Correcto: Color type explícito
.foregroundStyle(Color.focallyOnSurface)
```

**Debug**:
```bash
# Verificar Asset Catalog
ls -la Focally/Assets.xcassets/Color/
```

---

## Debugging Tools

### Console.app
```bash
open /Applications/Utilities/Console.app
# Filter: process == "Focally"
```

### Breakpoints en Xcode
```swift
// Add breakpoint en:
// - Service init
// - Service state changes
// - View body
// - Closure captures
```

### Print debugging
```swift
// ✅ Structured logging
logger.info("Calendar sync started", metadata: [
    "event_count": "\(events.count)",
    "duration_ms": "\(duration)"
])

// ❌ Strings sueltos
print("Syncing \(events.count) events...")
```

### Memory profiling
```bash
# En Xcode: Product > Profile > Leaks
# Revisar retain cycles
```

---

## When to Ask for Help

1. **Revisar AGENTS.md** → Quick reference
2. **Revisar docs/** → Dominio específico
3. **Usar `rg`** → Buscar patrones existentes
4. **Leer commits recientes** → `git log --oneline`
5. **Testear en clean state** → `git clean -fdx && xcodebuild clean`

---

## Referencias

- [AGENTS.md](../../AGENTS.md) — Quick reference
- [ARCHITECTURE.md](../architecture/ARCHITECTURE.md) — Mapa de dominios
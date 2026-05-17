# TESTING_GUIDE.md — Guía de Testing

---

## Test Types

### Unit Tests
- **Ubicación**: `FocallyTests/`
- **Target**: `FocallyTests`
- **Ejecuta en CI**: Sí

**Qué probar**:
- Services lógicos (`FocusTimerService`, `GoogleCalendarService` logic)
- Formateadores (`DateExtensions.formatTime()`)
- Helpers (`KeychainHelper` logic)

### UI Tests
- **Ubicación**: `FocallyUITests/`
- **Target**: `FocallyUITests`
- **Ejecuta en CI**: Sí

**Qué probar**:
- Flujos principales (crear sesión, iniciar timer)
- Navegación principal (abrir menubar, cambiar tabs)

---

## Running Tests

```bash
# Todos los tests
xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS'

# Solo unit tests
xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS' -only-testing:FocallyTests

# Solo UI tests
xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS' -only-testing:FocallyUITests

# Tests con coverage
xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS' -enableCodeCoverage YES
```

---

## Testing Guidelines

### 1. Tests deben pasar antes de merge
- NO hacer merge si tests fallan
- Si tests son flaky, arreglar antes de continuar

### 2. NO mockear APIs externas
- **Slack API**: NO mockear (usar test token o skip tests)
- **Google Calendar API**: NO mockear (usar test calendar o skip tests)
- **Keychain**: NO mockear (usar test keychain o mock data layer)

**Razón**: Tests de integración son más valiosos que tests aislados.

### 3. Tests de UI deben ser fast
- NO reiniciar app completa en cada test
- Usar `XCUIApplication.launch()` una vez por suite
- Reusar app instance entre tests

```swift
// ✅ Correcto: lanzar una vez
let app = XCUIApplication()
app.launch()

func test_create_session() {
    app.buttons["New Session"].click()
    // ...
}

func test_start_timer() {
    app.buttons["Start Timer"].click()
    // ...
}
```

### 4. Tests de Services deben cubrir edge cases
```swift
func testCalendarService_noEvents() {
    let service = GoogleCalendarService()
    service.events = []

    XCTAssertNil(service.currentMeeting)
}

func testCalendarService_eventsInPast() {
    let service = GoogleCalendarService()
    service.events = [
        CalendarEvent(start: Date().addingTimeInterval(-3600), end: Date().addingTimeInterval(-1800))
    ]

    XCTAssertNil(service.currentMeeting)
}

func testCalendarService_currentMeeting() {
    let service = GoogleCalendarService()
    let now = Date()
    service.events = [
        CalendarEvent(start: now.addingTimeInterval(-300), end: now.addingTimeInterval(300))
    ]

    XCTAssertEqual(service.currentMeeting?.title, "Meeting")
}
```

---

## Common Test Patterns

### Pattern 1: Service State Changes

```swift
func testFocusTimerService_start() {
    let service = FocusTimerService()
    service.startSession(duration: 1500)

    XCTAssertEqual(service.state, .running)
    XCTAssertGreaterThan(service.remainingSeconds, 0)
}
```

### Pattern 2: Formatter Tests

```swift
func testDateExtension_formatTime() {
    let date = Date(timeIntervalSince1970: 0)
    XCTAssertEqual(date.formatTime(), "00:00:00")
}
```

### Pattern 3: UI Flow Tests

```swift
func test_create_session_and_start() {
    let app = XCUIApplication()
    app.launch()

    app.buttons["New Session"].click()
    app.textFields["Task Name"].typeText("Test Task")
    app.buttons["Start"].click()

    XCTAssertTrue(app.staticTexts["Test Task"].exists)
}
```

---

## Debugging Failed Tests

### 1. Verificar Xcode output
```bash
xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS' 2>&1 | tee test.log
grep "Test Suite.*failed" test.log
```

### 2. Verificar test logs en Console.app
```
Filter: process == "xctest" AND subsystem == "com.apple.dt.XCTest"
```

### 3. Verificar code coverage
```bash
xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS' -enableCodeCoverage YES
# Xcode > Report > Coverage
```

---

## Skipping Tests

Si un test depende de APIs externas no disponibles en CI:

```swift
func testSlackService_updateStatus() throws {
    #if !targetEnvironment(simulator)
    // Solo ejecutar en device
    try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] != nil, "Skipping in CI")

    let service = SlackService()
    service.updateStatus(text: "Test", emoji: ":test:")

    // ...
    #endif
}
```

---

## When Tests Fail

1. **Verificar que tests NO son flaky**
   - Correr 3 veces: si falla inconsistente, es flaky
   - Arreglar flaky antes de continuar

2. **Verificar environment**
   - macOS version: debe ser ≥ 14.0
   - Xcode version: debe soportar Swift 5.9

3. **Verificar dependencies**
   - NO hay dependencias externas (package.swift no existe)

4. **Verificar code signing**
   - Tests NO requieren code signing

---

## Referencias

- [AGENTS.md](../../AGENTS.md) — Quick reference
- [ARCHITECTURE.md](../architecture/ARCHITECTURE.md) — Mapa de dominios
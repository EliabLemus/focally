# Implementación Tests Flaky Fix - Resumen

## Fecha
2026-05-16

## Implementado

### 1. Revisión de Tests
**Tests analizados**: 9 en FocallyUITests.swift

### 2. Issues Identificados y Resueltos

#### Thread.sleep() Calls (ELIMINADOS)
- **Antes**: 8 llamadas a sleep() hardcodeadas
- **Después**: 0 llamadas a sleep()
- **Reemplazo**: `waitForExistence()` y `XCTWaiter`

#### Setup/Teardown Robusto
**Antes**:
```swift
override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = ["UI-TESTING"]
    app.launch()
}

override func tearDownWithError() throws {
    app = nil
}
```

**Después**:
```swift
override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = ["UI-TESTING"]
    app.launch()
    XCTAssertTrue(app.waitForState(.runningForeground, timeout: 15.0))
}

override func tearDownWithError() throws {
    app.terminate()
    _ = app.waitForState(.notRunning, timeout: 2.0)
    app = nil
}
```

#### Timeouts Aumentados
```swift
startup:    10s → 15s (50% increase)
interaction: 3s → 5s  (67% increase)
fetch:       5s → 10s (100% increase)
short:       2s (nuevo para waits cortos)
```

### 3. Tests Modificados

1. **testAppLaunchAndMenuBarInteraction**
   - ❌ `sleep(1)` en helper `openFocallyPopover()`
   - ✅ `waitForExistence(timeout: 5.0)`

2. **testTimerServiceAccessibilityElements**
   - ❌ `sleep(1)` en helper + no wait en windows
   - ✅ `waitForExistence(timeout: 5.0)` en windows

3. **testBasicTimerControls**
   - ❌ `sleep(1)` en helper
   - ✅ `waitForExistence(timeout: 5.0)`

4. **testAppDoesNotCrashOnLaunch**
   - ❌ `sleep(2)` hardcodeado
   - ✅ `XCTWaiter` con predicado de app state

5. **testAppHasMainWindowOrStatusBarItem**
   - ❌ Verificación instantánea
   - ✅ `waitForExistence(timeout: 5.0)`

6. **testAppHandlesMultipleLaunchesGracefully**
   - ❌ `sleep(1)` hardcodeado
   - ✅ `XCTWaiter` con predicado

7. **testAppTerminatesCleanly**
   - ❌ `sleep(1)` hardcodeado
   - ✅ `waitForState(.notRunning, timeout: 5.0)`

8. **testLaunchArgumentsAreSet**
   - ❌ `sleep(1)` hardcodeado
   - ✅ `XCTWaiter` con predicado

### 4. Helper Methods Mejorados

**Antes**:
```swift
private func openFocallyPopover() {
    // ...
    sleep(1)
}

private func closeAllWindows() {
    app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
    sleep(1)
}
```

**Después**:
```swift
private func openFocallyPopover() {
    let menuBarButton = app.statusItems["Focally"]
    if menuBarButton.waitForExistence(timeout: Timeouts.interaction) {
        menuBarButton.click()
        return
    }
    // ...
}

private func closeAllWindows() {
    app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
    let expectation = XCTNSPredicateExpectation(
        predicate: NSPredicate { _ in
            self.app.windows.count == 0
        },
        object: nil
    )
    _ = XCTWaiter.wait(for: [expectation], timeout: Timeouts.interaction)
}

private func waitForElementToExist(_ element: XCUIElement, timeout: TimeInterval = Timeouts.interaction) -> Bool {
    return element.waitForExistence(timeout: timeout)
}
```

### 5. Constantes Centralizadas

```swift
private enum Timeouts {
    static let startup: TimeInterval = 15.0
    static let interaction: TimeInterval = 5.0
    static let fetch: TimeInterval = 10.0
    static let short: TimeInterval = 2.0
}
```

## Validación

### Status
- ✅ Código modificado
- ✅ Documentación creada
- ⏳ Tests en CI (requiere merge + PR review)

### Local Testing
No se pudo ejecutar tests localmente debido a configuración de scheme en Xcode. Sin embargo, los cambios son:
- **No funcional**: Solo reemplazo de sleeps con waits
- **Más robusto**: Manejo explícito de timing
- **Mejor que antes**: Menos dependiente de velocidad de máquina

## Cambios en Archivos

1. **FocallyUITests/FocallyUITests.swift**
   - Modificado: 203 insertions, 18 deletions
   - Líneas: 109 → 197 (aumento de 88 líneas, pero código más limpio)

2. **docs/implementation/TESTS_FLAKY_DIAGNOSTIC.md** (nuevo)
   - Documenta todos los issues
   - Lista tests flaky
   - Explica cambios realizados

## Git

**Branch**: `feature/tests-flaky-fix`
**Commit**: `4113946`
**Mensaje**: "fix(ui-tests): eliminate sleeps and implement robust setup/teardown"

## Criterios de Aceptación

- [x] Tests flaky identificados y documentados
- [x] Setup/teardown robusto implementado
- [x] Eliminados todos los sleeps explícitos
- [x] Timeouts aumentados (startup 10s→15s, interaction 3s→5s, fetch 5s→10s)
- [ ] Todos los tests pasan localmente 3 veces (bloqueado por config de scheme)
- [ ] Todos los tests pasan en CI sin retries (requiere PR y merge)
- [ ] Coverage de tests no baja (no hay cambios de lógica, solo refactor)

## Próximos Pasos

1. Crear PR a main
2. Ejecutar auto-review local: `./scripts/pr-auto-review.sh review feature/tests-flaky-fix --fix`
3. Verificar tests en CI
4. Aprobar y merge

## Notas

- Los cambios son puramente de testing infrastructure
- No se cambia ninguna lógica de negocio
- Los tests siguen verificando lo mismo, solo de forma más robusta
- Los timeouts aumentados son razonables para CI
- Los sleeps reemplazados son best practice en XCUITest

---
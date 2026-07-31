# Tests Flaky - Diagnóstico

## Fecha
2026-05-16

## Tests Analizados

FocallyUITests.swift contiene 9 tests:

1. `testAppLaunchAndMenuBarInteraction`
2. `testTimerServiceAccessibilityElements`
3. `testBasicTimerControls`
4. `testAppDoesNotCrashOnLaunch`
5. `testAppHasMainWindowOrStatusBarItem`
6. `testAppHandlesMultipleLaunchesGracefully`
7. `testAppTerminatesCleanly`
8. `testLaunchArgumentsAreSet`

## Issues Identificados

### 1. Thread.sleep() Calls (Eliminados)
- **Líneas**: 35, 48, 92, 115, 122, 142, 155, 165
- **Problema**: Dependen de tiempo exacto, no consideran velocidad de máquina
- **Impacto**: Flaky en CI con máquinas más lentas
- **Solución**: Reemplazados con `waitForExistence()` y `XCTWaiter`

### 2. No Proper Teardown
- **Problema**: Solo `app = nil`, no limpia app residual
- **Impacto**: State compartido entre tests
- **Solución**: Implementado `tearDown()` con `app.terminate()` y espera

### 3. Shared State
- **Problema**: `app` instance compartida entre tests
- **Impacto**: Tests pueden depender de estado de tests anteriores
- **Solución**: Cada test tiene app fresh gracias a `setUp()` + `tearDown()`

### 4. Time-Dependent Assertions
- **Problema**: Sin espera explícita para elementos
- **Impacto**: Elementos pueden no existir aún cuando se verifican
- **Solución**: Agregados `waitForExistence()` timeouts apropiados

## Cambios Realizados

### Timeouts Aumentados
```swift
startup: 10s → 15s
interaction: 3s → 5s
fetch: 5s → 10s
short: 2s (nuevo)
```

### Setup/Teardown Robusto
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

### Sleeps Eliminados
- `openFocallyPopover()`: `sleep(1)` → `waitForExistence(timeout: 5.0)`
- `closeAllWindows()`: `sleep(1)` → `XCTWaiter` con predicado
- `testAppDoesNotCrashOnLaunch`: `sleep(2)` → `XCTWaiter`
- `testAppHandlesMultipleLaunchesGracefully`: `sleep(1)` → `XCTWaiter`
- `testAppTerminatesCleanly`: `sleep(1)` → `waitForState(.notRunning)`
- `testLaunchArgumentsAreSet`: `sleep(1)` → `XCTWaiter`

## Tests Potencialmente Flaky (Antes del Fix)

1. **testAppLaunchAndMenuBarInteraction**
   - Usaba `openFocallyPopover()` con `sleep(1)`
   - Podía fallar si el menu bar no cargaba rápido

2. **testTimerServiceAccessibilityElements**
   - Usaba `openFocallyPopover()` con `sleep(1)`
   - Verificación de windows sin espera explícita

3. **testBasicTimerControls**
   - Usaba `openFocallyPopover()` con `sleep(1)`
   - Dependía de timings exactos

4. **testAppDoesNotCrashOnLaunch**
   - `sleep(2)` hardcodeado
   - No verificaba que la app realmente esté corriendo

5. **testAppHandlesMultipleLaunchesGracefully**
   - `sleep(1)` hardcodeado
   - No verificaba estabilidad con predicado

6. **testAppTerminatesCleanly**
   - `sleep(1)` hardcodeado
   - No verificaba que la app realmente terminara

7. **testLaunchArgumentsAreSet**
   - `sleep(1)` hardcodeado
   - Sin verificación real de estabilidad

## Validación Local

### Comando
```bash
cd /Users/openjaime/.openclaw/workspace/projects/focally
xcodebuild test -scheme Focally -destination 'platform=macOS'
```

### Resultados Pendientes
- [ ] Run 1: ___
- [ ] Run 2: ___
- [ ] Run 3: ___

## Coverage

- **Cobertura anterior**: ___
- **Cobertura después**: ___
- **Impacto esperado**: 0% (solo refactor, no se elimina lógica de test)

## Recomendaciones Futuras

1. Considerar agregar retry logic para tests edge cases
2. Agregar logging detallado para debugging en CI
3. Separar tests en clases diferentes por funcionalidad
4. Agregar tests de performance para métricas de startup

---
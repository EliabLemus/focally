# BUG_FIX: Tests Flaky en FocallyUITests

---

## Problema

Los tests en `FocallyUITests` son **flaky** — a veces pasan, a veces fallan sin un patrón claro.

**Evidencia**:
- Fallan inconsistente en GitHub Actions CI
- Pasan localmente cuando se corren varias veces
- Sin patrón visual claro en el código

**Impacto**:
- Bloquea CI frecuentemente
- Requiere retries manuales
- Reduce confianza en el test suite
- Desacelera desarrollo

---

## Diagnóstico

### Posibles Causas

1. **Race Conditions**
   - App no termina completamente antes del siguiente test
   - Shared state entre tests
   - Timer/events que no se completan en el tiempo esperado

2. **Time-Dependent Tests**
   - Tests que dependen de tiempos exactos (sleeps, timers)
   - Tests que asumen tiempo de startup específico

3. **UI State Inconsistency**
   - App no está en el mismo estado inicial entre tests
   - Background processes que no se limpiaron

4. **Network/External Dependencies**
   - Google Calendar/Slack API timeouts
   - Shortcuts ejecutándose en background

### Archivos a Investigar

```
FocallyUITests/
├── FocallyUITests.swift
└── [otros tests]
```

---

## Solución Propuesta

### Estrategia General

1. **Aislar tests flaky**: Identificar qué tests específicos fallan
2. **Preparar state**: Asegurar app en estado conocido antes de cada test
3. **Reducir dependencias de tiempo**: Eliminar sleeps, usar espera explícita
4. **Shared cleanup**: Implementar setup/teardown robusto
5. **Aumentar timeouts**: Para casos edge cases
6. **Isolar tests**: Usar diferentes target groups si aplica

### Plan de Acción

1. **Revisar tests existentes** y identificar:
   - Tests que usan sleep()
   - Tests que dependen de tiempo exacto
   - Tests que acceden a datos externos
   - Tests que comparten state

2. **Implementar setup/teardown robusto**:
   ```swift
   override func setUp() {
       super.setUp()
       // Clean up app state
       // Reset UserDefaults
       // Wait for app to fully start
   }

   override func tearDown() {
       // Clean up app state
       // Kill background processes
       super.tearDown()
   }
   ```

3. **Eliminar sleeps explícitos** y reemplazar con:
   ```swift
   // ❌ Incorrecto
   app.launch()
   Thread.sleep(forTimeInterval: 2.0)
   XCTAssert(app.buttons["Start"].exists)

   // ✅ Correcto
   app.launch()
   XCTAssert(app.buttons["Start"].waitForExistence(timeout: 5.0))
   ```

4. **Aumentar timeouts** en tests críticos:
   - Startup: 10s → 15s
   - Interacción: 3s → 5s
   - Fetch data: 5s → 10s

5. **Isolar tests entre sí**:
   - Usar diferentes bundles si aplica
   - Limpiar entre tests

6. **Agregar retry logic** para tests que fallan por race conditions:
   ```swift
   func testSomething() {
       var attempts = 0
       while attempts < 3 {
           attempts += 1
           if XCTAssert...() {
               break
           }
       }
   }
   ```

---

## Criterios de Aceptación

- [ ] Tests flaky identificados y documentados
- [ ] Setup/teardown robusto implementado
- [ ] Eliminados todos los sleeps explícitos
- [ ] Todos los tests pasan localmente 3 veces
- [ ] Todos los tests pasan en CI sin retries
- [ ] Coverage de tests no baja por los cambios
- [ ] Documentación de setup/teardown en FocallyUITests.swift

---

## Notas Técnicas

### Tests Existentes

Revisar en FocallyUITests/ para ver qué tests hay.

### Posibles Areas de Problema

1. **Test lifecycle**:
   - `launch()` no limpio entre tests
   - State residual de tests anteriores

2. **Timer/UI events**:
   - Events que no se completan en el tiempo esperado
   - App responde antes/después que se espera

3. **Background processes**:
   - Shortcuts ejecutándose en background
   - Notifications que afectan la UI

4. **Network**:
   - Google Calendar API timeouts
   - Slack API timeouts

### Recursos de Debugging

1. **Logs**:
   ```bash
   # Ver logs de tests
   open /Applications/Utilities/Console.app
   # Filter: process == "xctest"
   ```

2. **Coverage**:
   ```bash
   xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS' -enableCodeCoverage YES
   ```

3. **Test logs**:
   ```bash
   xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS' 2>&1 | tee test.log
   ```

---

## Timeline Estimado

**Effort**: 2 días

### Día 1
- [ ] Diagnóstico: Identificar tests flaky
- [ ] Implementar setup/teardown robusto
- [ ] Eliminar sleeps explícitos
- [ ] Ejecutar tests localmente

### Día 2
- [ ] Aumentar timeouts en tests críticos
- [ ] Isolar tests entre sí
- [ ] Ejecutar tests 3 veces localmente
- [ ] Verificar CI pasa sin retries

---

## Referencias

- [AGENTS.md](../../AGENTS.md) — Quick reference
- [TESTING_GUIDE.md](../implementation/TESTING_GUIDE.md) — Guía de testing
- [DEBUGGING_GUIDE.md](../implementation/DEBUGGING_GUIDE.md) — Cómo debuggear
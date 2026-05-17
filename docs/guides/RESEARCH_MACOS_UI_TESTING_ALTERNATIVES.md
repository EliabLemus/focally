# Research: macOS UI Testing Alternatives to XCUITest

**Fecha:** 2026-05-13
**Propósito:** Explorar alternativas a XCUITest para Focally (macOS Menu Bar App)

## Problema Actual con XCUITest

### Limitaciones Identificadas

1. **CLI Limitations**
   - `xcodebuild test` falla con error: "There are no test bundles available to test"
   - XCUITest en macOS con XcodeGen tiene restricciones conocidas
   - Acceso a `NSStatusBar` y menu bar items es complejo en XCUITest CLI

2. **Menu Bar Access**
   - `app.statusItems` property no está disponible en `XCUIElement` de macOS
   - Verificar elementos en popovers requiere enfoques alternativos
   - Menu bar apps tienen arquitectura diferente a apps con ventanas

3. **Automation Restrictions**
   - Osascript falla: "System Events got an error: osascript is not allowed to send keystrokes"
   - Requiere permisos de Accessibility que son difíciles en CI/headless

4. **CI/CD Challenges**
   - Ejecutar UI tests en CI requiere macOS runners con Xcode GUI
   - GitHub Actions macOS runners no tienen GUI por defecto
   - Headless testing en macOS es limitado

---

## Alternativas Exploradas

### 1. Appium for Mac

**Descripción:** Wrapper alrededor de XCTest/XCUITest que ofrece una API más flexible y soporte multi-plataforma.

**Pros:**
- ✅ API más simple que XCUITest nativo
- ✅ Multi-plataforma (puedes usar mismo código para iOS/macOS)
- ✅ Soporta lenguajes como Python, Java, JavaScript
- ✅ Mejor soporte para CI/CD (Docker, Selenium Grid)
- ✅ Capacidad de test en paralelo

**Cons:**
- ❌ Todavía depende de XCUITest por debajo (no soluciona el problema de raíz)
- ❌ Requiere WebDriverAgent setup adicional
- ❌ Más complejidad de configuración
- ❌ Menu bar apps siguen siendo difíciles de automatizar

**Viabilidad para Focally:** ⚠️ **Media**
- No soluciona el problema de XCUITest en CLI
- Añade capas pero el problema base persiste

---

### 2. Maestro

**Descripción:** Framework de testing UI multi-plataforma con DSL declarativa (Swift para iOS/macOS).

**Pros:**
- ✅ Sintaxis muy simple y declarativa
- ✅ Soporte nativo para Swift
- ✅ Buen soporte para apps iOS/macOS
- ✅ Genera flows que pueden reutilizarse como E2E tests
- ✅ No requiere escribir XPath/selectors complejos

**Cons:**
- ❌ Menos maduro que XCUITest
- ❌ Community más pequeña
- ❌ Documentación menos extensa
- ❌ Aún en desarrollo activo, puede tener bugs
- ❌ Menú bar apps pueden no estar bien soportadas

**Viabilidad para Focally:** ⚠️ **Media**
- Sintaxis atractiva pero no garantiza mejor soporte para menu bar apps
- Más experimental que XCUITest

---

### 3. Robot Framework

**Descripción:** Framework genérico de automatización basado en Python con keywords. Usa librerías como Appium Library o PyAutoGUI.

**Pros:**
- ✅ Basado en keywords (BDD-friendly)
- ✅ Muy flexible y extensible
- ✅ Soporta múltiples lenguajes (Python, Java)
- ✅ Genera reports HTML automáticamente
- ✅ Bueno para casos de E2E complejos

**Cons:**
- ❌ **No soporta SwiftUI nativo** (requiere UIAutomation de AppKit)
- ❌ Focally es SwiftUI + AppKit → **NO compatible**
- ❌ Aprendizaje curva alto para configurar
- ❌ Menú bar apps con SwiftUI no son bien soportadas

**Viabilidad para Focally:** ❌ **Baja/Invierte**
- Focally usa SwiftUI → Robot Framework no es adecuado

---

### 4. PyAutoGUI + Accessibility

**Descripción:** Automatización de GUI genérica usando Python + Accessibility APIs de macOS.

**Pros:**
- ✅ No depende de XCTest/XCUITest
- ✅ Puede interactuar con cualquier app de macOS
- ✅ Usa APIs nativas de Accessibility
- ✅ Bueno para apps que no pueden instrumentar con XCUITest

**Cons:**
- ❌ Requiere entender profundamente Accessibility APIs
- ❌ No es declarativo (todo es código imperativo)
- ❌ Difícil de mantener en proyectos grandes
- ❌ Menu bar items son difíciles de controlar
- ❌ Requiere permisos Accessibility específicos

**Viabilidad para Focally:** ⚠️ **Media-Alta**
- Podría funcionar pero mucha complejidad
- Requiere permisos adicionales

---

### 5. Xcode GUI Automation (Scriptable)

**Descripción:** Usar Xcode GUI con scripts de AppleScript/Shortcuts para ejecutar tests manualmente.

**Pros:**
- ✅ Usa XCUITest nativo sin cambios
- ✅ No requiere frameworks externos
- ✅ Permite ver visualmente los tests corriendo
- ✅ Acceso completo a todas las capacidades de XCUITest

**Cons:**
- ❌ **No automatizable en CI** (requiere GUI activa)
- ❌ Lento comparado con CLI
- ❌ Requiere máquina dedicada con GUI
- ❌ No puede ejecutarse en GitHub Actions runners
- ❌ Falla con restricciones de Accessibility

**Viabilidad para Focally:** ⚠️ **Solo Manual**
- Útil para testing manual pero no para CI/CD

---

### 6. Swift Testing Framework (Nativo de Apple)

**Descripción:** Nuevo framework de testing de Apple (`@Test`, `#expect`, `@Suite`) que reemplaza XCTest.

**Pros:**
- ✅ Nativo de Apple, bien integrado con Xcode
- ✅ Sintaxis moderna (`#expect` vs `XCTAssertEqual`)
- ✅ Soporte nativo para async/await
- ✅ Mejor para unit tests y tests de lógica de negocio

**Cons:**
- ❌ **NO es una alternativa a XCUITest** (sirve para unit/integration tests)
- ❌ No tiene capacidades de UI testing automatizado
- ❌ Requiere migración desde XCTest (costo inicial)

**Viabilidad para Focally:** ✅ **Alta** (para unit tests, NO para UI tests)
- Excelente para reemplazar unit tests existentes
- No soluciona el problema de XCUITest UI

---

### 7. Custom XCTestHelper (Recomendada)

**Descripción:** Crear wrappers alrededor de XCUITest que abstraen la complejidad de menu bar apps.

**Enfoque:**

1. **Helper Methods Avanzados**
   ```swift
   extension XCUIApplication {
       func openFocallyMenu() -> XCUIElement {
           // Múltiples estrategias para encontrar menu bar item
           // 1. Por accessibility identifier
           // 2. Por bundle identifier
           // 3. Por título/label
           // 4. Fallback a scripting bridge
       }

       func tapMenuItem(named name: String) {
           // Abstracción para clickear items en popover
       }
   }
   ```

2. **Testing por Componentes (sin UI completa)**
   - Separar lógica de TimerService, SlackService, etc.
   - Tests unitarios de servicios (ya hechos ✅)
   - Tests de integración sin dependencia de UI

3. **Accessibility Identifiers Completos**
   - Ya implementados: `startPomodoroButton`, `stopPomodoroButton`, etc.
   - Expandir a todos los elementos interactivos

4. **Screen Capture para Debug**
   ```swift
   func takeScreenshot(named: String) {
       let screenshot = app.screenshot()
       let attachment = XCTAttachment(screenshot: screenshot)
       attachment.lifetime = .keepAlways
       add(attachment)
   }
   ```

**Pros:**
- ✅ Usa XCUITest nativo (sin dependencias externas)
- ✅ Puedes mejorar gradualmente
- ✅ Compatibilidad total con Xcode/CI
- ✅ Reutilizable en otros proyectos

**Cons:**
- ❌ Requiere trabajo inicial de ingeniería
- ❌ Menu bar apps siguen siendo difíciles
- ❌ Necesita iteración y prueba

**Viabilidad para Focally:** ✅ **Alta**
- Mejor opción a largo plazo
- Construye sobre lo que ya tienes
- Compatible con CI/CD existente

---

## Skills Disponibles en Workspace

### testing-swift
- **Ubicación:** `~/.openclaw/workspace/skills/testing-swift/SKILL.md`
- **Descripción:** Swift Testing Framework (@Test, #expect, @Suite)
- **Uso:** Unit tests modernos, migration from XCTest
- **Viabilidad para UI Tests:** ❌ NO (es solo para unit/integration tests)

### test-skill
- **Ubicación:** `~/.openclaw/workspace/skills/test-skill/SKILL.md`
- **Descripción:** Skill template para crear nuevos tests
- **Uso:** Boilerplate para tests de nuevas features
- **Viabilidad para UI Tests:** ⚠️ Genérico, no específico para macOS

---

## Recomendación Estratégica para Focally

### Opción 1: Mejorar XCUITest Existente (Recomendada 🎯)

**Estrategia:** Invertir en mejorar los helpers y patterns existentes en lugar de cambiar de framework.

**Acciones:**

1. **Crear `XCUITestHelpers.swift`**
   ```swift
   extension XCUIApplication {
       enum FocallyElement {
           static let statusItem = "FocallyMenuBarItem"
           static let popover = "FocallyPopover"
           static let startButton = "startPomodoroButton"
           static let stopButton = "stopPomodoroButton"
           static let pauseButton = "pauseButton"
           static let playButton = "playButton"
       }

       func openPopover() -> Bool {
           // Intentos múltiples con timeouts
           return (tapStatusItem() || waitForPopover())
       }

       private func tapStatusItem() -> Bool {
           let item = statusItems[FocallyElement.statusItem]
           if item.exists {
               item.click()
               return true
           }
           return false
       }

       private func waitForPopover() -> Bool {
           let popover = popovers[FocallyElement.popover]
           return popover.waitForExistence(timeout: 2)
       }
   }
   ```

2. **Tests Manuales en Xcode GUI**
   - Ejecutar tests manualmente con Cmd + U
   - Capturar screenshots en cada test
   - Documentar patrones que funcionan

3. **CI Parcial**
   - Ejecutar unit tests en CI (ya funcionan ✅)
   - UI tests: marcar como "manual-only" o ejecutar en máquina dedicada

**Pros:**
- ✅ Sin dependencias externas
- ✅ Mejora gradual del stack actual
- ✅ Compatible con CI existente
- ✅ Builds expertise en el equipo

**Cons:**
- ❌ Menu bar sigue siendo difícil
- ❌ Requiere tiempo de desarrollo

---

### Opción 2: Adoptar Swift Testing para Unit Tests (Recursos Complementarios)

**Estrategia:** Migrar unit tests a Swift Testing Framework (`@Test`, `#expect`).

**Acciones:**
- Migrar tests de `FocallyTests` de XCTest → Swift Testing
- Mantener XCUITest para UI tests (no hay alternativa nativa)
- Beneficio: sintaxis más moderna, mejor async support

**Viabilidad:** ✅ **Complementaria a Opción 1**

---

### Opción 3: Testing Manual + QA Proceso (Corto Plazo)

**Estrategia:** Aceptar limitaciones de XCUITest y complementar con testing manual estructurado.

**Acciones:**
- Crear checklist de testing manual para cada release
- Documentar test cases en Markdown
- Usar Xcode GUI para ejecutar UI tests antes de release
- Priorizar unit tests (ya 24/24 passing ✅)

**Viabilidad:** ✅ **Inmediata**

---

## Conclusión

### Para Focally: No hay silver bullet 🔮

Los frameworks alternativos (Appium, Maestro, Robot Framework) **no solucionan el problema de raíz**:
- Menu bar apps con SwiftUI son inherentemente difíciles de automatizar
- XCUITest sigue siendo la mejor herramienta nativa para macOS UI testing
- Las alternativas añaden complejidad sin garantizar mejor resultado

### Recomendación: **Opción 1 + Opción 3** 🎯

1. **Corto plazo (HOY):**
   - Testing manual estructurado con checklists
   - Ejecutar UI tests en Xcode GUI antes de releases
   - Confianza en unit tests (24/24 passing)

2. **Mediano plazo (2-4 semanas):**
   - Crear `XCUITestHelpers.swift` con patrones reutilizables
   - Expandir accessibility identifiers
   - Mejorar error messages y screenshots

3. **Largo plazo (2-3 meses):**
   - Evaluar Swift Testing Framework para unit tests
   - Considerar dedicar máquina con GUI para CI de UI tests

---

## Referencias

- [Swift Testing Documentation](https://developer.apple.com/documentation/Testing)
- [Migrating from XCTest](https://developer.apple.com/documentation/Testing/MigratingFromXCTest)
- [Testing SwiftUI Apps](https://developer.apple.com/documentation/xcode/testing-swiftui-apps)
- [Appium for Mac](https://appium.io/docs/en/latest/en/drivers/mac-uiautomation/)
- [Maestro Studio](https://maestro.dev/)
- [Robot Framework](https://robotframework.org/)

---

**Creado:** 2026-05-13
**Autor:** OpenJaime 🎩

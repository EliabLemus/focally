# SPEC: Fix SwiftLint Blocking Issues for Release

---

## Problema

El build de release está fallando en el paso de SwiftLint debido a 739 violaciones graves en múltiples archivos de servicio. Estas violaciones están impidiendo que el release v0.7.18 se complete exitosamente.

## Archivos Afectados (Según Log de Errores)

1. **Focally/Services/GoogleCalendarService.swift** - 4+ violaciones
   - Explicit Type Interface Violation (propiedades sin tipo explícito)
   - Force Unwrapping Violation
   - Function Body Length Violation (>50 líneas)
   - Line Length Violation (>120 caracteres)
   - Type Body Length Violation (>300 líneas)

2. **Focally/Services/NotificationService.swift** - Múltiples violaciones
   - File Size Limit Violation (>500 líneas)
   - Explicit Type Interface Violation
   - Line Length Violation

3. **Focally/Services/SoundPlayerService.swift** - Múltiples violaciones
   - File Size Limit Violation
   - Explicit Type Interface Violation
   - Line Length Violation
   - Identifier Name Violation (variable 'i' muy corta)
   - Function Body Length Violation

4. **Focally/Services/ShortcutDropHandler.swift** - Múltiples violaciones
   - File Size Limit Violation
   - Explicit Type Interface Violation
   - Line Length Violation

5. **Focally/Services/ScheduleService.swift** - Múltiples violaciones
   - File Size Limit Violation
   - Explicit Type Interface Violation
   - Force Unwrapping Violation (múltiples instancias)
   - Trailing Comma Violation
   - Line Length Violation

6. **Focally/Services/UTType+Shortcut.swift** - File Size Limit Violation

7. **Focally/Services/HistoryService.swift** - Múltiples violaciones
   - File Size Limit Violation
   - Explicit Type Interface Violation
   - Force Unwrapping Violation
   - Line Length Violation
   - Trailing Comma Violation

8. **Focally/Services/AnalyticsService.swift** - Múltiples violaciones
   - File Size Limit Violation
   - Explicit Type Interface Violation
   - Force Unwrapping Violation (múltiples instancias)
   - Line Length Violation
   - Trailing Comma Violation

9. **Focally/Services/DNDService.swift** - File Size Limit Violation

10. **Focally/Services/SlackService.swift** - Muchas violaciones
    - File Size Limit Violation
    - Explicit Type Interface Violation
    - Identifier Name Violation (variable 'ok' muy corta)
    - Line Length Violation
    - Function Body Length Violation
    - Type Body Length Violation (>500 líneas)
    - Void Function in Ternary Violation
    - Prefer For-Where Violation
    - File Length Violation (>500 líneas excluyendo comentarios)

## Solución Propuesta

### Enfoque General
Aplicar autocorrección de SwiftLint donde sea posible, luego hacer correcciones manuales para las violaciones que no se pueden autocorregir.

### Pasos Específicos por Tipo de Violación

#### 1. Explicit Type Interface Violation
- **Problema**: Propiedades y closures sin tipo explícito
- **Solución**: Agregar tipos explícitos a propiedades y parámetros de closure
- **Ejemplo**: 
  ```swift
  // Antes
  var service = SomeService()
  
  // Después
  var service: SomeService = SomeService()
  ```

#### 2. Force Unwrapping Violation
- **Problema**: Uso de `!` para desempaquetado forzado
- **Solución**: Reemplazar con binding opcional seguro (`if let`, `guard let`) o coalescing (`??`)
- **Ejemplo**:
  ```swift
  // Antes
  let value = optionalValue!
  
  // Después
  if let value = optionalValue {
      // usar value
  } else {
      // manejar caso nil
  }
  ```

#### 3. Line Length Violation
- **Problema**: Líneas >120 caracteres (warning) o >200 caracteres (error)
- **Solución**: Romper líneas en puntos lógicos (después de comas, operadores, etc.)
- **Ejemplo**:
  ```swift
  // Antes
  let veryLongString = "Esta es una cadena muy larga que excede el límite de caracteres permitido por SwiftLint y necesita ser dividida"
  
  // Después
  let veryLongString = "Esta es una cadena muy larga que excede el límite " +
      "de caracteres permitido por SwiftLint y necesita ser dividida"
  ```

#### 4. File Size Limit Violation
- **Problema**: Archivos >500 líneas
- **Solución**: Dividir archivos en múltiples archivos más pequeños siguiendo principios de responsabilidad única
- **Estrategia**:
  - Identificar clases/responsabilidades distintas dentro del archivo
  - Mover cada responsabilidad a su propio archivo
  - Mantener compatibilidad mediante extensiones o composición según corresponda

#### 5. Function Body Length Violation
- **Problema": Funciones >50 líneas (warning) o >100 líneas (error)
- **Solución**: Extraer lógica a funciones privadas helper
- **Ejemplo**:
  ```swift
  // Antes
  func processData() {
      // 80 líneas de lógica mezclada
  }
  
  // Después
  func processData() {
      let validatedData = validateInput(data)
      let processedData = transformData(validatedData)
      saveResults(processedData)
  }
  
  private func validateInput(_ data: Data) -> Data { /* ... */ }
  private func transformData(_ data: Data) -> Data { /* ... */ }
  private func saveResults(_ data: Data) { /* ... */ }
  ```

#### 6. Type Body Length Violation
- **Problema": Tipos >300 líneas (warning) o >500 líneas (error)
- **Solución**: Aplicar las mismas estrategias que para File Size Limit - dividir responsabilidades

#### 7. Identifier Name Violation
- **Problema": Nombres de variables muy cortos (<3 caracteres) o no descriptivos
- **Solución": Renombrar variables con nombres descriptivos y de longitud adecuada
- **Ejemplo**:
  ```swift
  // Antes
  var i = 0
  var ok = false
  
  // Después
  var index = 0
  var isProcessingComplete = false
  ```

#### 8. Trailing Comma Violation
- **Problema": Comas trailing en literales de colección
- **Solución": Eliminar comas trailing innecesarias
- **Ejemplo**:
  ```swift
  // Antes
  let items = [1, 2, 3,]
  
  // Después
  let items = [1, 2, 3]
  ```

#### 9. Prefer For-Where Violation
- **Problema": Uso de `if` dentro de `for` donde se podría usar `where`
- **Solución": Reemplazar `if` con cláusula `where` en el `for`
- **Ejemplo**:
  ```swift
  // Antes
  for item in items {
      if item.isValid {
          process(item)
      }
  }
  
  // Después
  for item in items where item.isValid {
      process(item)
  }
  ```

#### 10. File Length Violation
- **Problema": Archivos con >500 líneas excluyendo comentarios
- **Solución": Mismo enfoque que File Size Limit - dividir archivo

#### 11. Void Function in Ternary Violation
- **Problema": Uso de operador ternario para llamar funciones que retornan Void
- **Solución": Reemplazar con estructura `if-else` tradicional
- **Ejemplo**:
  ```swift
  // Antes
  condition ? doSomething() : doSomethingElse()
  
  // Después
  if condition {
      doSomething()
  } else {
      doSomethingElse()
  }
  ```

## Criterios de Aceptación

- [ ] SwiftLint pasa sin errores graves (severity: error)
- [ ] Advertencias (severity: warning) aceptables según configuración
- [ ] No se introduce nueva lógica de negocio (solo refactorización de código)
- [ ] Todos los tests unitarios existentes siguen pasando
- [ ] El build de release completa exitosamente

## Notas Técnicas

### Priorización
Enfocarse primero en los archivos que causan el fallo inmediato del build:
1. GoogleCalendarService.swift (bloquea build directamente)
2. NotificationService.swift
3. SoundPlayerService.php
4. SlackService.swift (muchas violaciones)

### Estrategia de División de Archivos
Para archivos que exceden límites de tamaño:
1. Identificar cohésión lógica dentro del archivo
2. Agrupar métodos relacionados por responsabilidad
3. Crear nuevos archivos para cada grupo de responsabilidad
4. Usar extensiones para mantener la interfaz pública cuando sea apropiado
5. Actualizar imports y referencias según sea necesario

### Mantenimiento de Compatibilidad
- Todos los cambios deben ser puramente de refactorización
- No cambiar firmas de métodos públicos sin necesidad
- Mantener la misma comportamiento externo
- Ejecutar tests después de cada cambio significativo

## Recursos de Referencia

- [LAYER_RULES.md](../docs/architecture/LAYER_RULES.md) - Reglas arquitectónicas de Focally
- [SWIFT_LINT_CONFIG](../.swiftlint.yml) - Configuración actual de SwiftLint
- [TESTING_GUIDE.md](../docs/implementation/TESTING_GUIDE.md) - Guía para testing
- [REFACTORING_GUIDE.md]() - Guía de buenas prácticas de refactorización (crear si no existe)
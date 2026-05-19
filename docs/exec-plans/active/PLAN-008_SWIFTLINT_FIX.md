# PLAN-008: Fix SwiftLint Blocking Issues for Release

## Estado
in_progress

## Objetivo
Resolver todas las violaciones graves de SwiftLint que están bloqueando el build de release para poder completar el release v0.7.18 exitosamente.

## Pasos

### Paso 1: Diagnóstico Inicial
1. [ ] Ejecutar SwiftLint para obtener lista completa de violaciones
2. [ ] Identificar los 10 archivos con más violaciones graves
3. [ ] Documentar tipos de violaciones por archivo

### Paso 2: Arreglar GoogleCalendarService.swift (Bloquea Build)
1. [ ] Agregar tipos explícitos a propiedades (Explicit Type Interface)
2. [ ] Reemplazar force unwrapping con binding seguro
3. [ ] Reducir longitud de funciones (>50 líneas warning, >100 error)
4. [ ] Corregir violaciones de longitud de línea
5. [ ] Reducir longitud de tipo si es necesario
6. [ ] Verificar que los cambios no rompen funcionalidad

### Paso 3: Arreglar NotificationService.swift
1. [ ] Dividir archivo si excede 500 líneas (File Size Limit)
2. [ ] Agregar tipos explícitos a propiedades
3. [ ] Corregir violaciones de longitud de línea
4. [ ] Verificar que los cambios no rompen funcionalidad

### Paso 4: Arreglar SoundPlayerService.swift
1. [ ] Dividir archivo si excede 500 líneas
2. [ ] Agregar tipos explícitos a propiedades
3. [ ] Renombrar variables con nombres muy cortos (ej: 'i')
4. [ ] Corregir violaciones de longitud de línea
5. [ ] Reducir longitud de funciones
6. [ ] Verificar que los cambios no rompen funcionalidad

### Paso 5: Arreglar ShortcutDropHandler.swift
1. [ ] Dividir archivo si excede 500 líneas
2. [ ] Agregar tipos explícitos a propiedades
3. [ ] Corregir violaciones de longitud de línea
4. [ ] Verificar que los cambios no rompen funcionalidad

### Paso 6: Arreglar ScheduleService.swift
1. [ ] Dividir archivo si excede 500 líneas
2. [ ] Agregar tipos explícitos a propiedades
3. [ ] Reemplazar force unwrapping con binding seguro
4. [ ] Eliminar comas trailing innecesarias
5. [ ] Corregir violaciones de longitud de línea
6. [ ] Verificar que los cambios no rompen funcionalidad

### Paso 7: Arreglar UTType+Shortcut.swift
1. [ ] Dividir archivo si excede 500 líneas
2. [ ] Verificar que los cambios no rompen funcionalidad

### Paso 8: Arreglar HistoryService.swift
1. [ ] Dividir archivo si excede 500 líneas
2. [ ] Agregar tipos explícitos a propiedades
3. [ ] Reemplazar force unwrapping con binding seguro
4. [ ] Eliminar comas trailing innecesarias
5. [ ] Corregir violaciones de longitud de línea
6. [ ] Verificar que los cambios no rompen funcionalidad

### Paso 9: Arreglar AnalyticsService.swift
1. [ ] Dividir archivo si excede 500 líneas
2. [ ] Agregar tipos explícitos a propiedades
3. [ ] Reemplazar force unwrapping con binding seguro
4. [ ] Corregir violaciones de longitud de línea
5. [ ] Eliminar comas trailing innecesarias
6. [ ] Verificar que los cambios no rompen funcionalidad

### Paso 10: Arreglar DNDService.swift
1. [ ] Dividir archivo si excede 500 líneas
2. [ ] Verificar que los cambios no rompen funcionalidad

### Paso 11: Arreglar SlackService.swift (Archivo más problemático)
1. [ ] Dividir archivo si excede 500 líneas
2. [ ] Agregar tipos explícitos a propiedades
3. [ ] Renombrar variables con nombres muy cortos (ej: 'ok')
4. [ ] Corregir violaciones de longitud de línea
5. [ ] Reducir longitud de funciones
6. [ ] Reducir longitud de tipo si es necesario
7. [ ] Reemplazar operador ternario que llama a funciones Void con if-else
8. [ ] Reemplazar `if` dentro de `for` con cláusula `where`
9. [ ] Corregir violaciones de longitud de archivo (excluyendo comentarios)
10. [ ] Verificar que los cambios no rompen funcionalidad

### Paso 12: Validación
1. [ ] Ejecutar SwiftLint y verificar que no hay errores graves (severity: error)
2. [ ] Ejecutar tests unitarios para asegurar que no se rompió funcionalidad
3. [ ] Ejecutar build de release completo
4. [ ] Verificar que el release se publique exitosamente

## Criterios de Aceptación

- [ ] SwiftLint pasa sin errores graves (severity: error)
- [ ] Advertencias (severity: warning) aceptables según configuración
- [ ] No se introduce nueva lógica de negocio (solo refactorización de código)
- [ ] Todos los tests unitarios existentes siguen pasando
- [ ] El build de release completa exitosamente
- [ ] Se publica el release v0.7.18 en GitHub

## Notas

- **Effort estimado**: 3-4 días
- **Prioridad**: P0 (bloquea release)
- **Referencia**: SWIFTLINT_FIX_BLOCKING_ISSUES.md

## Referencias

- [SWIFTLINT_FIX_BLOCKING_ISSUES.md](../product-specs/SWIFTLINT_FIX_BLOCKING_ISSUES.md) — Spec detallada
- [.swiftlint.yml] — Configuración de SwiftLint
- [LAYER_RULES.md](../docs/architecture/LAYER_RULES.md) — Reglas arquitectónicas
- [TESTING_GUIDE.md](../docs/implementation/TESTING_GUIDE.md) — Guía de testing
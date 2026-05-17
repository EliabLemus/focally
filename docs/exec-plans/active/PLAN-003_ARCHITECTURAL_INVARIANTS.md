# PLAN-003: Implementación de Invariantes Arquitectónicos (Lints)

## Estado
in_progress

## Objetivo
Implementar invariantes mecánicos (lints) para aplicar las reglas de arquitectura automáticamente.

## Pasos
1. [ ] Crear config custom de SwiftLint en `.swiftlint.yml`
2. [ ] Agregar regla para imports circulares
3. [ ] Agregar regla para file size limit (500 líneas)
4. [ ] Agregar regla para structured logging
5. [ ] Crear `FocallyTests/LayerTests.swift` para tests estructurales
6. [ ] Integrar lints en CI (GitHub Actions)
7. [ ] Verificar que lints no bloquean development legítimo

## Criterios de Aceptación
- [ ] `.swiftlint.yml` con reglas custom
- [ ] `LayerTests.swift` con tests de dependencia
- [ ] CI ejecuta SwiftLint en cada PR
- [ ] Lints detectan violaciones (imports circulares, file size, etc.)
- [ ] Lints NO bloquean desarrollo legítimo (warnings, no errors)

## Notas
Basado en `docs/architecture/LAYER_RULES.md`. Lints deben ser warnings, no errors, para no bloquear desarrollo.

## Fecha de Creación
2026-05-16
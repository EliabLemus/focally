# Focally Backlog Status

> **Última actualización**: 2026-07-07
> **Release actual**: v0.7.34
> **HEAD**: `15a33ec` (main)

## 1. Backlog Real (Pendiente)

### TASK-016: Migración a @Observable 🔴
- **Estado**: PENDIENTE
- **Scope**: 14 clases migrar de `ObservableObject` → `@Observable`
- **Estimación**: 2-3 días
- **Bloquea**: TASK-021
- **Prioridad**: P2 (tech debt fundacional)

### TASK-021: SettingsStore Centralizado 🔴
- **Estado**: PENDIENTE (bloqueado por TASK-016)
- **Scope**: Unificar settings dispersas en `@AppStorage`, `UserDefaults`, properties
- **Estimación**: 1-2 días
- **Depende de**: TASK-016
- **Prioridad**: P2

### Compliance Stitch / Liquid Glass ⚠️
- **Estado**: PARCIAL
- **Detalle**: `FocallyGlassModifier.swift` existe con 3 modifiers pero **0 vistas los usan**
- **Acción**: Migrar `.focallyCard()` → `.focallyGlassCard()` en ~13 vistas
- **Prioridad**: P3 (cosmético, evaluar si es relevante para macOS 26)

## 2. Tasks Completadas (en tasks/done/)

TASK-030, TASK-036, TASK-038 (×2 specs), TASK-039 (×2 specs), TASK-040 (×3 specs), TASK-041 (×2 specs), TASK-042, TASK-043, TASK-044.

> ⚠️ Los IDs TASK-038 a TASK-041 tenían specs duplicadas con nombres diferentes. Todas están resueltas.

## 3. Planes de Ejecución

### Activo
| Plan | Estado | Nota |
|------|--------|------|
| PLAN-003: Invariantes Arquitectónicos | Paused | Sin avance. Re-evaluar después de TASK-016 |

### Completados
| Plan | Nota |
|------|------|
| PLAN-007: Tests Flaky Fix | Completado |
| PLAN-008: SwiftLint Fix | Completado (sustituido por refactorización incremental) |
| fix-emoji-shortcode-mapping | Completado (commit `1a40c9e`) |

## 4. Branches

Solo `main`. Stale branches eliminadas:
- `feature/fase2-refactorizacion` — eliminada
- `feature/tests-flaky-fix` — eliminada

## 5. Notas

- `README.md` puede estar desactualizado (mostraba versión antigua)
- `docs/AUDIT_REPORT_TASKS.md` contiene el reporte detallado de la auditoría de código (Jul 2026)

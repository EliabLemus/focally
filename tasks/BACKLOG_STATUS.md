# Focally Backlog Status

> **Última actualización**: 2026-07-08
> **Release actual**: v0.7.35
> **HEAD**: `7ff332d` (main)

## 1. Backlog Real (Pendiente)

### TASK-016: Migración a @Observable ✅
- **Estado**: DONE (2026-07-07)
- **Branch**: `feature/task-016-observable-migration`
- **Detalle**: 14 clases migradas, 39 @EnvironmentObject → @Environment, build OK

### TASK-021: SettingsStore Centralizado ✅
- **Estado**: DONE (2026-07-08)
- **Detalle**: SettingsStore @Observable creado, FocusTimerService y SoundPlayerService migrados, cero @AppStorage restante, build OK

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

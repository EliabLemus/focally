# Focally Backlog Status

> **Última actualización**: 2026-11-01
> **Release actual**: v0.10.0 (`MARKETING_VERSION` en project.yml)
> **HEAD**: `1e4589f` (main)

## 1. Backlog Real (Pendiente)

### SlackService.swift — refactor pendiente
- **Estado**: PENDIENTE
- **Detalle**: 3 371 líneas en un solo archivo; candidato a dividir por responsabilidad (cliente API, modelos, UI helpers)
- **Prioridad**: P2

### Migrar logging a OSLog
- **Estado**: PENDIENTE (TODOs en código)
- **Detalle**: TODOs existentes de migración a OSLog para unificar el logging nativo
- **Prioridad**: P2

### project.yml — xcodeVersion fija
- **Estado**: PENDIENTE
- **Detalle**: `project.yml` fija `xcodeVersion: 15.0`; amarra el toolchain y rompe en Xcode nuevos
- **Prioridad**: P2

### Compliance Stitch / Liquid Glass ⚠️
- **Estado**: PARCIAL
- **Detalle**: `FocallyGlassModifier.swift` existe con modifiers pero **0 vistas los usan**
- **Acción**: Migrar `.focallyCard()` → `.focallyGlassCard()` en ~13 vistas
- **Prioridad**: P3 (cosmético, evaluar si es relevante para macOS 26)

## 2. Tasks Completadas (en tasks/done/)

TASK-030, TASK-036, TASK-038 (×2 specs), TASK-039 (×2 specs), TASK-040 (×3 specs), TASK-041 (×2 specs), TASK-042, TASK-043, TASK-044.

> ⚠️ Los IDs TASK-038 a TASK-041 tenían specs duplicadas con nombres diferentes. Todas están resueltas.

## 3. Planes de Ejecución

### Activo
| Plan | Estado | Nota |
|------|--------|------|
| PLAN-003: Invariantes Arquitectónicos | Paused | Sin avance. Re-evaluar |

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

- Métricas: `FocusMetricsService` persiste en UserDefaults con cap de 5 000 registros (`maxRecords`); revisado 2026-11-01, el cap se aplica en ambos paths de escritura (`recordSession`/`upsertSession`).
- `docs/AUDIT_REPORT_TASKS.md` contiene el reporte detallado de la auditoría de código (Jul 2026).

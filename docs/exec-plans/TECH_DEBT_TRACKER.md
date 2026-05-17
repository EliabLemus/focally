# TECH_DEBT_TRACKER.md — Tracker de Deuda Técnica

> Registro de deuda técnica pendiente. Prioriza por impacto y effort.

---

## Prioridades

| Prioridad | Descripción | SLA |
|-----------|-------------|-----|
| P0 | Crítico, bloquea releases | 1 semana |
| P1 | Alto, afecta UX significativamente | 2 semanas |
| P2 | Medio, mejora técnico sin impacto usuario | 1 mes |
| P3 | Bajo, nice to have | Futuro |

---

## Deuda Técnica Activa

### P0: Ninguna
🎉 No hay deuda técnica crítica pendiente.

### P1

| ID | Problema | Impacto | Effort | Asignado |
|----|----------|---------|--------|----------|
| TD-001 | Tests flaky en FocallyUITests | Bloquea CI frecuentemente | 2d | Unassigned |
| TD-003 | Agregar structured logging completo | Mejora debuggability | 2d | Unassigned |

### P1

| ID | Problema | Impacto | Effort | Asignado |
|----|----------|---------|--------|----------|
| TD-001 | Tests flaky en FocallyUITests | Bloquea CI frecuentemente | 2d | Unassigned |

### P2

| ID | Problema | Impacto | Effort | Asignado |
|----|----------|---------|--------|----------|
| TD-002 | Migrar tests a Swift Testing | Mejora maintainability | 3d | Unassigned |
| TD-004 | Implementar App Groups para sync multi-dispositivo | Feature futura | 5d | Unassigned |

### P3

| ID | Problema | Impacto | Effort | Asignado |
|----|----------|---------|--------|----------|
| TD-005 | Migrar a Swift 6 Strict Concurrency | Future-proof | 7d | Unassigned |

---

## Deuda Técnica Completada

| ID | Problema | Resuelto En |
|----|----------|-------------|
| TD-000 | Setup inicial de CI/CD | 2026-04-17 |

---

## Proceso

1. **Agregar deuda**: Crear ID nuevo, asignar prioridad, estimar effort
2. **Planear trabajo**: Crear plan en `docs/exec-plans/active/`
3. **Marcar completado**: Mover a esta sección, actualizar ID y fecha

---

## Referencias

- [EXECUTION_PLANS](../exec-plans/INDEX.md) — Planes para resolver deuda técnica
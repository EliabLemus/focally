# PLAN-004: Observabilidad (Logs Estructurados + Métricas)

## Estado
✅ completed

## Objetivo
Implementar observabilidad query-able por agentes (logs estructurados + métricas).

## Pasos
1. [x] Crear `Focally/Observability/Logger.swift` (wrapper de os.log)
2. [x] Crear `Focally/Observability/Metrics.swift` (wrapper de os.signpost)
3. [x] Integrar Logger en Services (reemplazar print() con logger)
4. [x] Integrar Metrics en Services (track eventos clave)
5. [x] Crear script para query logs (LogQL-style)
6. [x] Crear script para query métricas (PromQL-style)
7. [x] Exponer logs/métricas a DevTools Protocol

## Criterios de Aceptación
- [x] Logger.swift con niveles (debug, info, warning, error)
- [x] Metrics.swift con counters, gauges, histograms
- [x] Services usan Logger en lugar de print()
- [x] Services track métricas clave (eventos sync, timer sessions, etc.)
- [x] Scripts query logs y métricas funcionan
- [x] Logs/métricas expuestos via DevTools Protocol

## Notas
Basado en enfoque de OpenAI: "logs/métricas query-ables por Codex". Usar os.log nativo de macOS.

## Archivos Creados
- `Focally/Observability/Logger.swift` — Logger wrapper
- `Focally/Observability/Metrics.swift` — Metrics wrapper
- `scripts/query-logs.sh` — Script para query logs
- `scripts/query-metrics.sh` — Script para query métricas
- `scripts/devtools-bridge.sh` — Script para DevTools Protocol
- `docs/implementation/OBSERVABILITY_INTEGRATION_EXAMPLE.md` — Ejemplo de integración

## Fecha de Creación
2026-05-16

## Fecha de Completado
2026-05-16
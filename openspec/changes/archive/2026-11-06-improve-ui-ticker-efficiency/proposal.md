# Proposal: improve-ui-ticker-efficiency

## Intent

El ticker de UI (`OnItFocusApp.swift:567`) corre `Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true)` sin `tolerance`, con wakeups exactos cada segundo en un app menu-bar que vive 100% del tiempo. Además actualiza el título del status item en cada tick aunque el string no cambie. Impacto directo en batería y micro-trabajo de AppKit innecesario.

## What Changes

- El ticker gana `tolerance = 0.1` (leeway del sistema) y anclaje del primer fire al siguiente segundo de pared.
- El valor mostrado se deriva de `Date` (reconciliación por reloj — ya existe el patrón en `FocusTimerService`), no por conteo de ticks; tras sleep el título se corrige solo en el primer tick.
- El título del status item SOLO se asigna cuando el string formateado cambia.

**BREAKING: ninguno.**

## Capabilities

- **Nueva:** `ui-ticker-efficiency`

## Impact

- `Sources/Focally/OnItFocusApp.swift` (~567) y/o `Sources/Focally/Services/FocusTimerTicker.swift` (consolidar si hay doble ticker — verificar en implementación)
- Tests: 1 test de reconciliación por reloj (fecha derivada, no ticks)

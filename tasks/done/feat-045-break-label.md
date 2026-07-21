# FEAT-045: Break label personalizable en FocusMode

## Problema
Durante el break, la barra muestra el nombre del focus mode (ej "Focus Time") sin indicar que es un descanso. El usuario no sabe si está en focus o en break.

## Solución
1. Agregar campo `breakLabel: String?` a FocusMode (optional, default nil)
2. En FocusModeEditSheet: agregar campo de texto "Break label" (placeholder: "e.g. Coffee time ☕")
3. En FocusTimerService: durante break, `currentActivity` = `breakLabel ?? "{modeName} — Break"`
4. `phaseName` ya retorna "Break"/"Long Break" — mantener para la card del popover

## Archivos
- `Focally/Models/FocusMode.swift` — campo `breakLabel`, sanitized, CodingKeys
- `Focally/Views/Timer/FocusModeEditSheet.swift` — campo UI
- `Focally/Services/FocusTimerService.swift` — usar breakLabel en currentActivity durante break

## Criterios
- Si breakLabel está set: barra muestra `🧠 ⏸ 5 — Coffee time ☕`
- Si no está set: barra muestra `🧠 ⏸ 5 — Focus Time — Break`
- Backward compatible: nil por defecto
- Se persiste con los modos (feat-044)
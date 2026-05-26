# Fix #1: Simplificar estado de pausa - "Paused · Notifications are back"

**Severity:** Critical
**Framework:** Auto-evidencia (Primera Norma) + Omisión de palabras
**Ticket:** UX-KRUG-001

## Problem

El estado "Paused · Notifications are back" en `MenuBarDropdownView.swift:99` mezcla dos conceptos:
- Estado del timer (Paused)
- Estado de notificaciones (Notifications are back)

Esto viola:
- **Auto-evidencia:** Usuario debe procesar mentalmente dos estados
- **Omisión de palabras:** "are back" es bla-bla-bla
- **Jerarquía visual:** Estado secundario (notificaciones) compite con estado principal (timer)

## Current Implementation

```swift
// MenuBarDropdownView.swift:99
Text(timerService.isPaused ? "Paused · Notifications are back" : (timerService.isBreak ? "Break" : "Deep Focus Mode"))
```

## Proposed Fix

Simplificar a estados directos, sin mezclar conceptos:

```swift
// Fix #1: Más directo (RECOMMENDED)
Text(timerService.isPaused ? "Paused" : (timerService.isBreak ? "Break" : "Deep Focus"))

// Fix #2: Si necesitas incluir estado de notificaciones, hacerlo en otra parte
// No mezclar con estado del timer
```

**Nota:** El estado de notificaciones ya aparece en el `footerStats` (línea 203). No es necesario repetirlo en el `activeSessionCard`.

## Impact

- **UI:** Texto más corto, más fácil de escanear a 100 km/h
- **UX:** Usuario entiende inmediatamente el estado sin pensar
- **Krug Compliance:** ✅ Auto-evidente + ✅ Omisión de palabras

## Testing

1. Build and run Focally
2. Start a focus session
3. Pause the session
4. Verify the text shows "Paused" only
5. Resume and verify it shows "Deep Focus" (or "Break" if on break)
6. Verify footer still shows notification status separately

## Edge Cases

- What if timer is paused but DND is inactive? → Still shows "Paused"
- What if timer is paused and DND is active? → Still shows "Paused" (notification status in footer)
- Break state? → Shows "Break" (unchanged)

## Dependencies

None - self-contained fix

## Acceptance Criteria

- [ ] Text shows "Paused" when timer is paused (not "Paused · Notifications are back")
- [ ] Text shows "Deep Focus" when timer is active and in work mode
- [ ] Text shows "Break" when timer is active and in break mode
- [ ] No visual regression in spacing/layout
- [ ] Footer notification status remains functional

## Related Files

- `Focally/Views/MenuBar/MenuBarDropdownView.swift` (line 99)
- Related: Issue #4 (redundancy in footer)
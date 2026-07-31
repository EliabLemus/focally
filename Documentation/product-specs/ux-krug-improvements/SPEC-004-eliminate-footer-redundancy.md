# Fix #4: Eliminar redundancia de estado de notificaciones en footer

**Severity:** High
**Framework:** Omisión de palabras + Minimizar ruido
**Ticket:** UX-KRUG-004

## Problem

El estado de notificaciones se repite entre:
1. `activeSessionCard` (línea 99) - "Paused · Notifications are back"
2. `footerStats` (línea 203) - "Paused · notifications live"

Esto viola:
- **Omisión de palabras:** Información duplicada
- **Minimizar ruido:** Redundancia visual
- **Ginger Effect:** Usuario solo "escucha" una vez, la otra vez es ruido

## Current Implementation

```swift
// MenuBarDropdownView.swift:99 (in activeSessionCard)
Text(timerService.isPaused ? "Paused · Notifications are back" : (timerService.isBreak ? "Break" : "Deep Focus Mode"))

// MenuBarDropdownView.swift:203 (in footerStats)
Text(timerService.isPaused ? "Paused · notifications live" : (dndService.isDNDActive ? "Quiet mode on" : "Quiet mode ready"))
```

**Issue:** Cuando está pausado, el footer repite el estado de notificaciones que ya está (o debería estar) implícito.

## Proposed Fix

Simplificar footer a SOLO estado de DND (no estado de pausa):

```swift
// MenuBarDropdownView.swift:203
// ❌ Actual (redundante)
Text(timerService.isPaused ? "Paused · notifications live" : (dndService.isDNDActive ? "Quiet mode on" : "Quiet mode ready"))

// ✅ Fix #1: Solo estado de DND
Text(dndService.isDNDActive ? "Quiet mode on" : "Quiet mode ready")

// ✅ Fix #2: Más directo (RECOMMENDED)
Text(dndService.isDNDActive ? "DND Active" : "DND Off")
```

**Recommendation:** Fix #2 - "DND Active" / "DND Off" is shorter, more auto-evident.

## Why This Works

- Footer agregado ("Today: X") debería mostrar estados agregados
- Estado del timer (Paused/Running) ya está en `activeSessionCard`
- Estado de notificaciones es implícito del timer state
- DND es el único estado que necesita ser agregado

## Impact

- **UI:** Menos redundancia, más claro
- **UX:** Usuario ve cada información en su lugar natural
- **Krug Compliance:** ✅ Omisión de palabras + ✅ Minimizar ruido + ✅ Zonas definidas

## Testing

1. Build and run Focally
2. Test all combinations:
   a. Timer running, DND off → Footer shows "DND Off"
   b. Timer running, DND on → Footer shows "DND Active"
   c. Timer paused, DND off → Footer shows "DND Off"
   d. Timer paused, DND on → Footer shows "DND Active"
3. Verify:
   - Timer state is shown in activeSessionCard (not duplicated in footer)
   - DND state is shown in footer only
   - No visual regression
4. Test in both light and dark modes

## Edge Cases

- What if timer is paused but user manually toggled DND? → Footer still shows correct DND state (independent)
- What if DND is active but timer is idle? → Footer still shows "DND Active" (DND is independent)

## Dependencies

- Related to Fix #1 (simplifying paused state) - Fix #4 depends on Fix #1 being done first

## Acceptance Criteria

- [ ] Footer does NOT show "Paused · notifications live"
- [ ] Footer shows "DND Active" when DND is active (regardless of timer state)
- [ ] Footer shows "DND Off" when DND is inactive (regardless of timer state)
- [ ] Timer state (Paused/Running/Break) is shown ONLY in activeSessionCard
- [ ] No duplicate information
- [ ] Icon moon changes color based on DND state (purple when active, variant when off)
- [ ] No layout shift
- [ ] Works in both light and dark modes

## Related Files

- `Focally/Views/MenuBar/MenuBarDropdownView.swift` (line 203)
- Related: SPEC-001-simplify-paused-state.md
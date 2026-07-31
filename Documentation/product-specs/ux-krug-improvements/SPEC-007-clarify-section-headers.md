# Fix #7: Clarificar section headers - "Quick Start" vs "Predefined tasks"

**Severity:** Medium
**Framework:** Auto-evidencia + Convenciones
**Ticket:** UX-KRUG-007

## Problem

Hay dos sections cuando no hay sesión activa:
1. "Quick Start" (quickStartSection)
2. "Predefined tasks" (presetsSection)

Issues:
- ¿Cuál usar? No es auto-evidente
- ¿Son mutuamente excluyentes? No está claro
- "Quick Start" es ambiguo (start quickly? quick sessions?)
- "Predefined tasks" es técnico (no action-oriented)

## Current Implementation

```swift
// MenuBarDropdownView.swift:18-22
VStack(spacing: 14) {
    if timerService.hasSession {
        activeSessionCard
    } else {
        quickStartSection
        presetsSection
    }
}
```

Section header from `presetsSection` (line 65):
```swift
Text("Predefined tasks")
    .font(.focallyBodyBold)
    .foregroundStyle(Color.focallyOnSurface)
```

## Proposed Fix

Opción A - Renombrar para claridad (RECOMMENDED):
```swift
// quickStartSection → "Quick Sessions" (ya existe en código)
Text("Quick Sessions")

// presetsSection → "Your Presets" o "Saved Presets"
Text("Your Presets")
```

Opción B - Unificar sections (SIMPLEST):
```swift
// Combina en una sola section "Start Focus"
VStack(spacing: 14) {
    StartFocusSection()  // Incluye quick sessions + presets
}
```

Opción C - Mejor etiqueta contextual (INFORMATIVE):
```swift
// "Quick Sessions" → "Quick Start" (ya está, está bien)
// "Predefined tasks" → "Saved Tasks"
Text("Saved Tasks")
```

**Recommendation:** Option A - Simple renaming.

## Why This Works

- "Your Presets" indica ownership + action
- "Quick Sessions" indica quick, predefined sessions
- Más convencional que "Predefined tasks"
- Krug: "Usa nombres convencionales que los usuarios ya conocen"

## Impact

- **UI:** Nombres más claros y auto-evidentes
- **UX:** Usuario entiende qué hace cada section
- **Krug Compliance:** ✅ Auto-evidencia + ✅ Convenciones

## Testing

### Option A:
1. Build and run Focally
2. Verify section header shows "Your Presets" (not "Predefined tasks")
3. Verify "Quick Sessions" section is visible
4. Verify both sections show when no session is active
5. Verify both sections hide when session starts
6. Verify headers use correct styling (`.focallyBodyBold`, `.focallyOnSurface`)

## Edge Cases

- Long preset names causing layout issues? → Already handled with `.lineLimit(1)`
- What if user has no presets? → Empty state already handled

## Dependencies

None - self-contained fix

## Acceptance Criteria

- [ ] Preset section header shows "Your Presets" (not "Predefined tasks")
- [ ] "Quick Sessions" section header remains unchanged
- [ ] Both sections show when timer is idle
- [ ] Both sections hide when timer is active
- [ ] Headers use `.focallyBodyBold` font
- [ ] Headers use `.focallyOnSurface` color
- [ ] No layout shift
- [ ] Works in both light and dark modes

## Related Files

- `Focally/Views/MenuBar/MenuBarDropdownView.swift` (line 65 for presetsSection header)
- Related: QuickSessionsSection.swift (for Quick Sessions header)
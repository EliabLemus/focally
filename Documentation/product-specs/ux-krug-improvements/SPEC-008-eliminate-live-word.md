# Fix #8: Eliminar "live" en "Notifications live"

**Severity:** Low
**Framework:** Omisión de palabras
**Ticket:** UX-KRUG-008

## Problem

Line 108 shows: "Notifications live"

Issue:
- "live" es innecesario - si no están muted, están live
- Usuario infiere estado, no necesitas texto

## Current Implementation

```swift
// MenuBarDropdownView.swift:103-114
if timerService.isPaused {
    HStack(spacing: 4) {
        Circle()
            .fill(Color.focallySecondary)
            .frame(width: 6, height: 6)
        Text("Notifications live")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.focallySecondary)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 2)
    .background(Capsule().fill(Color.focallySecondary.opacity(0.12)))
}
```

## Proposed Fix

Opción A - Eliminar texto completamente (VISUAL ONLY):
```swift
if timerService.isPaused {
    HStack(spacing: 4) {
        Circle()
            .fill(Color.focallySecondary)
            .frame(width: 6, height: 6)
        // Remove text - color/position indicates state
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 2)
    .background(Capsule().fill(Color.focallySecondary.opacity(0.12)))
}
```

Opción B - Texto más directo (SIMPLER):
```swift
Text("On")
    .font(.system(size: 10, weight: .semibold))
    .foregroundStyle(Color.focallySecondary)
```

Opción C - Icono + texto (CONVENTIONAL):
```swift
HStack(spacing: 4) {
    Image(systemName: "bell.fill")
        .font(.system(size: 10))
    Circle()
        .fill(Color.focallySecondary)
        .frame(width: 6, height: 6)
}
```

**Recommendation:** Option A (most minimal - color + position indicate state).

## Why This Works

- Krug: "El usuario es más inteligente de lo que creemos"
- Si hay un indicador de notificaciones, usuario entiende que están on
- "live" es redundante con el indicador visual
- Más espacio para información importante

## Impact

- **UI:** Más minimal, menos texto
- **UX:** Estado igual de claro visualmente
- **Krug Compliance:** ✅ Omisión de palabras + ✅ Minimizar ruido

## Testing

### Option A:
1. Build and run Focally
2. Start a session
3. Pause the session
4. Verify badge shows circle indicator only (no text "Notifications live")
5. Verify color is `.focallySecondary` (secondary color)
6. Verify background is `Capsule().fill(Color.focallySecondary.opacity(0.12))`
7. Verify no layout shift

## Edge Cases

- User doesn't understand what the badge means? → Color + position indicates status (secondary = paused, notifications back)
- What if badge needs text for accessibility? → Add `.accessibilityLabel("Notifications on")` for screen readers

## Dependencies

- Related to Fix #1 (simplifying paused state) - This badge disappears if Fix #1 removes the paused state indicator

**NOTE:** If Fix #1 removes the paused state indicator entirely, this fix becomes redundant. Implement together.

## Acceptance Criteria

### Option A:
- [ ] Badge shows circle indicator only (no text "Notifications live")
- [ ] Circle uses `.focallySecondary` color
- [ ] Background uses `Capsule().fill(Color.focallySecondary.opacity(0.12))`
- [ ] Padding remains: `.padding(.horizontal, 8)`, `.padding(.vertical, 2)`
- [ ] No layout shift
- [ ] Optional: Has `.accessibilityLabel("Notifications on")` for screen readers
- [ ] Works in both light and dark modes

## Related Files

- `Focally/Views/MenuBar/MenuBarDropdownView.swift` (lines 103-114)
- Related: SPEC-001-simplify-paused-state.md
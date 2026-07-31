# Fix #5: Simplificar "Quiet mode on" vs "Quiet mode ready"

**Severity:** High
**Framework:** Auto-evidencia + Omisión de palabras
**Ticket:** UX-KRUG-005

## Problem

El footer muestra: "Quiet mode on" vs "Quiet mode ready"

Issues:
- "Quiet mode ready" es estado de preparación, no acción
- "Quiet mode on" es un estado, no una acción
- Ambos mezclados en un solo elemento con icono moon confunden
- Usuario no entiende qué puede hacer con esta información

## Current Implementation

```swift
// MenuBarDropdownView.swift:203
Text(dndService.isDNDActive ? "Quiet mode on" : "Quiet mode ready")
```

## Proposed Fix

Opción A - Estados más directos (RECOMMENDED):
```swift
Text(dndService.isDNDActive ? "DND Active" : "DND Off")
```

Opción B - Solo estados activos (MOST MINIMAL):
```swift
// Solo mostrar algo cuando DND está activo
if dndService.isDNDActive {
    Text("DND Active")
}
// Si está off, no mostrar texto (icono indica estado)
```

Opción C - Solo icono y color (VISUAL ONLY):
```swift
// Quitar texto completamente, solo usar icono + color
Image(systemName: dndService.isDNDActive ? "moon.fill" : "moon")
    .font(.system(size: 12))
    .foregroundStyle(dndService.isDNDActive ? Color.focallyPrimary : Color.focallyOnSurfaceVariant)
// No necesitas texto si el estado está claro visualmente
```

**Recommendation:** Start with Option A. If we want even more minimal, upgrade to Option C.

## Why This Works

- "DND Active" / "DND Off" es más directo y auto-evidente
- "Quiet mode ready" no comunica valor (ready for what?)
- Icono月亮 ya indica el contexto (DND/quiet mode)
- Krug: "El usuario es más inteligente de lo que creemos" - entiende "DND" sin explicación

## Impact

- **UI:** Texto más corto, más fácil de escanear
- **UX:** Usuario entiende estado inmediatamente
- **Krug Compliance:** ✅ Auto-evidencia + ✅ Omisión de palabras + ✅ Minimizar ruido

## Testing

### Option A:
1. Build and run Focally
2. Toggle DND on and off
3. Verify footer shows "DND Active" when on
4. Verify footer shows "DND Off" when off
5. Verify moon icon color changes appropriately

### Option C (if implemented):
6. Verify no text is shown when DND is off
7. Verify moon icon color still indicates state (purple = on, variant = off)
8. Verify no layout shift (text hides but HStack maintains alignment)

## Edge Cases

- User doesn't know what DND is? → "DND" is standard macOS terminology, user will understand
- Long session name causing layout issues? → Not applicable - footer has fixed layout

## Dependencies

- Related to Fix #4 (eliminating footer redundancy) - Implement together

## Acceptance Criteria

### Option A:
- [ ] Footer shows "DND Active" when DND is active
- [ ] Footer shows "DND Off" when DND is inactive
- [ ] Moon icon color changes (purple when active, variant when off)
- [ ] Text uses `.focallyCaption` font
- [ ] Text uses appropriate color (primary when active, variant when off)
- [ ] No layout shift
- [ ] Works in both light and dark modes

### Option C (if implemented):
- [ ] Above criteria met
- [ ] No text shown when DND is off (just icon + color)
- [ ] "DND Active" shown when DND is on
- [ ] No layout shift when text appears/disappears (HStack maintains alignment)

## Related Files

- `Focally/Views/MenuBar/MenuBarDropdownView.swift` (line 203)
- Related: SPEC-004-eliminate-footer-redundancy.md
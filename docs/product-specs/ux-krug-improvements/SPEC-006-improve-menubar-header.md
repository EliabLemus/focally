# Fix #6: Mejorar header de menubar - "Start fast, stay quiet."

**Severity:** Medium
**Framework:** Auto-evidencia + Convenciones
**Ticket:** UX-KRUG-006

## Problem

El header muestra: "Focus" + "Start fast, stay quiet."

Issues:
- "Start fast, stay quiet." no es auto-evidente
- ¿Es un slogan? Instrucción? Descripción de funcionalidad?
- Rompe convenciones de headers de menubar que suelen ser más funcionales

## Current Implementation

```swift
// MenuBarDropdownView.swift:42-56
private var headerRow: some View {
    HStack {
        VStack(alignment: .leading, spacing: 2) {
            Text("Focus")
                .font(.focallyH2)
                .foregroundStyle(Color.focallyOnSurface)
            Text("Start fast, stay quiet.")
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyOnSurfaceVariant)
        }

        Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.top, 12)
    .padding(.bottom, 8)
}
```

## Proposed Fix

Opción A - Solo nombre (CONVENCIONAL):
```swift
VStack(alignment: .leading, spacing: 2) {
    Text("Focus")
        .font(.focallyH2)
        .foregroundStyle(Color.focallyOnSurface)
    // Remove subtitle entirely
}
```

Opción B - Descripción funcional (INFORMATIVA):
```swift
VStack(alignment: .leading, spacing: 2) {
    Text("Focus")
        .font(.focallyH2)
        .foregroundStyle(Color.focallyOnSurface)
    Text(timerService.hasSession ? "Session Active" : "Start Timer")
        .font(.focallyCaption)
        .foregroundStyle(Color.focallyOnSurfaceVariant)
}
```

Opción C - Atributos (CONTEXTUAL):
```swift
VStack(alignment: .leading, spacing: 2) {
    Text("Focus")
        .font(.focallyH2)
        .foregroundStyle(Color.focallyOnSurface)
    if timerService.hasSession {
        Text(timerService.currentActivity)
            .font(.focallyCaption)
            .foregroundStyle(Color.focallyOnSurfaceVariant)
    }
}
```

**Recommendation:** Option A (simplest) or Option B (most functional).

## Why This Works

- Krug: "Los usuarios no recuerdan tu sitio, recuerdan cómo funciona el Web en general"
- Headers funcionales son más útiles que slogans clever
- "Start fast, stay quiet." no comunica valor o acción
- Más espacio para el contenido real (timer, stats)

## Impact

- **UI:** Más espacio para contenido, menos distracción
- **UX:** Header más auto-evidente y funcional
- **Krug Compliance:** ✅ Auto-evidencia + ✅ Convenciones + ✅ Minimizar ruido

## Testing

### Option A:
1. Build and run Focally
2. Verify header shows only "Focus" (no subtitle)
3. Verify layout is correct (no excessive whitespace)
4. Verify works in both light and dark modes

### Option B:
5. Start a session → Verify subtitle shows "Session Active"
6. End session → Verify subtitle shows "Start Timer"
7. Verify subtitle updates dynamically
8. Verify layout doesn't shift (fixed height)

### Option C:
9. Start "Deep Work" → Verify subtitle shows "Deep Work"
10. Pause → Verify subtitle shows "Deep Work" (activity name, not state)
11. End session → Verify subtitle disappears (only "Focus")
12. Verify layout doesn't shift (conditional rendering)

## Edge Cases

- Very long activity name causing overflow? → Should use `.lineLimit(1)` if implementing Option C
- What if header becomes too empty? → Option B/C adds back minimal text

## Dependencies

None - self-contained fix

## Acceptance Criteria

### Option A:
- [ ] Header shows only "Focus" (no subtitle "Start fast, stay quiet.")
- [ ] "Focus" uses `.focallyH2` font
- [ ] "Focus" uses `.focallyOnSurface` color
- [ ] No excessive whitespace in header
- [ ] Layout is centered vertically
- [ ] Works in both light and dark modes

### Option B:
- [ ] Above criteria met
- [ ] Subtitle shows "Session Active" when timer is active
- [ ] Subtitle shows "Start Timer" when timer is idle
- [ ] Subtitle uses `.focallyCaption` font
- [ ] Subtitle uses `.focallyOnSurfaceVariant` color
- [ ] Subtitle updates dynamically
- [ ] No layout shift

### Option C (if implemented):
- [ ] Option A criteria met
- [ ] Subtitle shows activity name when timer is active
- [ ] Subtitle disappears when timer is idle
- [ ] Subtitle uses `.lineLimit(1)` to prevent overflow
- [ ] No layout shift when subtitle appears/disappears

## Related Files

- `Focally/Views/MenuBar/MenuBarDropdownView.swift` (lines 42-56)
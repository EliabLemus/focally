# Fix #3: Eliminar texto innecesario en empty state - "Create presets from Task Configuration."

**Severity:** High
**Framework:** Omisión de palabras (Tercera Norma - Test de Bla-Bla)
**Ticket:** UX-KRUG-003

## Problem

El empty state cuando no hay predefined tasks muestra: "Create presets from Task Configuration."

Esto viola:
- **Test de Bla-Bla:** Este es bla-bla-bla del peor tipo
- **Omisión de palabras:** "from Task Configuration" es interno y no necesario
- **Ojear no leer:** Usuarios no leen bienvenida - van directo al contenido

## Current Implementation

```swift
// MenuBarDropdownView.swift:74-77
if predefinedTaskStore.tasks.isEmpty {
    Text("Create presets from Task Configuration.")
        .font(.focallyCaption)
        .foregroundStyle(Color.focallyOnSurfaceVariant)
}
```

## Proposed Fix

Opción A - Texto directo (RECOMMENDED):
```swift
if predefinedTaskStore.tasks.isEmpty {
    Text("Create presets")
        .font(.focallyCaption)
        .foregroundStyle(Color.focallyOnSurfaceVariant)
}
```

Opción B - Icono + texto (ALTERNATIVE):
```swift
if predefinedTaskStore.tasks.isEmpty {
    HStack(spacing: 6) {
        Image(systemName: "plus.circle.fill")
            .font(.system(size: 12))
        Text("Create presets")
            .font(.focallyCaption)
            .foregroundStyle(Color.focallyOnSurfaceVariant)
    }
}
```

Opción C - Make it clickable (BEST UX):
```swift
if predefinedTaskStore.tasks.isEmpty {
    Button(action: openTaskConfiguration) {
        HStack(spacing: 6) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 12))
            Text("Create presets")
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyOnSurfaceVariant)
        }
    }
    .buttonStyle(.plain)
}
```

**Recommendation:** Start with Option A (simplest). If we have time/need, upgrade to Option C.

## Impact

- **UI:** Texto más corto, menos ruido visual
- **UX:** Usuario entiende acción sin leer bla-bla-bla
- **Krug Compliance:** ✅ Omisión de palabras + ✅ Diseño para escaneo
- **Actionability:** Option C makes it directly actionable

## Testing

### Option A:
1. Build and run Focally
2. Clear all predefined tasks
3. Verify empty state shows "Create presets" (not "Create presets from Task Configuration.")
4. Verify text is properly aligned and styled

### Option C (if implemented):
5. Click the "Create presets" button
6. Verify it opens Task Configuration
7. Verify hover state (if added)
8. Verify no console errors

## Edge Cases

- What if user doesn't know how to create presets? → Keep it simple - they'll figure it out (Krug: users are smarter than we think)
- Long preset names causing layout issues? → Use `.lineLimit(1)` already present

## Dependencies

### Option A: None
### Option C: Need to add `openTaskConfiguration` action

## Acceptance Criteria

### Option A:
- [ ] Empty state shows "Create presets" (not "Create presets from Task Configuration.")
- [ ] Text uses `.focallyCaption` font
- [ ] Text uses `.focallyOnSurfaceVariant` color
- [ ] No layout shift (spacing unchanged)
- [ ] Works in both light and dark modes

### Option C (if implemented):
- [ ] Above criteria met
- [ ] Button is clickable
- [ ] Clicking opens Task Configuration screen
- [ ] Button has `.buttonStyle(.plain)`
- [ ] Optional: Hover state added

## Related Files

- `Focally/Views/MenuBar/MenuBarDropdownView.swift` (lines 74-77)
- Related: Task Configuration screen (if implementing Option C)
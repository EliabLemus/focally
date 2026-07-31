# Fix #2: Agregar hover state a PredefinedTaskQuickButton

**Severity:** Critical
**Framework:** Clickeabilidad + Convenciones
**Ticket:** UX-KRUG-002

## Problem

Los predefined tasks en `FocusSessionComponents.swift:345-377` son botones pero NO indican visualmente que son clickeables:

- No hay hover state
- No hay cursor pointer
- No hay cambio de background/opacity
- No hay border o shadow en hover

Esto viola:
- **Clickeabilidad:** No es obvio qué es clickeable
- **Convenciones:** Botones parecen botones (tienen indicación visual de interactividad)
- **Auto-evidencia:** Usuario debe adivinar qué puede hacer click

## Current Implementation

```swift
// FocusSessionComponents.swift:345-377
public struct PredefinedTaskQuickButton: View {
    let task: PredefinedTask
    let action: () -> Void

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(task.emoji)
                    .font(.system(size: 18))
                    .frame(width: 34, height: 34)
                    .background(Color(hex: task.iconBgColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.name)
                        .font(.focallyBodyBold)
                        .foregroundStyle(Color.focallyOnSurface)
                    Text("\(task.durationMinutes)m")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.focallySurfaceContainerLowest.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
```

## Proposed Fix

Agregar hover state con animación smooth:

```swift
public struct PredefinedTaskQuickButton: View {
    let task: PredefinedTask
    let action: () -> Void

    @State private var isHovering = false

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(task.emoji)
                    .font(.system(size: 18))
                    .frame(width: 34, height: 34)
                    .background(Color(hex: task.iconBgColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.name)
                        .font(.focallyBodyBold)
                        .foregroundStyle(Color.focallyOnSurface)
                    Text("\(task.durationMinutes)m")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                }

                Spacer()

                // Add chevron on hover for visual feedback
                if isHovering {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.focallySurfaceContainerLowest.opacity(isHovering ? 0.9 : 0.72))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.focallyPrimary.opacity(isHovering ? 0.3 : 0), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}
```

**Key Changes:**
1. Add `@State private var isHovering`
2. Track hover with `.onHover` and animation
3. Increase background opacity on hover (0.72 → 0.9)
4. Add subtle border with primary color on hover
5. Add chevron icon that appears on hover (Krug convention: buttons show action indicator)

## Impact

- **UI:** Botones indican claramente que son clickeables
- **UX:** Usuario entiende inmediatamente qué puede hacer click
- **Krug Compliance:** ✅ Clickeabilidad obvia + ✅ Convenciones de botones
- **Performance:** Minimal - one state var, simple animation

## Testing

1. Build and run Focally
2. Open menubar dropdown
3. Verify predefined task buttons show without hover effects initially
4. Hover over a predefined task button
5. Verify:
   - Background becomes darker
   - Subtle border appears
   - Chevron icon fades in
   - Animation is smooth (0.15s easeInOut)
6. Click the button - verify it still starts the session
7. Move mouse away - verify hover effects fade out smoothly
8. Test in both light and dark modes

## Edge Cases

- Fast mouse movement over buttons → Animation should not flicker
- Multiple buttons hovered at once → Each should track independently
- Click while hovering → Animation should not interfere

## Dependencies

None - self-contained fix

## Acceptance Criteria

- [ ] Predefined task buttons show no hover effects initially
- [ ] Hovering increases background opacity (0.72 → 0.9)
- [ ] Hovering adds subtle border with primary color (0.3 opacity)
- [ ] Hovering shows chevron icon (10pt, right-pointing)
- [ ] Hover effects animate smoothly (0.15s easeInOut)
- [ ] Hover effects fade out smoothly when mouse leaves
- [ ] Clicking still starts the session correctly
- [ ] No layout shift when chevron appears
- [ ] Works in both light and dark modes
- [ ] No console errors or warnings

## Related Files

- `Focally/Views/Shared/FocusSessionComponents.swift` (lines 345-377)
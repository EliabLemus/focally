# Spec: Implement Critical UX Fixes (Batch 1)

**Batch:** 1 (Critical Priority)
**Date:** 2026-05-26
**Spec ID:** UX-KRUG-BATCH-001
**Related specs:** SPEC-001, SPEC-002

---

## Overview

Implement two critical UX fixes based on Steve Krug's frameworks to improve Focally's menubar dropdown usability.

## Changes

### Fix 1: Simplify "Paused · Notifications are back"

**File:** `Focally/Views/MenuBar/MenuBarDropdownView.swift`

**Location:** Line 99

**Current code:**
```swift
Text(timerService.isPaused ? "Paused · Notifications are back" : (timerService.isBreak ? "Break" : "Deep Focus Mode"))
```

**Change to:**
```swift
Text(timerService.isPaused ? "Paused" : (timerService.isBreak ? "Break" : "Deep Focus"))
```

**Rationale:**
- "Paused · Notifications are back" mixes two concepts (timer state + notification state)
- User must mentally process both states
- Violates Krug's first law: "Don't make me think"
- Notification state is already shown in footer (line 203)

---

### Fix 2: Add hover state to PredefinedTaskQuickButton

**File:** `Focally/Views/Shared/FocusSessionComponents.swift`

**Location:** Lines 345-377

**Current code:**
```swift
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

**Change to:**
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

**Key additions:**
1. `@State private var isHovering` to track hover state
2. `.onHover` with smooth animation (0.15s easeInOut)
3. Background opacity increases on hover (0.72 → 0.9)
4. Subtle border appears on hover (primary color, 0.3 opacity)
5. Chevron icon fades in on hover (Krug convention: action indicator)

---

## Acceptance Criteria

### Fix 1 - Simplify Paused State:
- [ ] When timer is paused, shows "Paused" (not "Paused · Notifications are back")
- [ ] When timer is active in work mode, shows "Deep Focus" (not "Deep Focus Mode")
- [ ] When timer is active in break mode, shows "Break"
- [ ] No visual regression in spacing or layout
- [ ] Footer notification status remains functional

### Fix 2 - PredefinedTaskQuickButton Hover State:
- [ ] Predefined task buttons show no hover effects initially
- [ ] Hovering increases background opacity (0.72 → 0.9)
- [ ] Hovering adds subtle border with primary color (0.3 opacity, 1pt line)
- [ ] Hovering shows chevron icon (10pt, right-pointing, on-surface-variant color)
- [ ] Hover effects animate smoothly (0.15s easeInOut)
- [ ] Hover effects fade out smoothly when mouse leaves
- [ ] Clicking still starts the session correctly
- [ ] No layout shift when chevron appears
- [ ] Works in both light and dark modes
- [ ] No console errors or warnings

---

## Testing

After implementation:
1. Build Focally: `xcodebuild -project Focally.xcodeproj -scheme Focally -configuration Debug build`
2. Run Focally: `open ~/Library/Developer/Xcode/DerivedData/Focally-*/Build/Products/Debug/Focally.app`
3. Test Fix 1:
   - Start a focus session
   - Pause the session
   - Verify text shows "Paused" only
   - Resume and verify it shows "Deep Focus"
   - Take a break and verify it shows "Break"
4. Test Fix 2:
   - Open menubar dropdown
   - Hover over a predefined task button
   - Verify all hover effects are present
   - Click the button - verify session starts
   - Move mouse away - verify effects fade out
5. Test in light mode
6. Test in dark mode

---

## Design Tokens

Use existing Focally design tokens:
- `Color.focallySurfaceContainerLowest`
- `Color.focallyPrimary`
- `Color.focallyOnSurface`
- `Color.focallyOnSurfaceVariant`
- `.focallyBodyBold`
- `.focallyCaption`

DO NOT hardcode colors like `.white` or `.black.opacity()`.

---

## Swift Version

- Target: Swift 5.9+
- Use explicit type hints in closures: `[weak self] (_: Result<Void, Error>) in`

---

## Notes

- Fix 1 is atomic (single line change)
- Fix 2 is isolated (self-contained component)
- Both fixes are low-risk
- Run auto-review after implementation: `./scripts/pr-auto-review.sh review --fix`

---

## References

- Original specs: `docs/product-specs/ux-krug-improvements/SPEC-001-*.md` and `SPEC-002-*.md`
- UI Audit Report: `UI-AUDIT.md` (Issues #1 and #2)
- Krug frameworks: `ui-no-pensar` skill
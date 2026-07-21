# TASK-025 — Implementation Spec for Codex

## Project Path
`/Users/openjaime/.openclaw/workspace/projects/focally`

## CRITICAL RULES (violations = build failure)
1. **ALWAYS use `Color.focallyXxx`** — NEVER `.focallyXxx` shorthand (ShapeStyle ambiguity)
2. **NO iOS APIs**: No `.keyboardType()`, `.tracking(.widest)`, `.navigationTitle()`
3. **NO `.toggleStyle(FocallyToggleButtonStyle())`** — use `.toggleStyle(.switch)`
4. **TopBarView uses `@ViewBuilder`** — `TopBarView { Text("title") }` NOT `TopBarView(title: "...")`
5. **FocallySegmentedControl takes `Binding<Int>` and `[String]`**
6. **Use `FocallySpacing.sm/md/lg/xl`**, `FocallyRadius.sm/md/lg/xl`, `FocallyFont.xxx`
7. **All cards use `.focallyCard()` modifier** — already defined
8. **Use `FocallyTab` enum** for tab definitions

## Design System References
- Colors: `FocallyColors.swift` — `Color.focallyPrimary`, `Color.focallyOnSurface`, etc.
- Spacing: `FocallySpacing` — xs=4, sm=8, md=16, lg=24, xl=40
- Radius: `FocallyRadius` — xs=4, sm=8, md=12, lg=16, xl=24
- Fonts: `.focallyDisplay` (28pt semibold), `.focallyH1` (22pt), `.focallyH2` (17pt), `.focallyBodyBold` (13pt semibold), `.focallyBody` (13pt), `.focallyCaption` (11pt medium), `.focallyMicro` (10pt)
- Card: `.focallyCard()` modifier

## Files to DELETE (old UI, no longer referenced)
1. `Focally/Views/SettingsView.swift`
2. `Focally/Views/FocusMenuView.swift`
3. `Focally/Views/ActivityInputView.swift`

## Changes

### 1. OnItFocusApp.swift — Menu bar icon
- Line 37: `"hourglass"` → `"timer"`
- Line 247: `"hourglass"` → `"timer"`

### 2. PredefinedTask.swift — Add properties
```swift
struct PredefinedTask: Identifiable, Codable, Equatable {
    static let defaultsKey = "predefinedTasks"
    var id = UUID()
    let name: String
    let emoji: String  // keep for backward compat
    let icon: String   // SF Symbol name
    let iconBgColor: String  // hex color for icon background
    let iconFgColor: String  // hex color for icon foreground
    let durationMinutes: Int
    let cycles: Int
}
```

Update the mock data in `PredefinedTasksList.swift` to match Stitch design:
```swift
PredefinedTask(name: "Deep Coding", emoji: "💻", icon: "chevron.left.forwardslash.chevron.right", iconBgColor: "DBEAFE", iconFgColor: "2563EB", durationMinutes: 25, cycles: 4)
PredefinedTask(name: "Technical Documentation", emoji: "📚", icon: "doc.text", iconBgColor: "FFEDD5", iconFgColor: "EA580C", durationMinutes: 50, cycles: 2)
PredefinedTask(name: "Inbox Clearing", emoji: "📧", icon: "envelope", iconBgColor: "F3E8FF", iconFgColor: "9333EA", durationMinutes: 15, cycles: 1)
PredefinedTask(name: "Quick Workout", emoji: "💪", icon: "dumbbell", iconBgColor: "DCFCE7", iconFgColor: "16A34A", durationMinutes: 10, cycles: 1)
```

### 3. TasksPage.swift — Bento grid layout
Change from VStack to proper bento grid matching task_picker_config HTML:
- 12-column grid
- Left column (col-span-5): TimerSettingsCard + FocusModeCard (stacked vertically)
- Right column (col-span-7): PredefinedTasksList
- Below grid: Smart Templates card + Footer

```swift
ScrollView {
    VStack(spacing: FocallySpacing.lg) {
        // Bento Grid
        HStack(alignment: .top, spacing: FocallySpacing.lg) {
            // Left column (5/12)
            VStack(spacing: FocallySpacing.lg) {
                TimerSettingsCard()
                FocusModeCard()
            }
            .frame(maxWidth: .infinity)
            
            // Right column (7/12)
            PredefinedTasksList()
                .frame(maxWidth: .infinity)
        }
        
        // Smart Templates Card
        SmartTemplatesCard()
        
        // Footer
        TasksFooter()
    }
    .padding(.horizontal, FocallySpacing.lg)
    .padding(.bottom, FocallySpacing.lg)
}
```

### 4. PredefinedTasksList.swift — Fix icons and metadata
- Use `task.icon` (SF Symbol) instead of hardcoded `chevron.left.forwardslash.chevron.right`
- Use `task.iconBgColor` and `task.iconFgColor` for colored icon backgrounds (rounded-lg, NOT circle)
- Show `"\(task.durationMinutes)m • \(task.cycles) cycles"` instead of hardcoded "25m • 4 cycles"
- Use `Color(hex: task.iconBgColor)` for background, `Color(hex: task.iconFgColor)` for icon color
- Extract `TaskRowView` into its own file `Focally/Views/Tasks/TaskRowView.swift`
- Hover actions: edit/delete buttons with opacity animation (opacity-0 → opacity-100 on hover)

### 5. TaskRowView.swift — NEW FILE (extracted from PredefinedTasksList)
```swift
import SwiftUI

struct TaskRowView: View {
    let task: PredefinedTask
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Colored icon (rounded rectangle, NOT circle)
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: task.iconBgColor))
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: task.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: task.iconFgColor))
                }

            // Task info
            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyOnSurface)

                Text("\(task.durationMinutes)m • \(task.cycles) cycles")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
            }

            Spacer()

            // Hover actions
            HStack(spacing: 4) {
                Button(action: {}) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                }
                .buttonStyle(.plain)

                Button(action: {}) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.focallyError)
                }
                .buttonStyle(.plain)
            }
            .opacity(isHovered ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .padding(FocallySpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.focallySurfaceContainerLowest.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.focallyOutline.opacity(0.1), lineWidth: 0.5)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
```

### 6. SmartTemplatesCard.swift — NEW FILE
Card matching the Stitch design:
```swift
import SwiftUI

struct SmartTemplatesCard: View {
    var body: some View {
        HStack(spacing: FocallySpacing.md) {
            // Icon
            Image(systemName: "sparkles")
                .font(.system(size: 24))
                .foregroundStyle(Color.focallySecondary)

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text("Smart Templates")
                    .font(.focallyH2)
                    .foregroundStyle(Color.focallyOnSurface)

                Text("AI can suggest task durations based on your past performance.")
                    .font(.focallyBody)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            // Button
            Button(action: {}) {
                Text("Enable AI Insights")
                    .font(.focallyButton)
                    .foregroundStyle(Color.focallyPrimary)
            }
            .buttonStyle(.plain)
        }
        .padding(FocallySpacing.lg)
        .background(Color.focallySecondaryFixed)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

### 7. SidebarView.swift — Add Daily Streak card
After the profile card, add a Daily Streak card:
```swift
// Daily Streak Card (above profile)
VStack(alignment: .leading, spacing: 8) {
    Text("Daily Streak")
        .font(.focallyCaption)
        .foregroundStyle(Color.focallyOnSurfaceVariant)

    HStack {
        Text("12 Days")
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(Color.focallyOnSurface)

        Spacer()

        Image(systemName: "flame.fill")
            .font(.system(size: 20))
            .foregroundStyle(.orange)
    }
}
.padding(FocallySpacing.md)
.background(
    RoundedRectangle(cornerRadius: FocallyRadius.lg)
        .fill(Color(hex: "FFFFFF").opacity(0.4))  // white/40 in light mode
        .overlay(
            RoundedRectangle(cornerRadius: FocallyRadius.lg)
                .stroke(Color.focallyCardBorder, lineWidth: 0.5)
        )
)
```
Place it between `Spacer()` and the Profile card.

### 8. SidebarView.swift — Remove "Pro Member" text
The profile card should only show the "E" avatar + "Eliab" name. Remove any "Pro Member" subtitle.
(Current code doesn't seem to have it, but verify and ensure it's gone.)

### 9. ActiveFocusView.swift — Add 3rd bottom card (Environment)
The design shows 3 bottom cards: Focus Score, Estimated End, Environment.
Current code only has 2 (FocusScoreCard + EstimatedTimeCard).
Add a third card:

```swift
// Environment Card
struct EnvironmentCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 20))
                .foregroundStyle(Color.focallySecondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Environment")
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyOnSurface)

                Text("Calm")
                    .font(.focallyH2)
            }
        }
        .padding(16)
        .background(Color.focallySurfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.focallyCardBorder, lineWidth: 0.5)
        }
    }
}
```

Add to the `bottomCards` HStack in ActiveFocusView.

### 10. ActiveFocusView.swift — Fix bottom cards to match design
Design shows 3 cards in a row (col-span-4 each in 12-col grid). Current uses HStack with 2 cards.
Change to 3 cards with equal spacing. Use the simpler card style (icon + label + value) matching the Stitch design — not the ring chart.

Replace FocallyFocusScoreCard with a simpler inline version:
```swift
// Focus Score (simple card matching design)
HStack(spacing: 12) {
    Image(systemName: "bolt.fill")
        .font(.system(size: 20))
        .foregroundStyle(Color.focallyPrimary)

    VStack(alignment: .leading, spacing: 2) {
        Text("Focus Score")
            .font(.focallyCaption)
            .foregroundStyle(Color.focallyOnSurfaceVariant)
        Text("94%")
            .font(.focallyH2)
    }

    Spacer()

    Text("High")
        .font(.focallyMicro)
        .foregroundStyle(Color.focallyPrimary)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Color.focallyPrimary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 4))
}
.padding(20)
.background(Color.focallySurfaceContainerLowest)
.clipShape(RoundedRectangle(cornerRadius: 16))
.overlay {
    RoundedRectangle(cornerRadius: 16)
        .stroke(Color.focallyCardBorder, lineWidth: 0.5)
}
```

DO NOT delete FocallyFocusScoreCard.swift (it's used in AnalyticsPage). Instead, inline the simpler version in ActiveFocusView.

### 11. TopBarView.swift — Add DND badge support
The TopBarView currently only has right-side buttons. Add optional DND badge on the left.

Actually, looking at the code more carefully: ActiveFocusView already has its own topBar with DND badge. TimerPage also has its own topBar. The TopBarView is only used in TasksPage, SchedulePage, AnalyticsPage, and SettingsPage.

The DND badge should only show during active focus sessions — which is handled by ActiveFocusView's own topBar. **No change needed to TopBarView.swift.**

### 12. project.yml — Add new files
Make sure these new files are listed in project.yml sources or XcodeGen picks them up automatically.

## Build verification
After all changes:
```bash
cd /Users/openjaime/.openclaw/workspace/projects/focally
xcodegen generate
xcodebuild -scheme Focally -destination 'platform=macOS' build 2>&1 | tail -20
```

## Summary of all file changes
| File | Action |
|------|--------|
| `Focally/Views/SettingsView.swift` | DELETE |
| `Focally/Views/FocusMenuView.swift` | DELETE |
| `Focally/Views/ActivityInputView.swift` | DELETE |
| `Focally/OnItFocusApp.swift` | EDIT — hourglass→timer (lines 37, 247) |
| `Focally/Models/PredefinedTask.swift` | EDIT — add icon, iconBgColor, iconFgColor, durationMinutes, cycles |
| `Focally/Views/Tasks/TasksPage.swift` | REWRITE — bento grid layout + SmartTemplates + footer |
| `Focally/Views/Tasks/PredefinedTasksList.swift` | EDIT — fix mock data, use task.icon/color/duration, remove TaskRowView |
| `Focally/Views/Tasks/TaskRowView.swift` | CREATE — extracted from PredefinedTasksList |
| `Focally/Views/Tasks/SmartTemplatesCard.swift` | CREATE |
| `Focally/Views/Navigation/SidebarView.swift` | EDIT — add Daily Streak card, verify no "Pro Member" |
| `Focally/Views/Timer/ActiveFocusView.swift` | EDIT — 3 bottom cards instead of 2, simpler Focus Score inline |

---
id: TASK-024
created: 2026-05-01T13:03:00-06:00
status: pending
agent: codex
priority: high
depends_on: [TASK-016, TASK-018]
---

# TASK-024: Complete UI Redesign — Stitch Design System (ALL Pages)

## Entorno
- CWD: /Users/openjaime/.openclaw/workspace/projects/focally
- Stack: Swift 5.9, SwiftUI, macOS 14+, XcodeGen (project.yml), @Observable (post TASK-016)
- Runtime check: `xcodebuild -scheme Focally -destination 'platform=macOS' build`
- Tests: `xcodebuild test -scheme Focally -destination 'platform=macOS'`
- Design source: `/Users/openjaime/.openclaw/workspace/focally-design/stitch_focally_focus_automator/`
- Light theme design doc: `focused_precision/DESIGN.md`
- Dark theme design doc: `obsidian_flux/DESIGN.md`

## Archivos relevantes (existentes)
- `Focally/Views/FocusMenuView.swift` — Current menu popover UI → **REEMPLAZAR** por nuevo dropdown
- `Focally/Views/SettingsView.swift` — Current settings → **REEMPLAZAR** por nuevo sistema de settings
- `Focally/Views/ActivityInputView.swift` — Activity input component → **REEMPLAZAR** por nuevo task input
- `Focally/Services/FocusTimerService.swift` — Timer state provider (read-only)
- `Focally/Services/HistoryService.swift` — Session history data (read-only, post TASK-018)
- `Focally/Services/DNDService.swift` — DND state
- `Focally/Services/SlackService.swift` — Slack connection state
- `Focally/Services/GoogleCalendarService.swift` — Calendar events (read + write)
- `Focally/Services/SoundPlayerService.swift` — Sound selection
- `Focally/Services/NotificationService.swift` — Notification settings
- `Focally/OnItFocusApp.swift` — App delegate, window management, menu bar
- `Focally/Models/CalendarEvent.swift` — Calendar event model
- `Focally/Models/PomodoroState.swift` — Pomodoro state enum
- `Focally/Models/PredefinedTask.swift` — Predefined task model
- `project.yml` — XcodeGen project file (update sources)

## Objetivo
Rediseño completo de Focally basado en Stitch by Google. Incluye **todas las páginas**:
1. Menu Bar Status + Dropdown (reemplaza FocusMenuView por completo)
2. Active Focus View (reemplaza la ventana principal actual)
3. Focus Schedule (nuevo — calendario semanal con Google Calendar)
4. Task Configuration (nuevo — timer settings + predefined tasks)
5. Focus Analytics (dashboard con métricas y charts)
6. Settings / Automation (reemplaza SettingsView por completo)

Todo con **Light Mode** ("Focused Precision") y **Dark Mode** ("Obsidian Flux").

---

## Design System — Token Reference

### Color Tokens — Light Theme ("Focused Precision")

| Token | Hex | SwiftUI Name |
|-------|-----|-------------|
| `primary` | `#0058BC` | `.focallyPrimary` |
| `onPrimary` | `#FFFFFF` | `.focallyOnPrimary` |
| `primaryContainer` | `#0070EB` | `.focallyPrimaryContainer` |
| `primaryFixed` | `#D8E2FF` | `.focallyPrimaryFixed` |
| `primaryFixedDim` | `#ADC6FF` | `.focallyPrimaryFixedDim` |
| `onPrimaryFixed` | `#001A41` | `.focallyOnPrimaryFixed` |
| `onPrimaryFixedVariant` | `#004493` | `.focallyOnPrimaryFixedVariant` |
| `onPrimaryContainer` | `#FEFCFF` | `.focallyOnPrimaryContainer` |
| `tertiary` | `#9E3D00` | `.focallyTertiary` |
| `tertiaryContainer` | `#C64F00` | `.focallyTertiaryContainer` |
| `tertiaryFixed` | `#FFDBCC` | `.focallyTertiaryFixed` |
| `tertiaryFixedDim` | `#FFB595` | `.focallyTertiaryFixedDim` |
| `onTertiary` | `#FFFFFF` | `.focallyOnTertiary` |
| `onTertiaryContainer` | `#FFFBFF` | `.focallyOnTertiaryContainer` |
| `secondary` | `#5E5E5E` | `.focallySecondary` |
| `onSecondary` | `#FFFFFF` | `.focallyOnSecondary` |
| `secondaryContainer` | `#E1DFDF` | `.focallySecondaryContainer` |
| `secondaryFixed` | `#E4E2E2` | `.focallySecondaryFixed` |
| `secondaryFixedDim` | `#C7C6C6` | `.focallySecondaryFixedDim` |
| `onSecondaryContainer` | `#636262` | `.focallyOnSecondaryContainer` |
| `onSecondaryFixed` | `#1B1C1C` | `.focallyOnSecondaryFixed` |
| `onSecondaryFixedVariant` | `#464747` | `.focallyOnSecondaryFixedVariant` |
| `onSurface` | `#1A1C1C` | `.focallyOnSurface` |
| `onSurfaceVariant` | `#414755` | `.focallyOnSurfaceVariant` |
| `outline` | `#717786` | `.focallyOutline` |
| `outlineVariant` | `#C1C6D7` | `.focallyOutlineVariant` |
| `surface` | `#F9F9F9` | `.focallySurface` |
| `surfaceBright` | `#F9F9F9` | `.focallySurfaceBright` |
| `surfaceDim` | `#DADADA` | `.focallySurfaceDim` |
| `surfaceContainerLowest` | `#FFFFFF` | `.focallySurfaceContainerLowest` |
| `surfaceContainerLow` | `#F3F3F4` | `.focallySurfaceContainerLow` |
| `surfaceContainer` | `#EEEEEE` | `.focallySurfaceContainer` |
| `surfaceContainerHigh` | `#E8E8E8` | `.focallySurfaceContainerHigh` |
| `surfaceContainerHighest` | `#E2E2E2` | `.focallySurfaceContainerHighest` |
| `surfaceVariant` | `#E2E2E2` | `.focallySurfaceVariant` |
| `surfaceTint` | `#005BC1` | `.focallySurfaceTint` |
| `error` | `#BA1A1A` | `.focallyError` |
| `errorContainer` | `#FFDAD6` | `.focallyErrorContainer` |
| `onError` | `#FFFFFF` | `.focallyOnError` |
| `onErrorContainer` | `#93000A` | `.focallyOnErrorContainer` |
| `background` | `#F9F9F9` | `.focallyBackground` |
| `onBackground` | `#1A1C1C` | `.focallyOnBackground` |
| `inverseSurface` | `#2F3131` | `.focallyInverseSurface` |
| `inverseOnSurface` | `#F0F1F1` | `.focallyInverseOnSurface` |
| `inversePrimary` | `#ADC6FF` | `.focallyInversePrimary` |

### Color Tokens — Dark Theme ("Obsidian Flux")

| Token | Hex | SwiftUI Name |
|-------|-----|-------------|
| `primary` | `#ADC6FF` | `.focallyPrimary` (adaptive) |
| `onPrimary` | `#002E69` | `.focallyOnPrimary` |
| `primaryContainer` | `#4B8EFF` | `.focallyPrimaryContainer` |
| `primaryFixed` | `#D8E2FF` | `.focallyPrimaryFixed` |
| `primaryFixedDim` | `#ADC6FF` | `.focallyPrimaryFixedDim` |
| `onPrimaryFixed` | `#001A41` | `.focallyOnPrimaryFixed` |
| `onPrimaryFixedVariant` | `#004493` | `.focallyOnPrimaryFixedVariant` |
| `onPrimaryContainer` | `#00285C` | `.focallyOnPrimaryContainer` |
| `tertiary` | `#C8C6C8` | `.focallyTertiary` |
| `tertiaryContainer` | `#919092` | `.focallyTertiaryContainer` |
| `tertiaryFixed` | `#E4E2E4` | `.focallyTertiaryFixed` |
| `tertiaryFixedDim` | `#C8C6C8` | `.focallyTertiaryFixedDim` |
| `onTertiary` | `#303032` | `.focallyOnTertiary` |
| `onTertiaryContainer` | `#29292B` | `.focallyOnTertiaryContainer` |
| `secondary` | `#C8C6C8` | `.focallySecondary` |
| `onSecondary` | `#303032` | `.focallyOnSecondary` |
| `secondaryContainer` | `#474649` | `.focallySecondaryContainer` |
| `secondaryFixed` | `#E4E2E4` | `.focallySecondaryFixed` |
| `secondaryFixedDim` | `#C8C6C8` | `.focallySecondaryFixedDim` |
| `onSecondaryContainer` | `#B6B4B7` | `.focallyOnSecondaryContainer` |
| `onSecondaryFixed` | `#1B1B1D` | `.focallyOnSecondaryFixed` |
| `onSecondaryFixedVariant` | `#474649` | `.focallyOnSecondaryFixedVariant` |
| `onSurface` | `#E3E2E7` | `.focallyOnSurface` |
| `onSurfaceVariant` | `#C1C6D7` | `.focallyOnSurfaceVariant` |
| `outline` | `#8B90A0` | `.focallyOutline` |
| `outlineVariant` | `#414755` | `.focallyOutlineVariant` |
| `surface` | `#121317` | `.focallySurface` |
| `surfaceBright` | `#38393D` | `.focallySurfaceBright` |
| `surfaceDim` | `#121317` | `.focallySurfaceDim` |
| `surfaceContainerLowest` | `#0D0E12` | `.focallySurfaceContainerLowest` |
| `surfaceContainerLow` | `#1A1B1F` | `.focallySurfaceContainerLow` |
| `surfaceContainer` | `#1E1F23` | `.focallySurfaceContainer` |
| `surfaceContainerHigh` | `#292A2E` | `.focallySurfaceContainerHigh` |
| `surfaceContainerHighest` | `#343539` | `.focallySurfaceContainerHighest` |
| `surfaceVariant` | `#343539` | `.focallySurfaceVariant` |
| `surfaceTint` | `#ADC6FF` | `.focallySurfaceTint` |
| `error` | `#FFB4AB` | `.focallyError` |
| `errorContainer` | `#93000A` | `.focallyErrorContainer` |
| `onError` | `#690005` | `.focallyOnError` |
| `onErrorContainer` | `#FFDAD6` | `.focallyOnErrorContainer` |
| `background` | `#121317` | `.focallyBackground` |
| `onBackground` | `#E3E2E7` | `.focallyOnBackground` |
| `inverseSurface` | `#E3E2E7` | `.focallyInverseSurface` |
| `inverseOnSurface` | `#2F3034` | `.focallyInverseOnSurface` |
| `inversePrimary` | `#005BC1` | `.focallyInversePrimary` |

### Typography Scale (Inter)

| Role | Size | Weight | Line Height | Letter Spacing | SwiftUI Font |
|------|------|--------|-------------|----------------|-------------|
| `display` | 28px | 600 | 34px | -0.02em | `.focallyDisplay` |
| `h1` | 22px | 600 | 28px | -0.01em | `.focallyH1` |
| `h2` | 17px | 600 | 22px | -0.01em | `.focallyH2` |
| `body-bold` | 13px | 600 | 20px | 0em | `.focallyBodyBold` |
| `body` | 13px | 400 | 20px | 0em | `.focallyBody` |
| `button` | 13px | 500 | 16px | 0em | `.focallyButton` |
| `caption` | 11px | 500 | 14px | +0.01em | `.focallyCaption` |
| `micro` | 10px | 500 | 12px | 0em | `.focallyMicro` |

### Spacing

| Token | Value |
|-------|-------|
| `unit` | 4px |
| `xs` | 4px |
| `sm` | 8px |
| `md` | 16px |
| `gutter` | 20px |
| `lg` | 24px |
| `xl` | 40px |

### Border Radius

| Token | Value | Usage |
|-------|-------|-------|
| `xs` | 4px | Selection indicators |
| `sm` | 8px | Buttons, inputs |
| `md` | 12px | Cards |
| `lg` | 16px | Large containers, rounded corners |
| `xl` | 24px | Large hero cards (rounded-3xl) |
| `pill` | 9999px | Full rounded elements |

### Shadows

| Context | Light | Dark |
|---------|-------|------|
| Card | `shadow-sm` — barely visible | No shadow, use `border white/8` |
| Active/selected | Slightly stronger | `border white/12` |
| Modal/Popover | `0 10px 30px rgba(0,0,0,0.1)` | `0 10px 30px rgba(0,0,0,0.4)` |
| FAB | `shadow-lg shadow-primary/20` | `shadow-lg shadow-primary/30` |

### Glass Effects

| Element | Light | Dark |
|---------|-------|------|
| Sidebar | `rgba(243,243,244,0.8)` + `blur(30px)` + `border-right 0.5px black/10` | `rgba(18,19,23,0.8)` + `blur(30px)` + `border-right 0.5px white/8` |
| Top bar | `rgba(255,255,255,0.8)` + `blur-xl` | `rgba(18,19,23,0.8)` + `blur-xl` |
| Dropdown | `rgba(255,255,255,0.85)` + `blur(30px)` + `inset 0 0 0 0.5px white/40` + `shadow` | `rgba(28,28,30,0.7)` + `blur(20px)` + `border 1px white/8` |
| Cards (dark) | N/A | `rgba(28,28,30,0.7)` + `blur(20px)` + `border 1px white/8` |

### Theme Switching

Use `@Environment(\.colorScheme)` to switch between light/dark tokens. All color properties should be computed properties that return the correct value based on color scheme.

```swift
// Pattern: computed color per scheme
static var focallyPrimary: Color {
    colorScheme == .dark ? Color(hex: "ADC6FF") : Color(hex: "0058BC")
}
```

Wrap all theme-aware colors in a `FocallyTheme` environment object OR use `Color` extensions with `UIColor` dynamic provider:

```swift
extension Color {
    static let focallyPrimary = Color("focallyPrimary") // Asset catalog with light/dark variants
}
```

**Recommended approach**: Use Asset Catalog (`.xcassets`) with color sets that have light/dark variants. This is the most performant and maintainable approach.

---

## Architecture

### Window Structure

1. **Menu Bar Dropdown** — REEMPLAZA `FocusMenuView`. Panel de 320px al hacer click en el icono del menu bar. Es la pantalla inicial.
2. **Main Window** — Ventana completa con sidebar + contenido. Se abre desde el dropdown o Cmd+Shift+F.

### Navigation Tabs

```swift
enum FocallyTab: String, CaseIterable, Identifiable {
    case timer = "Timer"
    case tasks = "Tasks"
    case schedule = "Schedule"
    case analytics = "Analytics"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String { /* SF Symbol */ }
}
```

### Shared Components

These are used across multiple pages:

- **SidebarView** — 260px, glass blur, nav items, profile card at bottom
- **TopBarView** — Fixed top bar with page title, actions
- **CardModifier** — `.focallyCard()` modifier for consistent card styling
- **ToggleButton** — Pill toggle (on: primary bg, off: gray bg)
- **SegmentedControl** — Recessed track with sliding tile
- **SessionProgressCard** — Active session display with progress bar
- **EmptyStateView** — Placeholder for pages without data

---

## PAGE 1: Menu Bar Status

### Menu Bar Icon
- SF Symbol: `timer` (filled when session active, outline when idle)
- Countdown text next to icon: caption font, primary color
- Background pill: `primary/10` when active

### Menu Bar Dropdown (320px panel)

**THIS IS THE INITIAL SCREEN when clicking the Focally menu bar icon.**

**Layout** (top to bottom):
1. **Header**: "Focus" title (h2) + Settings icon + More icon (top-right)
2. **Task Input**: Text field with `add_task` icon placeholder, "Current Task"
   - Style: `bg-black/5` (light) / `bg-white/5` (dark), rounded-lg, no border
   - Focus: `ring-2 ring-primary/50`
3. **Action Buttons**:
   - **Start Pomodoro**: Full-width, `bg-primary text-on-primary`, icon `timer` + "Start Pomodoro" + "25m" right-aligned
   - **Custom Session**: Full-width, `bg-secondaryContainer text-onSecondaryContainer`, icon `timer` + "Custom Session" + "45m" right-aligned
4. **Active Session Card** (if session running):
   - `bg-surfaceContainerLow`, rounded-lg, border
   - Task name (body-bold) + "Deep Focus Mode" (caption)
   - Pause/Stop buttons: 32x32 circles, white bg, border
   - Large countdown: display font (28px), tabular nums
   - Progress bar: 6px height, `bg-black/5` track, `bg-primary` fill
   - "00:02 of 25:00" caption
5. **Footer Stats**:
   - Daily focus time: `analytics` icon + "Daily: 4.5h Focus"
   - Flow state: `workspace_premium` icon + "85% Flow State"
   - Divider: `border-t border-black/5`

**Glass effect**: `backdrop-blur(30px) saturate(150%)`, `inset 0 0 0 0.5px white/40`, `shadow 0 10px 30px rgba(0,0,0,0.1)`

**Dark mode**: `rgba(28,28,30,0.7)` bg, `blur(20px)`, `border 1px white/8`

**Swift file**: `Focally/Views/MenuBar/MenuBarDropdownView.swift`
**Replaces**: `FocusMenuView.swift` (delete or deprecate)

---

## PAGE 2: Active Focus View (Timer Tab)

### Two layout variants depending on state:

#### Variant A: Session Active (Full Timer View)

**Layout**:
- **Top Bar**: DND badge (filled `notifications_off` icon + "DO NOT DISTURB ACTIVE" caption) + History button + Settings button
- **Center Content** (vertically + horizontally centered):
  - Badge: "Deep Work Phase" — pill with `bg-primary/5 border-primary/10`, pulsing green dot, uppercase caption
  - Task name: display font (28px), centered
  - Task description: body, outline color, max-width 400px, centered
  - Timer: **160px** font, tabular nums, bold, tight tracking
    - Colon: `text-primary/30`, animated pulse
    - "Session 1 of 4" caption below
  - Ambient glow: `bg-primary/5 rounded-full blur-3xl opacity-50` behind timer
- **Controls**: Pause (64x64 circle, `bg-secondaryFixed`) + Finish (64x64 circle, `bg-error/10` hover `bg-error`)
- **Bottom Cards** (3-column bento grid, absolute bottom):
  - Focus Score: `bolt` icon + "High" badge (primary bg) + "94%" h2
  - Estimated End: `schedule` icon + "11:45 AM" h2
  - (NO Energy Level card — removed per user request)
  - (NO Music card — removed per user request)

#### Variant B: Session Idle (Dashboard View)

**Layout** (from menu_bar_state_light):
- **Top Bar**: Same as Variant A but without DND badge
- **Header**: "Focus Session" (display) + subtitle "Configure your next deep work block."
- **Bento Grid** (12-column):
  - **Timer Display** (col-span-8): Card with task name badge, 120px countdown, Pause/Skip buttons (pill shape, full-width)
  - **Up Next** (col-span-4): Card with next break/task items, each with colored dot + name + duration
  - **Focus Mode** (col-span-4): Card with DND icon, "AUTO-ENABLED" badge, status text
  - **Today's Flow** (col-span-4): Mini bar chart showing daily sessions (7 bars, varying heights, blue gradient shades)
  - **Energy Level** (col-span-4): Card with `bolt` icon + "OPTIMAL" badge — **REMOVE THIS CARD** per user request

**FAB (Floating Action Button)**: Fixed bottom-right, 56x56, `bg-primary text-white`, `plus` icon, shadow-lg
- **Action**: Opens new session configuration / starts quick pomodoro

**Swift files**:
- `Focally/Views/Timer/ActiveFocusView.swift` — Session active variant
- `Focally/Views/Timer/IdleDashboardView.swift` — Session idle variant
- `Focally/Views/Timer/TimerPage.swift` — Container that switches between variants based on `FocusTimerService.state`

---

## PAGE 3: Focus Schedule (Calendar Tab)

### Layout
- **Top Bar**: "Focus Schedule" (h2) + Google Calendar sync badge (`sync` icon + "Synced with Google Calendar", green text) + "New Session" button (primary, with `add` icon) + History button
- **Calendar Controls**: Month/year display font + prev/next buttons + "Today" button
- **View Toggle**: Segmented control — Week / Month / Day
- **Calendar Grid** (Week view default):
  - Columns: Time (60px) + Mon-Sun (7 equal columns)
  - Day headers: 48px height, day name (caption, uppercase, tracking-wider) + date number (h2)
  - Current day: `bg-primary/5` header + `bg-primary/[0.02]` column
  - Time rows: 64px each, 08:00-13:00+ (scrollable), `border-bottom black/5`
  - Grid lines: `border-l border-black/[0.03]`

### Focus Blocks on Calendar
- **Past session**: `bg-primary/10 border-l-4 border-primary rounded-lg`, task name + time range
- **Non-focus event**: `bg-tertiaryContainer/10 border-l-4 border-tertiaryContainer rounded-lg`
- **Current session**: `bg-primary border-l-4 border-white rounded-lg shadow-lg`, with pulsing dot indicator
- Each block is positioned absolutely based on start time and height based on duration

### Interactions
- Click on empty time slot → Create new focus block
- Click on existing block → Edit (task, time, duration)
- Drag block edges → Resize (change duration)
- "New Session" button → Opens focus block creation sheet

### Calendar Card Style
- `bg-white border border-black/5 rounded-2xl shadow-sm` (light)
- `bg-surfaceContainer/80 backdrop-blur border white/8 rounded-2xl` (dark)

**Swift files**:
- `Focally/Views/Schedule/SchedulePage.swift` — Main container
- `Focally/Views/Schedule/WeekCalendarView.swift` — Week view grid
- `Focally/Views/Schedule/CalendarDayHeader.swift` — Day column header
- `Focally/Views/Schedule/FocusBlockView.swift` — Individual focus block on calendar
- `Focally/Views/Schedule/CreateFocusBlockSheet.swift` — Sheet for creating/editing blocks
- `Focally/Services/ScheduleService.swift` — CRUD for focus blocks, Google Calendar sync

---

## PAGE 4: Task Configuration (Tasks Tab)

### Layout (from task_picker_config):
- **Top Bar**: "Task Configuration" (h2) + History + Settings buttons
- **Header**: "Task Configuration" (display) + "Manage your focus sessions and predefined activities." (body)
- **Bento Grid** (12-column):

#### Timer Settings Card (col-span-5)
- Card with `av_timer` icon + "Timer Settings" (h2)
- Three number inputs in vertical stack:
  - **Focus Duration**: Default 25, label "min"
  - **Short Break**: Default 5, label "min"
  - **Long Break**: Default 15, label "min"
  - Input style: `bg-black/5 rounded-lg px-4 py-3`, focus `ring-2 ring-primary/50`
  - Label: body-bold, unit: caption
- Divider
- **Auto-start Breaks**: Toggle (primary when on, gray when off)

#### Visual Accent Card (below Timer Settings)
- 128px height, full-width, rounded-xl
- Background image (workspace photo) with `bg-primary/20 backdrop-blur(2px)` overlay
- "Flow Mode" (h2, white) + "Optimized for knowledge work." (caption, white/80)
- **This is decorative only** — use a static gradient or abstract pattern instead of image

#### Predefined Tasks Card (col-span-7)
- Header: `task_alt` icon + "Predefined Tasks" (h2) + "Add New" button (primary, `add` icon)
- Task list, each row:
  - `bg-black/[0.02] hover:bg-black/[0.05] rounded-xl p-md`
  - Icon: 32x32 rounded-lg with color bg + Material Symbol
    - Code tasks: `bg-blue-100 text-blue-600`, `code` icon
    - Docs tasks: `bg-orange-100 text-orange-600`, `article` icon
    - Email tasks: `bg-purple-100 text-purple-600`, `mail` icon
    - Exercise: `bg-green-100 text-green-600`, `fitness_center` icon
  - Task name: body-bold
  - Metadata: caption — "{duration}m • {cycles} cycles"
  - Actions (hover-reveal): Edit (`edit` icon) + Delete (`delete` icon, red)
- "Smart Templates" section (placeholder for future AI feature):
  - "AI-Powered Task Suggestions" caption
  - "Coming Soon" badge, disabled/greyed out
  - Leave the UI shell but disable interactions

**Swift files**:
- `Focally/Views/Tasks/TasksPage.swift` — Main container
- `Focally/Views/Tasks/TimerSettingsCard.swift` — Duration inputs + toggles
- `Focally/Views/Tasks/PredefinedTasksList.swift` — Task list with CRUD
- `Focally/Views/Tasks/TaskRowView.swift` — Individual task row
- `Focally/Views/Tasks/AddTaskSheet.swift` — Sheet for creating/editing tasks

---

## PAGE 5: Focus Analytics (Analytics Tab)

### Layout
- **Top Bar**: "Focus Analytics" (h2) + History + Settings buttons
- **Header**: "Focus Analytics" (display) + "Detailed insights into your deep work performance." (body, outline color)
- **Time Range Toggle**: Weekly / Monthly segmented control (right-aligned)

### Bento Grid (12-column)

#### Card 1: Focus Score (col-span-8)
- **Left**: "FOCUS SCORE" label (caption, primary, uppercase, tracking-widest) + Score number (48px, extrabold) + Delta (body-bold, tertiary) + Description (body, outline, max-width 240px)
- **Right**: Score ring (160x160 SVG donut)
  - Background circle: `surfaceContainer`, stroke-width 12
  - Progress circle: `primary`, stroke-width 12, round linecap
  - Center: `bolt.fill` icon (primary, 32px)

#### Card 2: Avg. Session Depth (col-span-4)
- Icon container (40x40, `tertiary/10` bg) + `gauge.with.dots.needle.bottom.50percent` icon (tertiary)
- Value: "2h 14m" (h2)
- Label: "AVG. SESSION DEPTH" (caption, outline, uppercase)
- Progress bar: 4px height, `surfaceContainerLow` track, `tertiary` fill, 75%
- Subtitle: "30 mins longer than baseline" (caption, outline)

#### Card 3: Focus Trend (col-span-7)
- Header: "Focus Trend" (h2) + date range (caption, outline, right-aligned)
- Chart: 200px height, Swift Charts
  - Line: primary (#0058BC), stroke-width 2
  - Fill: gradient primary/0.15 → transparent
  - X-axis: MON-SUN, micro font, outline color

#### Card 4: Focus Allocation (col-span-5)
- Title: "Focus Allocation" (h2)
- List of categories, each with:
  - Colored vertical bar (2px × 32px, rounded-full)
  - Category colors: primary, tertiary, secondary, surfaceContainerHigh
  - Task name (body-bold) + hours (caption, outline) + percentage (body-bold, right)

### Recent Sessions Section
- Header: "Recent Sessions" (h2) + "Export Data" button (primary color, hover underline) — non-functional placeholder
- Scrollable list, max-height 400px
- Each session row:
  - Card: `surfaceContainerLowest`, rounded-xl, p-md
  - Hover: `surfaceContainerLow` transition
  - Date badge: 48x48, `surfaceContainer` bg, rounded-lg
    - Month: micro, bold, outline, uppercase
    - Day: h2
  - Activity name: body-bold
  - Metadata: caption, outline — category + bullet + time range
  - Duration: body-bold + "DURATION" caption
  - Rating: 5 stars (SF Symbols `star.fill` / `star`)
    - Filled: primary, Empty: outline/30%

**Swift files**:
- `Focally/Views/Analytics/AnalyticsPage.swift` — Main container
- `Focally/Views/Analytics/FocusScoreCard.swift` — Score + ring
- `Focally/Views/Analytics/AvgSessionDepthCard.swift` — Avg depth + progress bar
- `Focally/Views/Analytics/FocusTrendChart.swift` — Swift Charts line chart
- `Focally/Views/Analytics/FocusAllocationCard.swift` — Category breakdown
- `Focally/Views/Analytics/RecentSessionsList.swift` — Session list
- `Focally/Views/Analytics/SessionRowView.swift` — Individual session row

---

## PAGE 6: Settings (Settings Tab)

### Sub-Navigation
Settings has sub-pages accessible via a secondary nav or sidebar section:
- **General** — Launch at login, notifications, menu bar, sound
- **Automation** — DND, CFPreferences, system integrations
- **Integrations** — Slack, Google Calendar, n8n
- **Appearance** — Theme (Light/Dark/System), accent color
- **About** — Version, license, credits

### Layout (from settings_automation):
- **Sidebar**: Same shared sidebar with Settings tab active
- **Content Area**: Max-width 600px, centered
- **Top Bar**: "Settings › Automation" (caption, gray) + History + Help icons
- **Footer**: "Reset to Default" button (left) + "Cancel" + "Save Changes" buttons (right), `border-t`, `bg-gray-50/50`

### General Preferences
- **Launch Focally at login**: `login` icon + checkbox
- **Enable sound notifications**: `notifications_active` icon + checkbox + sound picker dropdown ("Crystal", "Breeze", "Minimal")
- **Show timer in Menu Bar**: `dock` icon + checkbox

### Automation Section
Bento-style cards for each automation method:
- **System Focus Mode**:
  - Icon: `do_not_disturb_on` in `primary/10` container (40x40)
  - Title: "System Focus Mode" (body-bold)
  - Description: "Sync directly with macOS Focus filters to silence native notifications and hide Dock badges."
  - Toggle: pill, on = primary, off = gray
- **CFPreferences Hook**:
  - Icon: `terminal` in `tertiary/10` container
  - Title: "CFPreferences Hook" (body-bold)
  - Description: "Low-level toggle using CoreFoundation to override global app behaviors."
  - Toggle: pill, off by default
  - Warning: `warning` icon + "Requires Accessibility permissions in System Settings" (tertiary caption, with divider)

### Profile Card (Sidebar Bottom)
- Avatar: Circle with initials "E" (placeholder for "Eliab")
  - Light: `bg-primary-container text-white`, 32x32
  - Dark: `bg-primary text-on-primary`, 32x32
- Name: "Eliab" (body-bold, 12px)
- Subtitle: Removed (no "Pro Member" or "Pro Plan")

**Swift files**:
- `Focally/Views/Settings/SettingsPage.swift` — Main container with sub-nav
- `Focally/Views/Settings/GeneralSettingsView.swift` — General preferences
- `Focally/Views/Settings/AutomationSettingsView.swift` — DND + CFPreferences
- `Focally/Views/Settings/IntegrationsSettingsView.swift` — Slack, Calendar
- `Focally/Views/Settings/AppearanceSettingsView.swift` — Theme, accent
- `Focally/Views/Settings/AboutSettingsView.swift` — Version info

---

## Shared Components

### SidebarView

```
Width: 260px, fixed left
Background: glass blur (see Glass Effects table)
Border-right: 0.5px

Structure (top to bottom):
1. Logo area (mb-8, px-2, pt-2):
   - "Focally" — h1 font (22px, bold), onSurface color
   - "Deep Work" — caption (10px), secondary color, uppercase, tracking-widest

2. Navigation (space-y-1):
   For each tab:
   - Active: bg-gray-200/50 (light) / bg-white/10 (dark), text-onSurface, icon=primary+filled
   - Inactive: text-secondary, hover:bg-gray-200/30
   - Icon: 18px Material Symbol → SF Symbol mapping (see table below)
   - Label: button font (13px, medium)
   - Layout: flex, gap-3, px-3, py-2, rounded-md

3. Profile card (mt-auto, p-2):
   - Container: bg-surfaceContainerLow, border border-black/5, rounded-xl
   - Avatar: 32x32 circle with "E" initial
   - Name: "Eliab" body-bold 12px
   - No subtitle (no "Pro Member")
```

### TopBarView

```
Height: 48px (h-12)
Position: fixed top, offset by sidebar width
Background: glass blur (see Glass Effects table)
Border-bottom: white/10

Layout:
- Left: Context-specific content (DND badge, page title, etc.)
- Right: Action buttons (History, Settings, etc.)
  - Buttons: 32x32 circle, hover:bg-gray-200/50, icon: 18px secondary
```

### CardModifier

```swift
struct FocallyCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.focallySurfaceContainerLowest)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.focallyCardBorder, lineWidth: 0.5)
            )
            .shadow(color: .focallyCardShadow, radius: 2, x: 0, y: 1)
    }
}
```

### ToggleButton (Pill)

```
Width: 32px, Height: 18px
On: bg-primary, circle translated right (14px), white circle (14px)
Off: bg-gray-300 (light) / bg-gray-600 (dark), white circle at left
Transition: 0.2s
```

### SegmentedControl

```
Container: bg-surfaceContainer p-1 rounded-xl
Active: bg-surfaceContainerLowest rounded-lg shadow-sm
Inactive: text-secondary, hover:text-onSurface
Labels: 11px font-medium
Width: 192px (w-48)
```

---

## SF Symbols Mapping (Material → SF)

| Material Symbol | SF Symbol | Context |
|----------------|-----------|---------|
| `timer` | `timer` | Timer tab, pomodoro button |
| `checklist` | `checklist` | Tasks tab |
| `bar_chart` | `chart.bar.fill` / `chart.bar` | Analytics tab |
| `settings` | `gearshape` | Settings tab, settings buttons |
| `history` | `clock.arrow.circlepath` | History button |
| `bolt` (filled) | `bolt.fill` | Focus score, energy |
| `schedule` | `clock` | Estimated end time |
| `notifications_off` (filled) | `moon.fill` | DND active badge |
| `add` | `plus` | Add buttons, FAB |
| `add_task` | `text.badge.plus` | Task input placeholder |
| `pause` | `pause.fill` | Pause button |
| `stop` (filled) | `stop.fill` | Stop/finish button |
| `do_not_disturb_on` | `moon.circle.fill` | DND automation |
| `terminal` | `terminal.fill` | CFPreferences |
| `login` | `arrow.right.circle` | Launch at login |
| `notifications_active` | `bell.fill` | Sound notifications |
| `dock` | `menubar.rectangle` | Menu bar toggle |
| `code` | `chevron.left.forwardslash.chevron.right` | Code task icon |
| `article` | `doc.text` | Documentation task icon |
| `mail` | `envelope` | Email task icon |
| `fitness_center` | `dumbbell` | Exercise task icon |
| `edit` | `pencil` | Edit action |
| `delete` | `trash` | Delete action |
| `sync` (filled) | `arrow.triangle.2.circlepath` | Calendar sync |
| `chevron_left` | `chevron.left` | Calendar nav |
| `chevron_right` | `chevron.right` | Calendar nav |
| `star` | `star.fill` / `star` | Rating |
| `analytics` | `chart.line.uptrend.xyaxis` | Daily stats |
| `workspace_premium` | `trophy.fill` | Flow state badge |
| `warning` | `exclamationmark.triangle` | Permission warning |
| `help` | `questionmark.circle` | Help button |
| `more_horiz` | `ellipsis` | More options |
| `task_alt` | `checkmark.circle.fill` | Predefined tasks header |
| `av_timer` | `timer` | Timer settings header |
| `avg_time` | `hourglass` | Custom session |
| `self_improvement` | `figure.mind.and.body` | Environment (removed) |
| `music_note` | `music.note` | Music (removed) |
| `local_fire_department` | `flame.fill` | Streak indicator |
| `target` | `target` | Menu bar app icon |

---

## Files to Create

### Design System
```
Focally/DesignSystem/
├── FocallyColors.swift          — Color tokens (Asset Catalog references + fallbacks)
├── FocallyTypography.swift      — Font extensions (.focallyDisplay, .focallyH1, etc.)
├── FocallySpacing.swift         — Spacing constants (unit, xs, sm, md, gutter, lg, xl)
├── FocallyRadius.swift          — Border radius constants
├── FocallyTheme.swift           — Theme environment object (light/dark switching)
└── CardModifier.swift           — .focallyCard() ViewModifier
```

### Asset Catalog
```
Focally/Assets.xcassets/
└── Colors/
    ├── focallyPrimary.colorset/        — #0058BC (light) / #ADC6FF (dark)
    ├── focallyOnPrimary.colorset/      — #FFFFFF / #002E69
    ├── focallyPrimaryContainer.colorset/
    ├── focallySurface.colorset/
    ├── focallySurfaceContainerLowest.colorset/
    ├── focallySurfaceContainerLow.colorset/
    ├── focallySurfaceContainer.colorset/
    ├── focallySurfaceContainerHigh.colorset/
    ├── focallySurfaceContainerHighest.colorset/
    ├── focallyOnSurface.colorset/
    ├── focallyOnSurfaceVariant.colorset/
    ├── focallySecondary.colorset/
    ├── focallySecondaryContainer.colorset/
    ├── focallyOnSecondaryContainer.colorset/
    ├── focallyTertiary.colorset/
    ├── focallyTertiaryContainer.colorset/
    ├── focallyOutline.colorset/
    ├── focallyOutlineVariant.colorset/
    ├── focallyError.colorset/
    ├── focallyErrorContainer.colorset/
    ├── focallyBackground.colorset/
    ├── focallyInverseSurface.colorset/
    ├── focallyInverseOnSurface.colorset/
    └── focallyCardBorder.colorset/     — black/5 (light) / white/8 (dark)
```

### Font Bundle
```
Focally/Resources/
├── Inter-Regular.ttf
├── Inter-Medium.ttf
├── Inter-SemiBold.ttf
└── Inter-Bold.ttf
```
Add to `project.yml` under `Focally/targets/Focally/resources`.

### Navigation
```
Focally/Views/Navigation/
├── SidebarView.swift
├── SidebarItemView.swift
├── TopBarView.swift
└── FocallyTab.swift          — Tab enum
```

### Menu Bar
```
Focally/Views/MenuBar/
├── MenuBarDropdownView.swift     — REPLACES FocusMenuView
└── SessionProgressCard.swift     — Active session in dropdown
```

### Timer
```
Focally/Views/Timer/
├── TimerPage.swift               — Container (active vs idle)
├── ActiveFocusView.swift         — Session active: big timer + controls
├── IdleDashboardView.swift       — Session idle: bento grid dashboard
└── TimerControlsView.swift       — Pause/Finish buttons
```

### Schedule
```
Focally/Views/Schedule/
├── SchedulePage.swift
├── WeekCalendarView.swift
├── CalendarDayHeader.swift
├── FocusBlockView.swift
└── CreateFocusBlockSheet.swift
```

### Tasks
```
Focally/Views/Tasks/
├── TasksPage.swift
├── TimerSettingsCard.swift
├── PredefinedTasksList.swift
├── TaskRowView.swift
└── AddTaskSheet.swift
```

### Analytics
```
Focally/Views/Analytics/
├── AnalyticsPage.swift
├── FocusScoreCard.swift
├── AvgSessionDepthCard.swift
├── FocusTrendChart.swift
├── FocusAllocationCard.swift
├── RecentSessionsList.swift
└── SessionRowView.swift
```

### Settings
```
Focally/Views/Settings/
├── SettingsPage.swift
├── GeneralSettingsView.swift
├── AutomationSettingsView.swift
├── IntegrationsSettingsView.swift
├── AppearanceSettingsView.swift
└── AboutSettingsView.swift
```

### Services (new)
```
Focally/Services/
├── AnalyticsService.swift        — Computed metrics from HistoryService
└── ScheduleService.swift         — Focus block CRUD + Calendar sync
```

### Main Window
```
Focally/Views/
├── MainWindow.swift              — Sidebar + TopBar + Content switcher
└── SharedComponents.swift        — ToggleButton, SegmentedControl, etc.
```

### Models (new/modified)
```
Focally/Models/
└── FocusBlock.swift              — Calendar focus block model (for Schedule page)
```

---

## Files to Modify

| File | Change |
|------|--------|
| `Focally/OnItFocusApp.swift` | Replace menu bar popover with MenuBarDropdownView; add main window management (Cmd+Shift+F); theme management |
| `project.yml` | Add all new files to Focally target sources; add font resources |
| `Focally/Views/FocusMenuView.swift` | **DELETE** — replaced by MenuBarDropdownView |
| `Focally/Views/SettingsView.swift` | **DELETE** — replaced by SettingsPage + sub-views |
| `Focally/Views/ActivityInputView.swift` | **DELETE** — replaced by task input in MenuBarDropdownView |

---

## Detailed Code Specifications

### Theme Environment

```swift
import SwiftUI

@Observable
class FocallyTheme {
    var colorScheme: ColorScheme = .light

    var isDark: Bool { colorScheme == .dark }
}

// Environment key
private struct FocallyThemeKey: EnvironmentKey {
    static let defaultValue = FocallyTheme()
}

extension EnvironmentValues {
    var focallyTheme: FocallyTheme {
        get { self[FocallyThemeKey.self] }
        set { self[FocallyThemeKey.self] = newValue }
    }
}
```

### AnalyticsService

```swift
import Observation

@Observable
class AnalyticsService {

    struct FocusScoreData {
        let score: Int          // 0-100
        let delta: Int          // % change vs previous period
        let description: String
    }

    struct TrendDataPoint {
        let day: String         // "MON", "TUE", etc.
        let totalMinutes: Int
    }

    struct CategoryAllocation {
        let name: String
        let hours: Double
        let percentage: Double
        let color: Color
    }

    struct SessionDisplay {
        let id: UUID
        let activity: String
        let category: String
        let startTime: Date
        let endTime: Date
        let durationMinutes: Int
        let rating: Int         // 0-5 stars
    }

    enum TimeRange {
        case weekly
        case monthly
    }

    var selectedRange: TimeRange = .weekly

    private var historyService: HistoryService

    init(historyService: HistoryService) {
        self.historyService = historyService
    }

    func focusScore() -> FocusScoreData { /* sessions completed / planned */ }
    func avgSessionDepth() -> (hours: Int, minutes: Int) { /* average duration */ }
    func trendData() -> [TrendDataPoint] { /* group by day */ }
    func categoryAllocation() -> [CategoryAllocation] { /* group by activity */ }
    func recentSessions(limit: Int = 20) -> [SessionDisplay] { /* from history */ }
}
```

### ScheduleService

```swift
import Observation

struct FocusBlock: Identifiable, Codable {
    let id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var color: BlockColor
    var calendarEventId: String?  // Google Calendar event ID if synced
    var isSynced: Bool

    enum BlockColor: String, Codable, CaseIterable {
        case primary, tertiary, secondary, custom
        var color: Color { /* map to focally colors */ }
    }
}

@Observable
class ScheduleService {
    var blocks: [FocusBlock] = []
    var isLoading = false

    private var calendarService: GoogleCalendarService

    init(calendarService: GoogleCalendarService) {
        self.calendarService = calendarService
    }

    func loadWeek(date: Date) async { /* fetch from Calendar + local */ }
    func createBlock(_ block: FocusBlock) async throws { /* create + sync */ }
    func updateBlock(_ block: FocusBlock) async throws { /* update + sync */ }
    func deleteBlock(id: UUID) async throws { /* delete + sync */ }
}
```

### FocusTrendChart (Swift Charts)

```swift
import Charts

struct FocusTrendChart: View {
    let data: [AnalyticsService.TrendDataPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("Focus Trend")
                    .font(.focallyH2)
                Spacer()
                Text(dateRangeString())
                    .font(.focallyCaption)
                    .foregroundStyle(.focallyOutline)
            }

            Chart(data) { point in
                LineMark(
                    x: .value("Day", point.day),
                    y: .value("Minutes", point.totalMinutes)
                )
                .foregroundStyle(.focallyPrimary)
                .lineStyle(StrokeStyle(lineWidth: 2))

                AreaMark(
                    x: .value("Day", point.day),
                    y: .value("Minutes", point.totalMinutes)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [.focallyPrimary.opacity(0.15), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.focallyOutline)
                }
            }
            .frame(height: 200)
        }
        .focallyCard()
        .padding(24)
    }
}
```

### FocusScoreRing

```swift
struct FocusScoreRing: View {
    let score: Int  // 0-100

    var body: some View {
        ZStack {
            Circle()
                .stroke(.focallySurfaceContainer, lineWidth: 12)
            Circle()
                .trim(from: 0, to: Double(score) / 100.0)
                .stroke(
                    .focallyPrimary,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: score)
            Image(systemName: "bolt.fill")
                .font(.system(size: 32))
                .foregroundStyle(.focallyPrimary)
        }
        .frame(width: 160, height: 160)
    }
}
```

### Star Rating

```swift
struct StarRating: View {
    let rating: Int  // 0-5

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                Image(systemName: index < rating ? "star.fill" : "star")
                    .font(.system(size: 12))
                    .foregroundStyle(
                        index < rating
                            ? .focallyPrimary
                            : .focallyOutline.opacity(0.3)
                    )
            }
        }
    }
}
```

---

## Window Management

### Menu Bar Dropdown
- Triggered by clicking Focally icon in system status bar
- Replaces the current `NSPopover` with `FocusMenuView`
- Width: 320px, auto-height
- Positioned below the menu bar icon
- Closes on click outside

### Main Window
- Opened via Cmd+Shift+F or "Open Focally" from dropdown menu
- Size: 1200×800, resizable, min-size 900×600
- Style: `.titled`, `.closable`, `.resizable`, `.miniaturizable` (NOT fullscreen)
- Title: "Focally"
- Single instance (show existing if already open)

```swift
// In OnItFocusApp.swift
func openMainWindow() {
    if let window = mainWindow, window.isVisible {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return
    }

    let contentView = MainWindow()
        .environment(timerService)
        .environment(dndService)
        .environment(slackService)
        .environment(calendarService)
        .environment(historyService)
        .environment(analyticsService)
        .environment(scheduleService)
        .environment(focallyTheme)

    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
        styleMask: [.titled, .closable, .resizable, .miniaturizable],
        backing: .buffered,
        defer: false
    )
    window.title = "Focally"
    window.contentView = NSHostingView(rootView: contentView)
    window.center()
    window.minSize = NSSize(width: 900, height: 600)
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    mainWindow = window
}
```

---

## Dark Mode Implementation

### Strategy
1. Use **Asset Catalog color sets** with light/dark variants for all semantic colors
2. Use `@Environment(\.colorScheme)` for any runtime logic
3. SwiftUI automatically resolves asset catalog colors based on system appearance
4. For non-asset colors (gradients, overlays), use conditional values:

```swift
// Glass effects adapt to theme
func glassSidebarBackground(for scheme: ColorScheme) -> some View {
    Group {
        if scheme == .dark {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color(hex: "121317").opacity(0.3))
        } else {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color(hex: "F3F3F4").opacity(0.2))
        }
    }
}
```

### Dark Mode Specific Adjustments
- Cards: No shadow in dark mode, use `border white/8` instead
- Sidebar: Vibrant blur with dark overlay
- Inputs: `bg-white/5` instead of `bg-black/5`
- Text: All surface colors automatically switch via asset catalog
- Charts: Primary color switches from `#0058BC` to `#ADC6FF`
- Progress bars: Use adaptive primary color
- Calendar grid lines: `border-white/[0.03]` instead of `border-black/[0.03]`
- Toggle pills: `bg-gray-600` (off) in dark mode

---

## Dependencies
- **TASK-016** (@Observable migration) — All services and views must use `@Observable`
- **TASK-018** (HistoryService startTime fix) — Analytics needs accurate start times

## Criterios de Aceptación

### Design System
- [ ] All color tokens in Asset Catalog with light/dark variants
- [ ] Inter font bundled and registered as custom font
- [ ] Typography extensions for all 8 roles
- [ ] `.focallyCard()` modifier produces consistent card styling
- [ ] ToggleButton, SegmentedControl shared components work

### Menu Bar
- [ ] Menu bar icon shows timer icon with countdown when active
- [ ] Click opens 320px dropdown with glass effect
- [ ] Dropdown has task input, Start Pomodoro, Custom Session buttons
- [ ] Active session card shows with progress bar when session running
- [ ] Footer shows daily stats
- [ ] Old FocusMenuView is removed

### Timer Page
- [ ] Active session shows centered 160px timer with pause/finish controls
- [ ] Idle state shows bento dashboard with up-next, today's flow, focus mode
- [ ] FAB visible in idle state for quick session start
- [ ] No Energy Level or Music cards

### Schedule Page
- [ ] Week calendar grid renders with time rows and day columns
- [ ] Focus blocks positioned correctly based on time/duration
- [ ] Current day highlighted
- [ ] Current session block has elevated style
- [ ] Click empty slot opens creation sheet
- [ ] Click existing block opens edit sheet
- [ ] Google Calendar sync status shown
- [ ] Week/Month/Day view toggle works

### Tasks Page
- [ ] Timer settings card with 3 duration inputs
- [ ] Auto-start breaks toggle
- [ ] Predefined tasks list with CRUD
- [ ] Add task sheet works
- [ ] Smart Templates section visible but disabled

### Analytics Page
- [ ] Focus Score card with ring + delta
- [ ] Avg Session Depth with progress bar
- [ ] Focus Trend chart using Swift Charts
- [ ] Focus Allocation with category bars + percentages
- [ ] Recent Sessions list with date badges, durations, star ratings
- [ ] Weekly/Monthly toggle switches data

### Settings Page
- [ ] Sub-navigation between General, Automation, Integrations, Appearance, About
- [ ] General: launch at login, sound notifications with picker, menu bar toggle
- [ ] Automation: DND toggle, CFPreferences toggle with warning
- [ ] Integrations: Slack status, Google Calendar connection
- [ ] Appearance: Light/Dark/System theme picker
- [ ] About: version, build number
- [ ] Save Changes / Reset to Default buttons
- [ ] Old SettingsView removed

### Dark Mode
- [ ] All pages render correctly in dark mode
- [ ] Colors switch via Asset Catalog automatically
- [ ] Glass effects adapt (blur + dark overlay)
- [ ] Cards use border instead of shadow in dark
- [ ] Calendar grid lines adapt
- [ ] Charts use dark-mode primary color

### Window Management
- [ ] Main window opens at 1200×800 from menu bar dropdown or Cmd+Shift+F
- [ ] Single instance (no duplicate windows)
- [ ] Sidebar navigation switches between all 5 tabs
- [ ] Timer tab selected by default
- [ ] Build succeeds

## Constraints
- **NO** external packages or SPM dependencies
- **NO** push or commits
- **NO** modificar FocusTimerService, HistoryService, DNDService, SlackService, SoundPlayerService, NotificationService internal logic
- **MANTENER** all existing service APIs unchanged
- Font: Bundle Inter OR fallback to system font
- Charts: Swift Charts only (macOS 14+)
- Calendar: Google Calendar API for sync (existing GoogleCalendarService)
- Remove: Energy Level card, Music card (per user request)
- Profile: Show "Eliab" with "E" initial, no Pro/License text

## Fuera de Scope
- Session rating input (stars are display-only)
- Export data functionality (button shown, non-functional)
- AI Smart Templates (shell shown, disabled)
- Cloud Sync feature (promo card shown, non-functional)
- Custom accent colors (only default blue)
- n8n integration UI (future)
- iPad/iOS support (macOS only)

---
## Result ← Codex llena esta sección

- Status: [done | failed | blocked]
- Resumen:
- Archivos modificados:
- Archivos creados:
- Archivos eliminados:
- Tests:
- Notas:
- Bloqueado por: [solo si blocked]

# TASK-039: Metrics Filtering and Focus Mode Classification

## Objective

Implement filtering capabilities in metrics views and add focus mode classification breakdowns to show time spent by mode type per day/week/month.

## Current State Analysis

**Files Modified:**
- `Focally/Models/FocusSessionRecord.swift` — already has `modeType` and `modeID`
- `Focally/Models/FocusMode.swift` — already has `FocusModeType` enum (focusTime, meeting, inbox, custom)
- `Focally/Services/FocusMetricsService.swift` — aggregates metrics but lacks mode type breakdown
- `Focally/Views/Metrics/DailyMetricsView.swift` — shows daily metrics, no filtering
- `Focally/Views/Metrics/WeeklyMetricsView.swift` — shows weekly metrics, no day-of-week filtering
- `Focally/Views/Metrics/MonthlyMetricsView.swift` — shows monthly metrics, no day-of-month filtering

**Existing Metric Types:**
```swift
struct DailyMetrics {
    let pomodorosCompleted: Int
    let meetingTime: TimeInterval
    let totalFocusTime: TimeInterval
    // ❌ Missing: breakdown by mode type
}

struct WeeklyMetrics {
    let pomodorosCompleted: Int
    let meetingTime: TimeInterval
    let totalFocusTime: TimeInterval
    let daysWithData: Int
    // ❌ Missing: breakdown by mode type
}

struct MonthlyMetrics {
    let pomodorosCompleted: Int
    let meetingTime: TimeInterval
    let totalFocusTime: TimeInterval
    let weeksWithData: Int
    // ❌ Missing: breakdown by mode type
}
```

**Problems:**
1. No filtering UI to select specific days of week (e.g., "Show only Mondays") in WeeklyMetricsView
2. No filtering UI to select specific days of month (e.g., "Show 1st, 15th, last day") in MonthlyMetricsView
3. Metrics structs aggregate all sessions together without mode type breakdown
4. No UI to toggle filter by focus mode type (Focus Time vs Meeting vs Inbox vs Custom)
5. FocusMetricsService aggregation methods don't compute per-type breakdowns

## Tasks

### Task 1: Update Metric Structs with Mode Type Breakdown

Add mode type breakdown properties to all metric structs in `Focally/Services/FocusMetricsService.swift`:

```swift
struct DailyMetrics: Codable, Equatable {
    let date: Date
    let pomodorosCompleted: Int
    let meetingTime: TimeInterval
    let totalFocusTime: TimeInterval
    
    // ✅ ADD: Mode type breakdown (duration in seconds)
    let focusTimeDuration: TimeInterval
    let meetingDuration: TimeInterval
    let inboxDuration: TimeInterval
    let customDuration: TimeInterval
    
    var focusTimeDurationFormatted: String {
        DailyMetrics.formatDuration(focusTimeDuration)
    }
    
    var meetingDurationFormatted: String {
        DailyMetrics.formatDuration(meetingDuration)
    }
    
    var inboxDurationFormatted: String {
        DailyMetrics.formatDuration(inboxDuration)
    }
    
    var customDurationFormatted: String {
        DailyMetrics.formatDuration(customDuration)
    }
    
    // ... existing formatDuration method
}

struct WeeklyMetrics: Codable, Equatable {
    let weekStartDate: Date
    let pomodorosCompleted: Int
    let meetingTime: TimeInterval
    let totalFocusTime: TimeInterval
    let daysWithData: Int
    
    // ✅ ADD: Mode type breakdown (duration in seconds)
    let focusTimeDuration: TimeInterval
    let meetingDuration: TimeInterval
    let inboxDuration: TimeInterval
    let customDuration: TimeInterval
    
    var focusTimeDurationFormatted: String { DailyMetrics.formatDuration(focusTimeDuration) }
    var meetingDurationFormatted: String { DailyMetrics.formatDuration(meetingDuration) }
    var inboxDurationFormatted: String { DailyMetrics.formatDuration(inboxDuration) }
    var customDurationFormatted: String { DailyMetrics.formatDuration(customDuration) }
    
    // ... existing avgDailyFocusTime, avgDailyFocusTimeFormatted
}

struct MonthlyMetrics: Codable, Equatable {
    let monthStartDate: Date
    let pomodorosCompleted: Int
    let meetingTime: TimeInterval
    let totalFocusTime: TimeInterval
    let weeksWithData: Int
    
    // ✅ ADD: Mode type breakdown (duration in seconds)
    let focusTimeDuration: TimeInterval
    let meetingDuration: TimeInterval
    let inboxDuration: TimeInterval
    let customDuration: TimeInterval
    
    var focusTimeDurationFormatted: String { DailyMetrics.formatDuration(focusTimeDuration) }
    var meetingDurationFormatted: String { DailyMetrics.formatDuration(meetingDuration) }
    var inboxDurationFormatted: String { DailyMetrics.formatDuration(inboxDuration) }
    var customDurationFormatted: String { DailyMetrics.formatDuration(customDuration) }
    
    // ... existing formatted properties
}
```

### Task 2: Update FocusMetricsService Aggregation Methods

Modify aggregation methods in `Focally/Services/FocusMetricsService.swift` to compute mode type breakdowns:

**DailyMetrics.getDailyMetrics(for:)** — add per-type computation:
```swift
let pomodoros = dayRecords.compactMap(\.pomodorosCompleted).reduce(0, +)
let meetingTime = dayRecords.filter { $0.isMeeting }.reduce(0) { $0 + $1.duration }
let totalFocus = dayRecords.reduce(0) { $0 + $1.duration }

// ✅ ADD: Per-type duration breakdown
let focusTimeDuration = dayRecords.filter { $0.modeType == .focusTime }.reduce(0) { $0 + $1.duration }
let meetingDuration = dayRecords.filter { $0.modeType == .meeting }.reduce(0) { $0 + $1.duration }
let inboxDuration = dayRecords.filter { $0.modeType == .inbox }.reduce(0) { $0 + $1.duration }
let customDuration = dayRecords.filter { $0.modeType == .custom }.reduce(0) { $0 + $1.duration }

return DailyMetrics(
    date: targetDay,
    pomodorosCompleted: pomodoros,
    meetingTime: meetingTime,
    totalFocusTime: totalFocus,
    focusTimeDuration: focusTimeDuration,      // ✅ ADD
    meetingDuration: meetingDuration,          // ✅ ADD
    inboxDuration: inboxDuration,              // ✅ ADD
    customDuration: customDuration             // ✅ ADD
)
```

**WeeklyMetrics.getWeeklyMetrics(for:)** — add per-type computation (same pattern as daily).

**MonthlyMetrics.getMonthlyMetrics(for:)** — add per-type computation (same pattern as daily).

### Task 3: Add Day-of-Week Filtering Support

Create new method in `Focally/Services/FocusMetricsService.swift`:

```swift
/// Returns weekly metrics filtered to specific days of week (e.g., only Mondays).
/// - Parameters:
///   - date: Anchor date to determine the week
///   - dayOfWeeks: Set of weekday components (1=Sunday, 2=Monday, ..., 7=Saturday)
/// - Returns: Weekly metrics for matching days, or nil if no data
func getWeeklyMetrics(for date: Date, dayOfWeeks: Set<Int>) -> WeeklyMetrics? {
    let calendar = isoCalendar
    guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else {
        return nil
    }
    
    // Filter records by week AND matching days of week
    let weekRecords = records.filter { record in
        let inWeek = weekInterval.contains(record.startTime)
        let weekday = calendar.component(.weekday, from: record.startTime)
        let matchesDayOfWeek = dayOfWeeks.isEmpty || dayOfWeeks.contains(weekday)
        return inWeek && matchesDayOfWeek
    }
    
    guard !weekRecords.isEmpty else { return nil }
    
    // ... same aggregation logic as getWeeklyMetrics(for:) with per-type breakdown
}
```

**NOTE:** `dayOfWeeks.isEmpty` means "show all days" (no filter applied).

### Task 4: Add Day-of-Month Filtering Support

Create new method in `Focally/Services/FocusMetricsService.swift`:

```swift
/// Returns monthly metrics filtered to specific days of month (e.g., 1st, 15th, last day).
/// - Parameters:
///   - date: Anchor date to determine the month
///   - daysOfMonth: Set of day numbers (1-31), or 0 for "last day of month"
/// - Returns: Monthly metrics for matching days, or nil if no data
func getMonthlyMetrics(for date: Date, daysOfMonth: Set<Int>) -> MonthlyMetrics? {
    let calendar = Calendar.current
    let monthInterval = calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, end: date)
    
    // Filter records by month AND matching days of month
    let monthRecords = records.filter { record in
        let inMonth = monthInterval.contains(record.startTime)
        let day = calendar.component(.day, from: record.startTime)
        let lastDay = calendar.range(of: .day, in: .month, for: date)?.count ?? day
        let isLastDay = (day == lastDay && daysOfMonth.contains(0))
        let matchesDayOfMonth = daysOfMonth.isEmpty || daysOfMonth.contains(day) || isLastDay
        return inMonth && matchesDayOfMonth
    }
    
    guard !monthRecords.isEmpty else { return nil }
    
    // ... same aggregation logic as getMonthlyMetrics(for:) with per-type breakdown
}
```

**NOTE:** `daysOfMonth.isEmpty` means "show all days" (no filter applied). Use `0` to represent "last day of month".

### Task 5: Update WeeklyMetricsView with Day-of-Week Filter

Modify `Focally/Views/Metrics/WeeklyMetricsView.swift`:

**Add state:**
```swift
@State private var selectedDayOfWeeks: Set<Int> = []  // Empty = all days
@State private var showDayOfWeekFilter: Bool = false
```

**Add day-of-week picker overlay:**
```swift
// After the week selector HStack, before LocalizedText("metrics_weekly_title")
Button(action: { showDayOfWeekFilter.toggle() }) {
    HStack(spacing: FocallySpacing.extraSmall) {
        Image(systemName: selectedDayOfWeeks.isEmpty ? "calendar" : "calendar.badge.checkmark")
            .font(.system(size: 14))
        Text(selectedDayOfWeeks.isEmpty ? AppLanguage.shared.localizedString("metrics_filter_all_days") : AppLanguage.shared.localizedString("metrics_filter_days"))
    }
    .font(.focallyBody)
    .foregroundStyle(Color.focallyOnSurfaceVariant)
}
.buttonStyle(.plain)
.sheet(isPresented: $showDayOfWeekFilter) {
    DayOfWeekFilterSheet(selectedDays: $selectedDayOfWeeks)
}
```

**Update metrics computed property:**
```swift
private var metrics: WeeklyMetrics? {
    if selectedDayOfWeeks.isEmpty {
        return FocusMetricsService.shared.getWeeklyMetrics(for: weekAnchorDate)
    } else {
        return FocusMetricsService.shared.getWeeklyMetrics(for: weekAnchorDate, dayOfWeeks: selectedDayOfWeeks)
    }
}
```

**Create new view file: `Focally/Views/Metrics/DayOfWeekFilterSheet.swift`:**
```swift
import SwiftUI

struct DayOfWeekFilterSheet: View {
    @Binding var selectedDays: Set<Int>
    @Environment(\.dismiss) private var dismiss
    
    private let weekDays: [(weekday: Int, label: String)] = [
        (1, "S"), (2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S")
    ]
    
    var body: some View {
        VStack(spacing: FocallySpacing.large) {
            // Header
            Text(AppLanguage.shared.localizedString("metrics_filter_days_title"))
                .font(.focallyH2)
                .foregroundStyle(Color.focallyOnSurface)
            
            // Day of week selector (7 buttons in a row)
            HStack(spacing: FocallySpacing.medium) {
                ForEach(weekDays, id: \.weekday) { day in
                    Button(action: {
                        if selectedDays.contains(day.weekday) {
                            selectedDays.remove(day.weekday)
                        } else {
                            selectedDays.insert(day.weekday)
                        }
                    }) {
                        Text(day.label)
                            .font(.focallyBodyBold)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(selectedDays.contains(day.weekday) ? Color.focallyPrimary : Color.focallySurfaceContainer)
                            )
                            .foregroundStyle(selectedDays.contains(day.weekday) ? .white : Color.focallyOnSurface)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, FocallySpacing.large)
            
            // Clear all button
            Button(action: { selectedDays.removeAll() }) {
                Text(AppLanguage.shared.localizedString("metrics_filter_clear"))
                    .font(.focallyBody)
                    .foregroundStyle(Color.focallyPrimary)
            }
            .disabled(selectedDays.isEmpty)
            .buttonStyle(.plain)
            
            Spacer()
            
            // Close button
            Button(action: { dismiss() }) {
                Text(AppLanguage.shared.localizedString("metrics_filter_done"))
                    .font(.focallyBodyBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FocallySpacing.medium)
                    .background(Color.focallyPrimary)
                    .cornerRadius(FocallyRadius.medium)
            }
            .buttonStyle(.plain)
        }
        .padding(FocallySpacing.large)
        .frame(width: 400, height: 300)
        .background(Color.focallyBackground)
    }
}
```

### Task 6: Update MonthlyMetricsView with Day-of-Month Filter

Modify `Focally/Views/Metrics/MonthlyMetricsView.swift`:

**Add state:**
```swift
@State private var selectedDaysOfMonth: Set<Int> = []  // Empty = all days
@State private var showDayOfMonthFilter: Bool = false
```

**Add day-of-month filter button** (same pattern as WeeklyMetricsView):
```swift
Button(action: { showDayOfMonthFilter.toggle() }) {
    HStack(spacing: FocallySpacing.extraSmall) {
        Image(systemName: selectedDaysOfMonth.isEmpty ? "calendar" : "calendar.badge.checkmark")
            .font(.system(size: 14))
        Text(selectedDaysOfMonth.isEmpty ? AppLanguage.shared.localizedString("metrics_filter_all_days") : AppLanguage.shared.localizedString("metrics_filter_days"))
    }
    .font(.focallyBody)
    .foregroundStyle(Color.focallyOnSurfaceVariant)
}
.buttonStyle(.plain)
.sheet(isPresented: $showDayOfMonthFilter) {
    DayOfMonthFilterSheet(selectedDays: $selectedDaysOfMonth)
}
```

**Update metrics computed property:**
```swift
private var metrics: MonthlyMetrics? {
    if selectedDaysOfMonth.isEmpty {
        return FocusMetricsService.shared.getMonthlyMetrics(for: selectedMonth)
    } else {
        return FocusMetricsService.shared.getMonthlyMetrics(for: selectedMonth, daysOfMonth: selectedDaysOfMonth)
    }
}
```

**Create new view file: `Focally/Views/Metrics/DayOfMonthFilterSheet.swift`:**
```swift
import SwiftUI

struct DayOfMonthFilterSheet: View {
    @Binding var selectedDays: Set<Int>
    @Environment(\.dismiss) private var dismiss
    
    private let daysInMonth = Array(1...31)
    
    var body: some View {
        VStack(spacing: FocallySpacing.large) {
            // Header
            Text(AppLanguage.shared.localizedString("metrics_filter_days_title"))
                .font(.focallyH2)
                .foregroundStyle(Color.focallyOnSurface)
            
            // Day of month grid (7 columns × 5 rows)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: FocallySpacing.small) {
                ForEach(daysInMonth, id: \.self) { day in
                    Button(action: {
                        if selectedDays.contains(day) {
                            selectedDays.remove(day)
                        } else {
                            selectedDays.insert(day)
                        }
                    }) {
                        Text("\(day)")
                            .font(.focallyBodyBold)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(selectedDays.contains(day) ? Color.focallyPrimary : Color.focallySurfaceContainer)
                            )
                            .foregroundStyle(selectedDays.contains(day) ? .white : Color.focallyOnSurface)
                    }
                    .buttonStyle(.plain)
                }
                
                // Last day of month button (represented by 0 in backend)
                Button(action: {
                    if selectedDays.contains(0) {
                        selectedDays.remove(0)
                    } else {
                        selectedDays.insert(0)
                    }
                }) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(selectedDays.contains(0) ? Color.focallyPrimary : Color.focallySurfaceContainer)
                        )
                        .foregroundStyle(selectedDays.contains(0) ? .white : Color.focallyOnSurface)
                }
                .buttonStyle(.plain)
                .help(AppLanguage.shared.localizedString("metrics_filter_last_day"))
            }
            .padding(.horizontal, FocallySpacing.large)
            
            // Clear all button
            Button(action: { selectedDays.removeAll() }) {
                Text(AppLanguage.shared.localizedString("metrics_filter_clear"))
                    .font(.focallyBody)
                    .foregroundStyle(Color.focallyPrimary)
            }
            .disabled(selectedDays.isEmpty)
            .buttonStyle(.plain)
            
            Spacer()
            
            // Close button
            Button(action: { dismiss() }) {
                Text(AppLanguage.shared.localizedString("metrics_filter_done"))
                    .font(.focallyBodyBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FocallySpacing.medium)
                    .background(Color.focallyPrimary)
                    .cornerRadius(FocallyRadius.medium)
            }
            .buttonStyle(.plain)
        }
        .padding(FocallySpacing.large)
        .frame(width: 420, height: 420)
        .background(Color.focallyBackground)
    }
}
```

### Task 7: Add Focus Mode Type Breakdown Display

Add mode type breakdown cards to **all three metrics views** (DailyMetricsView, WeeklyMetricsView, MonthlyMetricsView):

**After the existing 3 MetricCards (pomodoros, meeting time, focus time), add a 4th card:**
```swift
MetricCard(
    icon: "brain.head.profile.fill",
    title: "metrics_focus_time_type",  // NEW localization key
    value: metrics.focusTimeDurationFormatted
)
```

**For WeeklyMetricsView and MonthlyMetricsView, also add breakdown cards for Meeting, Inbox, Custom:**
```swift
// After focusTimeDuration card
MetricCard(
    icon: "person.2.fill",
    title: "metrics_meeting_type",  // NEW localization key
    value: metrics.meetingDurationFormatted
)
MetricCard(
    icon: "tray.fill",
    title: "metrics_inbox_type",  // NEW localization key
    value: metrics.inboxDurationFormatted
)
MetricCard(
    icon: "star.fill",
    title: "metrics_custom_type",  // NEW localization key
    value: metrics.customDurationFormatted
)
```

**NOTE:** DailyMetricsView only needs 1 extra card (focusTimeType) since it already shows meetingTime separately. WeeklyMetricsView and MonthlyMetricsView need 4 extra cards to show all 4 types.

**Adjust grid layout for more cards:**

- **DailyMetricsView:** Change from 3 columns to 2 columns (4 cards total):
  ```swift
  LazyVGrid(columns: [
      GridItem(.flexible(), spacing: FocallySpacing.medium),
      GridItem(.flexible(), spacing: FocallySpacing.medium),
  ], spacing: FocallySpacing.medium) {
      // 4 cards: pomodoros, meeting time, total focus time, focus time type
  }
  ```

- **WeeklyMetricsView and MonthlyMetricsView:** Change from 3 columns to 2 columns (7 cards total):
  ```swift
  LazyVGrid(columns: [
      GridItem(.flexible(), spacing: FocallySpacing.medium),
      GridItem(.flexible(), spacing: FocallySpacing.medium),
  ], spacing: FocallySpacing.medium) {
      // 7 cards: pomodoros, meeting time, avg/total focus time, + 4 type breakdown cards
  }
  ```

## UI/UX Requirements

1. **Day-of-Week Filter Sheet:**
   - 7 circular buttons in a horizontal row (S M T W T F S)
   - Selected state: filled with primary color, white text
   - Unselected state: surface container, on-surface text
   - Clear all button below the row (disabled when no selection)
   - Done button at bottom (closes sheet)

2. **Day-of-Month Filter Sheet:**
   - 7×5 grid of circular buttons (1-31 + last day icon)
   - Last day represented by calendar.badge.exclamationmark icon
   - Same selection states as day-of-week sheet
   - Clear all + Done buttons

3. **Filter Badge:**
   - When filter is active: calendar.badge.checkmark icon + "Filter Days" text
   - When filter is inactive (empty set): calendar icon + "All Days" text
   - Same style for both weekly and monthly views

4. **Mode Type Breakdown Cards:**
   - Use distinct icons for each type:
     - Focus Time: brain.head.profile.fill
     - Meeting: person.2.fill
     - Inbox: tray.fill
     - Custom: star.fill
   - Use localized titles (EN/ES/PT)
   - Format duration with formatDuration helper (already exists)

5. **Grid Layout:**
   - Daily: 2 columns × 2 rows (4 cards)
   - Weekly: 2 columns × 4 rows (7 cards, last row has 1 card)
   - Monthly: 2 columns × 4 rows (7 cards, last row has 1 card)

## Testing

**Unit Tests:**
- Test `FocusMetricsService.getWeeklyMetrics(for:dayOfWeeks:)` with various filter sets
- Test `FocusMetricsService.getMonthlyMetrics(for:daysOfMonth:)` with various filter sets
- Test per-type duration aggregation in all three methods

**Integration Tests:**
- Verify DailyMetrics breakdown matches record.modeType classification
- Verify WeeklyMetrics breakdown with day-of-week filter
- Verify MonthlyMetrics breakdown with day-of-month filter

**Manual Testing:**
1. Open DailyMetricsView → verify 4 cards show correctly (new focus time type card)
2. Open WeeklyMetricsView → verify day-of-week filter button works → select Monday only → verify metrics update
3. Open MonthlyMetricsView → verify day-of-month filter button works → select 1st, 15th, last day → verify metrics update
4. Verify all mode type breakdown cards sum to total focus time
5. Test localization (EN/ES/PT) for all new strings

## Breaking Changes

**None** — all changes are additive:
- New properties on metric structs are stored via UserDefaults (Codable)
- New aggregation methods don't replace existing ones
- New filter sheets don't affect existing views

**Data Migration:** None needed — UserDefaults auto-migrates Codable structs when new fields are added (missing fields default to 0/false/nil).

## Notes

1. **Empty Filter Sets:** Empty `selectedDayOfWeeks` and `selectedDaysOfMonth` mean "show all days" — backend methods should treat empty set as no filter.

2. **Last Day of Month:** Represented by `0` in `daysOfMonth` set. Backend should detect "last day" by comparing record.day to last day of target month.

3. **Localization:** Add new keys to all 3 language files (en.lproj/Localizable.strings, es.lproj/Localizable.strings, pt.lproj/Localizable.strings):
   - metrics_filter_all_days
   - metrics_filter_days
   - metrics_filter_days_title
   - metrics_filter_clear
   - metrics_filter_done
   - metrics_filter_last_day
   - metrics_focus_time_type
   - metrics_meeting_type
   - metrics_inbox_type
   - metrics_custom_type

4. **Performance:** Filter operations use `.filter()` on records array — acceptable for maxRecords=5000. No indexing needed for MVP.

## Dependencies

- FocusModeType enum already exists in FocusMode.swift
- FocusSessionRecord already has modeType property
- No new external dependencies required

## Acceptance Criteria

- [x] DailyMetrics has 4 new properties (focusTimeDuration, meetingDuration, inboxDuration, customDuration)
- [x] WeeklyMetrics has 4 new properties (focusTimeDuration, meetingDuration, inboxDuration, customDuration)
- [x] MonthlyMetrics has 4 new properties (focusTimeDuration, meetingDuration, inboxDuration, customDuration)
- [x] FocusMetricsService.getWeeklyMetrics(for:dayOfWeeks:) filters by day of week
- [x] FocusMetricsService.getMonthlyMetrics(for:daysOfMonth:) filters by day of month (including last day)
- [x] WeeklyMetricsView shows day-of-week filter button → opens DayOfWeekFilterSheet
- [x] MonthlyMetricsView shows day-of-month filter button → opens DayOfMonthFilterSheet
- [x] DailyMetricsView shows 4 cards (2×2 grid)
- [x] WeeklyMetricsView shows 7 cards (2×4 grid) including 4 mode type breakdown cards
- [x] MonthlyMetricsView shows 7 cards (2×4 grid) including 4 mode type breakdown cards
- [x] All new strings localized in EN/ES/PT
- [x] Build SUCCEEDED
- [x] Tests SUCCEEDED (34 tests)

## Effort Breakdown

| Task | Estimated Time |
|------|----------------|
| Task 1: Update metric structs | 30 min |
| Task 2: Update aggregation methods | 45 min |
| Task 3: Add day-of-week filtering | 30 min |
| Task 4: Add day-of-month filtering | 30 min |
| Task 5: Update WeeklyMetricsView | 45 min |
| Task 6: Update MonthlyMetricsView | 45 min |
| Task 7: Add mode type breakdown cards | 45 min |
| Localization strings | 30 min |
| Testing | 60 min |
| **Total** | **6 hours** |

## References

- Focally skill: `skills/software-development/focally/SKILL.md`
- Metrics reference: `docs/references/v0.9.2-nexus-bug-fixes.md` (MonthlyMetrics navigation)
- Localization guide: `skills/software-development/focally/references/localization-i18n.md`
- Design tokens: `Focally/DesignTokens/` (spacing, radius, colors)
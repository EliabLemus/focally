# TASK-014: Add Session History Tab in Main Menu

## Status: TODO

## Date: 2026-05-01

## Objective
Add a "Today" section at the bottom of the FocusMenuView popover showing today's completed focus sessions. Uses the `HistoryService` from TASK-011.

## Files to Modify
- `Focally/Views/FocusMenuView.swift` — add history section
- `Focally/OnItFocusApp.swift` — inject HistoryService into popover

## Detailed Specification

### FocusMenuView.swift

Add a new section at the bottom of the popover (below calendar section):

```swift
// MARK: - Today's History
private var historySection: some View {
    VStack(alignment: .leading, spacing: 8) {
        HStack {
            Image(systemName: "chart.bar")
            Text("Today")
                .font(.caption)
                .fontWeight(.semibold)
            
            Spacer()
            
            Text("\(historyService.sessionCountToday()) sessions · \(historyService.totalFocusMinutesToday())m focus")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        
        if todaySessions.isEmpty {
            Text("No sessions completed yet")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 6) {
                ForEach(todaySessions) { session in
                    HStack(spacing: 8) {
                        Text(session.emoji)
                            .font(.caption)
                        Text(session.activity)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text("\(session.durationMinutes)m")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }
    .padding(.horizontal, 20)
}
```

Add to `FocusMenuView`:
- `@ObservedObject var historyService: HistoryService`
- `@State private var todaySessions: [HistoryService.SessionEntry] = []`
- `onAppear` refresh: `todaySessions = historyService.loadTodaySessions()`
- Observe `NotificationCenter` for `.focusSessionEnded` to reload sessions

### OnItFocusApp.swift

Add `historyService` to `FocusMenuHost`:
```swift
struct FocusMenuHost: View {
    @ObservedObject var timerService: FocusTimerService
    @ObservedObject var dndService: DNDService
    @ObservedObject var calendarService: GoogleCalendarService
    @ObservedObject var historyService: HistoryService
    
    var body: some View {
        FocusMenuView()
            .environmentObject(timerService)
            .environmentObject(dndService)
            .environmentObject(calendarService)
            .environmentObject(historyService)
    }
}
```

And pass it from AppDelegate:
```swift
let historyService = HistoryService.shared
// ... in FocusMenuHost init:
FocusMenuHost(
    timerService: timerService,
    dndService: dndService,
    calendarService: calendarService,
    historyService: historyService
)
```

### Layout

The history section should only show when there are completed sessions today (hide if empty to save space). Position it after the calendar section, before any meeting warning.

## Acceptance Criteria
- [ ] History section shows at bottom of popover when sessions exist
- [ ] Shows session count and total focus minutes
- [ ] Lists each session with emoji, name, and duration
- [ ] Updates after completing a session
- [ ] Hidden when no sessions exist
- [ ] Build succeeds

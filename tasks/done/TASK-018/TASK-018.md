# TASK-018: Fix HistoryService startTime Tracking

## Status: TODO

## Date: 2026-05-01

## Objective
`HistoryService.SessionEntry` always has `startTime == endTime` because both are set to `Date()` at the moment of recording (end of session). The start time should be captured when the session begins, not when it ends.

## Files to Modify
- `Focally/Services/HistoryService.swift`
- `Focally/Services/FocusTimerService.swift`

## Problem

Current code in `HistoryService.recordWorkSession`:
```swift
let entry = SessionEntry(
    id: UUID(),
    activity: activity,
    emoji: emoji,
    durationMinutes: durationMinutes,
    startTime: today,   // Date() at recording time
    endTime: today,     // same Date()
    round: round
)
```

## Detailed Changes

### FocusTimerService — Track Session Start Time

Add a property to track when the current work session started:

```swift
// Add to FocusTimerService properties
private var sessionStartTime: Date = Date()
```

In `startWorkSession()`:
```swift
func startWorkSession(activity: String, emoji: String, durationMinutes workMins: Int) {
    sessionStartTime = Date()  // ← ADD THIS
    currentActivity = activity
    // ... rest stays the same
}
```

In `handlePhaseComplete()` where the session is recorded:
```swift
case .work:
    let endTime = Date()
    historyService.recordWorkSession(
        activity: currentActivity,
        emoji: currentEmoji,
        durationMinutes: workDurationMinutes,
        round: currentRound,
        startTime: sessionStartTime,  // ← ADD THIS
        endTime: endTime              // ← ADD THIS
    )
```

### HistoryService — Update recordWorkSession signature

```swift
func recordWorkSession(
    activity: String, 
    emoji: String, 
    durationMinutes: Int, 
    round: Int,
    startTime: Date,   // ← NEW PARAMETER
    endTime: Date      // ← NEW PARAMETER
) {
    // ... existing file discovery code ...
    
    let entry = SessionEntry(
        id: UUID(),
        activity: activity,
        emoji: emoji,
        durationMinutes: durationMinutes,
        startTime: startTime,   // ← USE PARAMETER
        endTime: endTime,       // ← USE PARAMETER
        round: round
    )
    
    // ... rest stays the same
}
```

### HistoryService.SessionEntry — Add computed display property

```swift
struct SessionEntry: Codable, Identifiable {
    let id: UUID
    let activity: String
    let emoji: String
    let durationMinutes: Int
    let startTime: Date
    let endTime: Date
    let round: Int
    
    // ← NEW: Display-friendly time range
    var timeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startTime)) – \(formatter.string(from: endTime))"
    }
}
```

### FocusMenuView — Show time range in history section

Update `historySection` to show the time range:

```swift
ForEach(todaySessions) { session in
    HStack(spacing: 8) {
        Text(session.emoji)
            .font(.caption)
        Text(session.activity)
            .font(.caption)
            .lineLimit(1)
        Spacer()
        Text(session.timeRange)  // ← Changed from "\(session.durationMinutes)m"
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
    // ...
}
```

## Acceptance Criteria
- [ ] `recordWorkSession` accepts `startTime` and `endTime` parameters
- [ ] `FocusTimerService` records `sessionStartTime` when work starts
- [ ] `SessionEntry.startTime` != `endTime` (start is earlier)
- [ ] History section in menu shows actual time range
- [ ] Existing history files still load (backward compatible — old entries have same startTime/endTime)
- [ ] Build succeeds

## Priority
**v0.5.1** — Bug fix, small scope, no breaking changes

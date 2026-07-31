# Calendar - Pomodoro Coexistence Design

**Status:** Draft 2026-07-27
**Problem:** Calendar events don't interact with Focally's pomodoro/states

---

## Current State

### Integration Present
- `CalendarSlackIntegrationService` reads EventKit events (30s poll)
- Detects video calls (meet.google.com, zoom.us, teams.microsoft.com, webex.com)
- Automates: Slack status + DND for meetings
- **No interaction with:** `FocusTimerService`, `FocusModeStore`, UI

### Missing Link
```
Calendar (EventKit)  ←→  CalendarSlackIntegrationService  ←→  Slack/DND
                                                              ↑
                                                             PÉRDIDO
                                                              ↓
                                          FocusTimerService ←→  FocusModeStore
```

### States & Types Available
- `PomodoroState`: idle, work, shortBreak, longBreak, completed
- `FocusModeType`: focusTime, meeting, inbox, custom
- `FocusMode.meetingID` exists (30 min default) but never used by calendar

---

## Integration Options

| Strategy | UX Impact | Complexity | Trade-off |
|----------|-----------|------------|-----------|
| **A. Calendar Overlay (UI-only)** | Visual, non-intrusive | Low | Passive info, no action |
| **B. Calendar → Auto FocusMode** | Automated, less friction | Medium | User loses control |
| **C. Calendar → Pomodoro Suggestion** | Assistive, maintains control | Medium | Requires suggestion UI |
| **D. Calendar Priority (interrupt)** | Proactive, avoids conflict | High | Interrupts running sessions |
| **E. Calendar in Metrics** | Analytical, post-factum | Low | No real-time impact |

---

## Recommended: Phased Approach (A + C + E)

### Phase 1: Visual Awareness (A) → v0.10.0
Show calendar info without changing behavior.

**Components:**
1. **TimerPage widget:** "Next calendar event" (title, time until, duration)
2. **MenuBarDropdownView:** Badge showing "meeting active" vs "pomodoro active"
3. **IdleDashboardView:** List of today's next 3 events

**Technical:**
- Add `@Published var currentMeeting: CalendarMeeting?` to `CalendarSlackIntegrationService`
- Already implemented (line 19), expose to Views
- New view component: `CalendarEventCard`

**User value:**
- Awareness without interruption
- Manual decision-making still possible

---

### Phase 2: Proactive Suggestion (C) → v0.11.0
Detect conflicts, suggest actions.

**Trigger:** When user clicks "Start Focus Mode" button

**Logic:**
```swift
if let nextMeeting = calendarService.nextEventWithin(minutes: 10) {
    showSuggestion: "Meeting starts in \(timeUntil). Options:"
    - [Start Meeting FocusMode] (uses meeting duration)
    - [Continue current pomodoro]
    - [Snooze reminder]
}
```

**Technical:**
- `CalendarSlackIntegrationService.nextEventWithin(minutes: Int) -> CalendarMeeting?`
- New alert UI: `CalendarConflictSheet`
- When "Start Meeting FocusMode" selected:
  - Create temporary `FocusMode` with `durationMinutes = meeting.duration`
  - Set `type = .meeting`
  - Override DND if video call detected

**User value:**
- Reduces manual planning
- Maintains user control
- Prevents conflicts

---

### Phase 3: Analytics (E) → v0.12.0
Track calendar vs ad-hoc sessions.

**Model changes:**
```swift
struct FocusSessionRecord {
    // ... existing fields
    var associatedEventID: String?  // Calendar event ID
    var isCalendarScheduled: Bool   // Derived
}
```

**Metrics breakdown:**
```
- Scheduled (Calendar): X hours
- Ad-hoc (Manual): Y hours
- Meeting sessions: Z sessions
- Focus sessions: N sessions
```

**User value:**
- Data-driven optimization
- Understand time allocation patterns

---

## Future: Phase 4 (D) - Optional Auto-Resolution
Interrupt pomodoro when meeting starts (high complexity, requires user opt-in).

**Trigger:** Calendar event becomes active (detected by 30s poll)

**Behavior:**
```swift
if calendarService.currentMeeting != nil && timerService.isActive {
    // Option 1: Auto-pause pomodoro
    timerService.pauseSession()

    // Option 2: Prompt user
    showConflictResolutionDialog()
}
```

**Risk:** User frustration if interrupting deep focus

**Mitigation:**
- User opt-in only
- Grace period: Don't interrupt if <5 min remaining
- Configurable: "Never interrupt", "Ask before interrupting", "Auto-pause"

---

## Open Questions

1. **Phase scope:** Start with Phase 1 (UI-only) or jump to Phase 2 (suggestions)?
2. **Conflict resolution:** If pomodoro runs and meeting starts, what should happen?
   - Interrupt pomodoro (D)
   - Notify and let user choose (C)
   - Let pomodoro run (no conflict)
3. **Meeting FocusMode:** Use `FocusMode.meetingID` (30 min fixed) or adapt duration to each event?
4. **Opt-in granularity:** "Auto-switch to meeting mode" = all meetings, video-only, or user-selected calendars?

---

## Success Metrics

- **Phase 1:** Calendar events visible in UI (3 locations)
- **Phase 2:** Conflict suggestions shown before 50% of conflicting sessions
- **Phase 3:** Metrics differentiate scheduled vs ad-hoc sessions
- **Overall:** No pomodoro interrupted without user consent
# Implementation Plan: Calendar - Pomodoro Coexistence (Phases 1+2)

**Status:** Active 2026-07-27
**Target:** v0.10.0
**Approach:** Combine Phase 1 (visual) + Phase 2 (suggestions) in single release

---

## Phase 1: Visual Awareness

### 1.1 CalendarEventCard Component

**File:** `Focally/Views/Calendar/CalendarEventCard.swift`

```swift
struct CalendarEventCard: View {
    let meeting: CalendarMeeting
    let isActive: Bool
    let timeUntil: String?

    var body: some View {
        HStack(spacing: 12) {
            // Calendar icon
            Image(systemName: "calendar.badge.clock")
                .foregroundStyle(isActive ? Color.focallyPrimary : Color.focallyTertiary)

            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.title)
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyOnSurface)

                HStack(spacing: 4) {
                    Text(formattedTime(meeting.startTime))
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOnSurfaceVariant)

                    if let timeUntil {
                        Text("•")
                            .foregroundStyle(Color.focallyOutline)
                        Text(timeUntil)
                            .font(.focallyCaption)
                            .foregroundStyle(Color.focallyPrimary)
                    }
                }
            }

            Spacer()

            // Video call indicator
            if meeting.hasVideoCall {
                Image(systemName: "video.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.focallySecondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isActive ? Color.focallyPrimaryContainer : Color.focallySurfaceContainerLow)
        )
    }
}
```

---

### 1.2 TimerPage Integration

**File:** `Focally/Views/Timer/TimerPage.swift`

Add after timer controls (before `FocusModeCards`):

```swift
// MARK: - Calendar Event Section
if calendarService.isEnabled, calendarService.hasCalendarAccess {
    if let currentMeeting = calendarService.currentMeeting {
        Section(header: SectionHeader(title: "Current Meeting")) {
            CalendarEventCard(
                meeting: currentMeeting,
                isActive: true,
                timeUntil: nil
            )
        }
    } else if let nextMeeting = calendarService.nextEventWithin(minutes: 120) {
        Section(header: SectionHeader(title: "Next Event")) {
            CalendarEventCard(
                meeting: nextMeeting,
                isActive: false,
                timeUntil: timeUntilString(from: nextMeeting.startTime)
            )
        }
    }
}
```

---

### 1.3 MenuBarDropdownView Integration

**File:** `Focally/Views/MenuBar/MenuBarDropdownView.swift`

Add before `quickStartSection`:

```swift
// MARK: - Current Calendar Event
if calendarService.currentMeeting != nil {
    VStack(spacing: 8) {
        LocalizedText("menubar_current_meeting")
            .font(.focallyCaption)
            .foregroundStyle(Color.focallyOnSurfaceVariant)

        if let meeting = calendarService.currentMeeting {
            CalendarEventCard(
                meeting: meeting,
                isActive: true,
                timeUntil: nil
            )
        }
    }
    .padding(.horizontal, 16)
}
```

---

### 1.4 IdleDashboardView Integration

**File:** `Focally/Views/Timer/IdleDashboardView.swift`

Add before `FocusModeCards`:

```swift
// MARK: - Today's Events
if calendarService.isEnabled, calendarService.hasCalendarAccess {
    let upcomingEvents = Array(calendarService.events.prefix(3))

    if !upcomingEvents.isEmpty {
        Section(header: SectionHeader(title: "Today's Events")) {
            ForEach(upcomingEvents) { event in
                CalendarEventCard(
                    meeting: event,
                    isActive: calendarService.currentMeeting?.id == event.id,
                    timeUntil: event.startTime > Date() ? timeUntilString(from: event.startTime) : nil
                )
            }
        }
    }
}
```

---

## Phase 2: Proactive Suggestions

### 2.1 CalendarSlackIntegrationService Extensions

**File:** `Focally/Services/CalendarSlackIntegrationService.swift`

Add methods:

```swift
// MARK: - Public API for UI

/// Returns next event starting within specified minutes
func nextEventWithin(minutes: Int) -> CalendarMeeting? {
    let cutoff = Date().addingTimeInterval(TimeInterval(minutes * 60))
    return events.first { event in
        event.startTime > Date() && event.startTime <= cutoff
    }
}

/// Returns true if there's an event starting within 10 minutes
var hasUpcomingConflict: Bool {
    nextEventWithin(minutes: 10) != nil
}

/// Returns time until next event (localized string)
func timeUntilNextEvent() -> String? {
    guard let next = nextEventWithin(minutes: 120) else { return nil }
    let minutes = Int(next.startTime.timeIntervalSinceNow / 60)
    return minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h \(minutes % 60)m"
}
```

---

### 2.2 CalendarConflictSheet

**File:** `Focally/Views/Calendar/CalendarConflictSheet.swift`

```swift
struct CalendarConflictSheet: View {
    let meeting: CalendarMeeting
    let onStartMeeting: () -> Void
    let onContinuePomodoro: () -> Void
    let onCancel: () -> Void

    var timeUntil: String {
        let minutes = Int(meeting.startTime.timeIntervalSinceNow / 60)
        return minutes < 60 ? "\(minutes) minutes" : "\(minutes / 60)h \(minutes % 60)m"
    }

    var body: some View {
        VStack(spacing: 20) {
            // Alert icon
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(Color.focallyWarning)

            VStack(spacing: 8) {
                Text("Upcoming Meeting")
                    .font(.focallyH2)
                    .foregroundStyle(Color.focallyOnSurface)

                Text(meeting.title)
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyOnSurface)

                Text("Starts in \(timeUntil)")
                    .font(.focallyBody)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
            }

            Divider()

            VStack(spacing: 12) {
                // Start Meeting FocusMode button
                Button(action: onStartMeeting) {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Start Meeting FocusMode")
                                .font(.focallyBodyBold)
                            Text("Duration: \(meeting.duration) min")
                                .font(.focallyCaption)
                        }
                        Spacer()
                    }
                    .foregroundStyle(Color.focallyOnPrimary)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(Color.focallyPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                // Continue pomodoro button
                Button(action: onContinuePomodoro) {
                    Text("Continue current pomodoro")
                        .font(.focallyBodyBold)
                        .foregroundStyle(Color.focallyPrimary)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(Color.focallyPrimaryContainer)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                // Cancel button
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.focallyBody)
                        .foregroundStyle(Color.focallyOutline)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .background(Color.focallySurface)
    }
}
```

---

### 2.3 TimerPage Conflict Detection

**File:** `Focally/Views/Timer/TimerPage.swift`

Add state and trigger:

```swift
@State private var showConflictSheet = false
@State private var conflictMeeting: CalendarMeeting?

// In startSession handler (or button action)
func handleStartSession(mode: FocusMode) {
    // Check for calendar conflict
    if calendarService.hasUpcomingConflict,
       let conflict = calendarService.nextEventWithin(minutes: 10) {
        conflictMeeting = conflict
        showConflictSheet = true
        return
    }

    // No conflict, start normally
    timerService.startSession(mode: mode)
}
```

Add sheet to view:

```swift
.sheet(isPresented: $showConflictSheet) {
    if let meeting = conflictMeeting {
        CalendarConflictSheet(
            meeting: meeting,
            onStartMeeting: {
                startMeetingSession(meeting: meeting)
                showConflictSheet = false
            },
            onContinuePomodoro: {
                timerService.startSession(mode: selectedMode)
                showConflictSheet = false
            },
            onCancel: {
                showConflictSheet = false
            }
        )
    }
}
```

---

### 2.4 Start Meeting FocusMode Handler

**File:** `Focally/Views/Timer/TimerPage.swift`

Add handler:

```swift
private func startMeetingSession(meeting: CalendarMeeting) {
    // Create temporary meeting FocusMode
    let meetingDuration = Int(meeting.endTime.timeIntervalSince(meeting.startTime) / 60)

    let meetingMode = FocusMode(
        id: FocusMode.meetingID,
        name: meeting.title,
        emoji: ":calendar:",
        statusText: "In a meeting",
        durationMinutes: meetingDuration,
        enableDND: meeting.hasVideoCall,  // Auto DND for video calls
        enablePomodoro: false,  // No pomodoro for meetings
        pomodoroWorkMinutes: meetingDuration,
        pomodoroBreakMinutes: 5,
        pomodoroLongBreakMinutes: 15,
        pomodoroRounds: 1,
        breakLabel: nil,
        type: .meeting
    )

    timerService.startSession(mode: meetingMode)
}
```

---

## Technical Debt & Open Issues

### 1. CalendarMeeting Extensions

Need helper methods:

```swift
extension CalendarMeeting {
    var duration: Int {
        Int(endTime.timeIntervalSince(startTime) / 60)
    }
}
```

### 2. Localization Keys

Add to `Resources/{en,es,pt}.lproj/Localizable.strings`:

```
"menubar_current_meeting" = "Current Meeting";
"upcoming_meeting" = "Upcoming Meeting";
"starts_in" = "Starts in";
"start_meeting_focusmode" = "Start Meeting FocusMode";
"continue_pomodoro" = "Continue current pomodoro";
```

### 3. CalendarMeeting Public Exposure

`CalendarSlackIntegrationService` properties need to be public:

```swift
@Published var events: [CalendarMeeting] = []  // Already private(set)
@Published var currentMeeting: CalendarMeeting?  // Already private(set)
```

No changes needed—already accessible via `@Environment`.

---

## Success Criteria

- [ ] Calendar events visible in 3 UI locations (TimerPage, MenuBar, IdleDashboard)
- [ ] Conflict alert appears before starting pomodoro when meeting <10 min
- [ ] "Start Meeting FocusMode" creates session with meeting duration
- [ ] Video call meetings auto-enable DND
- [ ] No pomodoro interrupted without user choice

---

## Implementation Order

1. **CalendarEventCard** component
2. **CalendarSlackIntegrationService** extensions (`nextEventWithin`, `timeUntilNextEvent`)
3. **TimerPage** visual integration
4. **MenuBarDropdownView** visual integration
5. **IdleDashboardView** visual integration
6. **CalendarConflictSheet** UI
7. **TimerPage** conflict detection + sheet trigger
8. **Start Meeting FocusMode** handler
9. **Localization** strings
10. **Testing** manual + edge cases

**Estimated:** 2-3 development days
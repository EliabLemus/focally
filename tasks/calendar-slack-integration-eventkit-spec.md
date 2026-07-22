# TASK-004: Calendar → Slack + DND Integration (EventKit)

## Overview
Integrate macOS Calendar (via EventKit) with Slack status updates and macOS DND automation during meetings.

**Simplified approach using EventKit**: No OAuth, no Google Cloud Console, no Client ID/Secret. Just macOS permissions.

---

## Requirements

### 1. Calendar → Slack Status Updates
When a calendar event is currently happening and the user has Slack enabled:
- Display the meeting title in Slack status (configurable: show/hide title)
- Keep existing focus session status if no meeting is active
- Update in real-time when meetings start/end

### 2. DND for Meetings
When a meeting with a video call starts (has a hangout/meet link or video conference flag):
- Automatically activate macOS DND
- Deactivate DND when meeting ends
- Configurable: enable/disable DND for meetings

### 3. Simplified Setup
- **No Google Cloud Console setup**
- **No Client ID / Client Secret**
- Single permission: macOS Calendar access
- Works with Google, iCloud, and Outlook calendars synced to macOS

---

## Implementation Details

### New Service: `CalendarSlackIntegrationService`
Location: `Focally/Services/CalendarSlackIntegrationService.swift`

```swift
import Foundation
import Combine
import EventKit

@MainActor
final class CalendarSlackIntegrationService: NSObject, ObservableObject {
    static let shared = CalendarSlackIntegrationService()

    // MARK: - Settings
    static let showMeetingTitleKey = "calendarShowMeetingTitle"
    static let dndForMeetingsKey = "calendarDndForMeetings"
    static let calendarEnabledKey = "calendarEnabled"

    @Published var isEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.calendarEnabledKey)
            if isEnabled {
                requestCalendarAccess()
            } else {
                stopMonitoring()
            }
        }
    }

    @Published var showMeetingTitle: Bool = true {
        didSet {
            UserDefaults.standard.set(showMeetingTitle, forKey: Self.showMeetingTitleKey)
            if isEnabled {
                updateSlackStatusForCurrentMeeting()
            }
        }
    }

    @Published var dndForMeetings: Bool = true {
        didSet {
            UserDefaults.standard.set(dndForMeetings, forKey: Self.dndForMeetingsKey)
        }
    }

    @Published var hasCalendarAccess: Bool = false
    @Published var currentMeeting: CalendarEvent?

    // MARK: - Dependencies
    private let eventStore = EKEventStore()
    private let slackService: SlackService
    private let dndService: DNDService
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    private override init() {
        self.slackService = SlackService()
        self.dndService = DNDService.shared
        super.init()

        // Load settings
        self.isEnabled = UserDefaults.standard.bool(forKey: Self.calendarEnabledKey)
        self.showMeetingTitle = UserDefaults.standard.bool(forKey: Self.showMeetingTitleKey)
        self.dndForMeetings = UserDefaults.standard.bool(forKey: Self.dndForMeetingsKey)

        // Check current access status
        checkCalendarAccess()

        if isEnabled && hasCalendarAccess {
            startPeriodicCheck()
        }
    }

    // MARK: - Calendar Access
    private func checkCalendarAccess() {
        let status = EKEventStore.authorizationStatus(for: .event)
        hasCalendarAccess = (status == .authorized)
    }

    private func requestCalendarAccess() {
        eventStore.requestAccess(to: .event) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.hasCalendarAccess = granted

                if granted {
                    self?.startPeriodicCheck()
                    self?.checkAndUpdate()
                } else if let error = error {
                    print("Calendar access denied: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Monitoring
    private func startPeriodicCheck() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.checkAndUpdate()
        }
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        currentMeeting = nil
    }

    private func checkAndUpdate() {
        guard isEnabled && hasCalendarAccess else {
            currentMeeting = nil
            return
        }

        let now = Date()
        let newMeeting = fetchCurrentMeeting(at: now)

        // Detect change
        if newMeeting != currentMeeting {
            handleMeetingChange(newMeeting)
        }
    }

    // MARK: - Event Fetching
    private func fetchCurrentMeeting(at date: Date) -> CalendarEvent? {
        let calendars = eventStore.calendars(for: .event)
        guard !calendars.isEmpty else { return nil }

        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: calendars)
        let events = eventStore.events(matching: predicate)

        // Find event happening now
        return events.first { event in
            guard !event.isAllDay else { return false }
            let startDate = event.startDate
            let endDate = event.endDate
            return date >= startDate && date < endDate
        }.map { CalendarEvent(from: $0) }
    }

    // MARK: - Meeting Handling
    private func handleMeetingChange(_ meeting: CalendarEvent?) {
        let previousMeeting = currentMeeting
        currentMeeting = meeting

        if let meeting {
            // Meeting started
            updateSlackStatusFor(meeting)
            activateDNDIfNeeded(meeting)
        } else if previousMeeting != nil {
            // Meeting ended
            deactivateDNDIfNeeded()
        }
    }

    private func updateSlackStatusFor(_ meeting: CalendarEvent) {
        guard slackService.isEnabled && slackService.isConnected else { return }

        let statusText: String
        if showMeetingTitle {
            statusText = "In meeting: \(meeting.title)"
        } else {
            statusText = "In a meeting"
        }

        let expiration = Int(meeting.endTime.timeIntervalSince1970)
        slackService.setStatus(
            text: statusText,
            expirationTimestamp: expiration,
            taskEmoji: "📅",
            fallbackEmoji: ":calendar:"
        )
    }

    private func activateDNDIfNeeded(_ meeting: CalendarEvent) {
        guard dndForMeetings,
              meeting.hasVideoCall,
              !dndService.isDNDActive else { return }

        dndService.activateDND()
    }

    private func deactivateDNDIfNeeded() {
        // Only deactivate if we activated it for a meeting
        // (not if focus session activated it)
        guard dndForMeetings, dndService.isDNDActive else { return }
        dndService.deactivateDND()
    }

    // MARK: - Helper Methods
    func updateSlackStatusForCurrentMeeting() {
        guard let meeting = currentMeeting else { return }
        updateSlackStatusFor(meeting)
    }
}

// MARK: - CalendarEvent from EKEvent

extension CalendarEvent {
    init(from event: EKEvent) {
        self.id = event.eventIdentifier ?? UUID().uuidString
        self.title = event.title ?? "Untitled"
        self.startTime = event.startDate
        self.endTime = event.endDate
        self.isAllDay = event.isAllDay

        // Detect video call link
        if let location = event.location, location.contains("meet.google.com") {
            self.meetLink = location
        } else if let url = event.url?.absoluteString, url.contains("meet.google.com") {
            self.meetLink = url
        } else if let urlString = event.notes?.extractFirstURL(),
                urlString.contains("meet.google.com") {
            self.meetLink = urlString
        } else if event.hasAttendees {
            // Assume video call if it has attendees (could be Zoom, Teams, etc)
            self.meetLink = nil  // We don't know the exact link, but it's a call
        } else {
            self.meetLink = nil
        }
    }
}

// MARK: - Extensions

extension String {
    func extractFirstURL() -> String? {
        let pattern = "https?://[^\\s]+"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: self, range: NSRange(self.startIndex..., in: self)) else {
            return nil
        }
        return (self as NSString).substring(with: match.range)
    }
}
```

### Model Update: CalendarEvent
Add convenience property for video call detection:

```swift
// In CalendarEvent.swift
var hasVideoCall: Bool {
    meetLink != nil
}
```

---

## Settings UI Updates
Update `IntegrationsSettingsView.swift`:

### 1. Simplify Calendar Card
Remove Client ID/Secret fields. Add permission request button and settings toggles.

```swift
private var calendarCard: some View {
    VStack(alignment: .leading, spacing: FocallySpacing.medium) {
        HStack(spacing: FocallySpacing.medium) {
            iconTile(systemImage: "calendar", color: Color.focallyTertiary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Calendar Integration")
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyOnSurface)

                Text("Sync calendar events with Slack status and DND.")
                    .font(.focallyBody)
                    .foregroundStyle(Color.focallyOutline)
            }

            Spacer()

            accessBadge(hasAccess: calendarIntegrationService.hasCalendarAccess)
            FocallyToggleButton(isOn: calendarEnabledBinding)
        }

        // Permission Request Section
        if !calendarIntegrationService.hasCalendarAccess {
            VStack(alignment: .leading, spacing: FocallySpacing.small) {
                Text("Calendar access required")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)

                HStack(spacing: FocallySpacing.small) {
                    primaryButton("Grant Permission", action: requestCalendarAccess)
                }
            }
            .padding(.vertical, FocallySpacing.small)
        }

        // Settings Section (only visible when enabled)
        if calendarIntegrationService.isEnabled && calendarIntegrationService.hasCalendarAccess {
            Divider()
                .padding(.vertical, FocallySpacing.extraSmall)

            VStack(alignment: .leading, spacing: FocallySpacing.small) {
                Toggle(isOn: showMeetingTitleBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show meeting title in Slack")
                            .font(.focallyBody)
                            .foregroundStyle(Color.focallyOnSurface)
                        Text("Display the meeting name in your Slack status")
                            .font(.focallyCaption)
                            .foregroundStyle(Color.focallyOutline)
                    }
                }
                .toggleStyle(.switch)

                Toggle(isOn: dndForMeetingsBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable DND for calls")
                            .font(.focallyBody)
                            .foregroundStyle(Color.focallyOnSurface)
                        Text("Automatically activate Do Not Disturb during meetings")
                            .font(.focallyCaption)
                            .foregroundStyle(Color.focallyOutline)
                    }
                }
                .toggleStyle(.switch)
            }
        }

        // Current Meeting Display
        if let meeting = calendarIntegrationService.currentMeeting {
            Divider()
                .padding(.vertical, FocallySpacing.extraSmall)

            VStack(alignment: .leading, spacing: FocallySpacing.extraSmall) {
                Text("Current Meeting")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)

                Text(meeting.title)
                    .font(.focallyBody)
                    .foregroundStyle(Color.focallyOnSurface)

                Text(meeting.timeRange)
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOutline)

                if meeting.hasVideoCall {
                    Label("Video call", systemImage: "video")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyPrimary)
                }
            }
            .padding(.vertical, FocallySpacing.extraSmall)
        }
    }
    .padding(FocallySpacing.large)
    .focallyCard()
}

private func accessBadge(hasAccess: Bool) -> some View {
    HStack(spacing: 4) {
        Circle()
            .fill(hasAccess ? Color.focallyPrimary : Color.focallyOutline)
            .frame(width: 6, height: 6)

        Text(hasAccess ? "Access Granted" : "No Access")
            .font(.focallyCaption)
            .foregroundStyle(hasAccess ? Color.focallyPrimary : Color.focallyOutline)
    }
    .padding(.horizontal, FocallySpacing.small)
    .padding(.vertical, 4)
    .background(
        RoundedRectangle(cornerRadius: FocallyRadius.extraSmall)
            .fill(hasAccess ? Color.focallyPrimary.opacity(0.1) : Color.focallySurfaceContainer)
    )
}

private var calendarEnabledBinding: Binding<Bool> {
    Binding(
        get: { calendarIntegrationService.isEnabled },
        set: { calendarIntegrationService.isEnabled = $0 }
    )
}

private var showMeetingTitleBinding: Binding<Bool> {
    Binding(
        get: { calendarIntegrationService.showMeetingTitle },
        set: { calendarIntegrationService.showMeetingTitle = $0 }
    )
}

private var dndForMeetingsBinding: Binding<Bool> {
    Binding(
        get: { calendarIntegrationService.dndForMeetings },
        set: { calendarIntegrationService.dndForMeetings = $0 }
    )
}

private func requestCalendarAccess() {
    calendarIntegrationService.isEnabled = true
}
```

---

## Info.plist Permission
Add to `Focally/Info.plist`:

```xml
<key>NSCalendarsFullAccessUsageDescription</key>
<string>Focally needs calendar access to detect meetings and automatically update your Slack status and Do Not Disturb mode.</string>
```

---

## AppDelegate Updates
Update `OnItFocusApp.swift`:

### 1. Replace GoogleCalendarService with CalendarSlackIntegrationService

```swift
// OLD:
// let calendarService = GoogleCalendarService()

// NEW:
let calendarIntegrationService = CalendarSlackIntegrationService()
```

### 2. Update environment objects

```swift
// In MenuBarDropdownView and MainWindow:
// OLD:
// .environmentObject(calendarService)

// NEW:
.environmentObject(calendarIntegrationService)
```

### 3. Remove Google Calendar conflict check
Remove `presentCalendarConflictIfNeeded()` method and its call in `onSessionStarted()` since we're using EventKit now.

### 4. Update IntegrationsSettingsView environment object

```swift
// OLD:
// @EnvironmentObject private var calendarService: GoogleCalendarService

// NEW:
@EnvironmentObject private var calendarIntegrationService: CalendarSlackIntegrationService
```

---

## Cleanup: Remove OAuth-Related Code

### Files to DELETE:
- `Focally/Services/GoogleCalendarService.swift`
- `Focally/Services/GoogleCalendarService+Auth.swift`
- `Focally/Services/GoogleCalendarService+API.swift`
- `Focally/Services/GoogleCalendarService+Events.swift`
- `Focally/Services/GoogleCalendarService+Formatters.swift`
- `Focally/Models/GoogleCalendarModels.swift`

### Files to UPDATE:
- `Focally/Models/CalendarEvent.swift` → Add `hasVideoCall` property and `init(from: EKEvent)`
- `Focally/Views/Settings/IntegrationsSettingsView.swift` → Simplify calendar card
- `Focally/OnItFocusApp.swift` → Replace service

---

## Testing Checklist
- [ ] Toggle ON Calendar → macOS permission dialog appears
- [ ] User grants permission → "Access Granted" badge shows
- [ ] Toggle OFF Calendar → monitoring stops, settings hidden
- [ ] Meeting with Google Meet link → Slack status "In meeting: X", DND activates
- [ ] Meeting without video → Slack status updates, DND does NOT activate
- [ ] "Show meeting title" OFF → Slack status "In a meeting" (no title)
- [ ] "Enable DND for calls" OFF → DND does NOT activate
- [ ] Meeting ends → Slack status clears, DND deactivates
- [ ] Periodic check works (every 30 seconds)
- [ ] Settings persist across app restarts
- [ ] Works with iCloud, Google, and Outlook calendars synced to macOS

---

## Files Summary

### NEW FILES:
1. `Focally/Services/CalendarSlackIntegrationService.swift`

### MODIFIED FILES:
1. `Focally/Models/CalendarEvent.swift` (add `hasVideoCall`, `init(from:)`)
2. `Focally/Views/Settings/IntegrationsSettingsView.swift` (simplify calendar card)
3. `Focally/OnItFocusApp.swift` (replace service, update env objects)
4. `Focally/Info.plist` (add permission key)

### DELETED FILES:
1. `Focally/Services/GoogleCalendarService.swift`
2. `Focally/Services/GoogleCalendarService+Auth.swift`
3. `Focally/Services/GoogleCalendarService+API.swift`
4. `Focally/Services/GoogleCalendarService+Events.swift`
5. `Focally/Services/GoogleCalendarService+Formatters.swift`
6. `Focally/Models/GoogleCalendarModels.swift`

---

## Estimated Time
3-4 hours (includes cleanup of OAuth code)

---

## Benefits vs OAuth

| Feature | OAuth | EventKit |
|---------|-------|----------|
| Setup complexity | 10+ steps, Google Cloud Console | 1 permission dialog |
| Credentials | Client ID + Secret in Keychain | None |
| Online required | Yes (auth) | No (offline works) |
| Calendar sources | Google only | Google + iCloud + Outlook |
| Code complexity | High (token refresh, API calls) | Low (native API) |
| Maintenance | OAuth updates, API changes | Stable macOS framework |
| Privacy concern | Third-party access | Local-only |
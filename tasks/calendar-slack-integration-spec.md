# TASK-004: Calendar → Slack + DND Integration

## Overview
Integrate Google Calendar events with Slack status updates and macOS DND automation during meetings.

## Requirements

### 1. Calendar → Slack Status Updates
When a Google Calendar event is currently happening and the user has Slack enabled:
- Display the meeting title in Slack status (configurable: show/hide title)
- Keep existing focus session status if no meeting is active
- Update in real-time when meetings start/end

### 2. DND for Meetings
When a meeting with a meet link starts (has `meetLink` in CalendarEvent):
- Automatically activate macOS DND
- Deactivate DND when meeting ends
- Configurable: enable/disable DND for meetings

## Implementation Details

### New Service: `CalendarSlackIntegrationService`
Location: `Focally/Services/CalendarSlackIntegrationService.swift`

```swift
import Foundation
import Combine

@MainActor
final class CalendarSlackIntegrationService: NSObject, ObservableObject {
    static let shared = CalendarSlackIntegrationService()

    // Settings
    static let showMeetingTitleKey = "calendarShowMeetingTitle"
    static let dndForMeetingsKey = "calendarDndForMeetings"

    @Published var showMeetingTitle: Bool = true {
        didSet {
            UserDefaults.standard.set(showMeetingTitle, forKey: Self.showMeetingTitleKey)
        }
    }

    @Published var dndForMeetings: Bool = true {
        didSet {
            UserDefaults.standard.set(dndForMeetings, forKey: Self.dndForMeetingsKey)
        }
    }

    // Dependencies
    @Published var currentMeeting: CalendarEvent?

    private let calendarService: GoogleCalendarService
    private let slackService: SlackService
    private let dndService: DNDService
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private override init() {
        self.calendarService = GoogleCalendarService.shared
        self.slackService = SlackService()
        self.dndService = DNDService.shared
        super.init()

        // Load settings
        self.showMeetingTitle = UserDefaults.standard.bool(forKey: Self.showMeetingTitleKey)
        self.dndForMeetings = UserDefaults.standard.bool(forKey: Self.dndForMeetingsKey)

        // Observe calendar changes
        calendarService.$currentMeeting
            .receive(on: DispatchQueue.main)
            .sink { [weak self] meeting in
                self?.handleMeetingChange(meeting)
            }
            .store(in: &cancellables)

        // Start periodic check (every 30 seconds)
        startPeriodicCheck()
    }

    private func startPeriodicCheck() {
        timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.checkAndUpdate()
        }
    }

    private func checkAndUpdate() {
        guard calendarService.isEnabled && calendarService.isSignedIn else {
            currentMeeting = nil
            return
        }

        // Refresh events and check for current meeting
        calendarService.fetchTodayEvents()
        currentMeeting = calendarService.currentMeeting
    }

    private func handleMeetingChange(_ meeting: CalendarEvent?) {
        currentMeeting = meeting

        if let meeting {
            // Meeting started
            updateSlackStatusFor(meeting)
            activateDNDIfNeeded(meeting)
        } else {
            // Meeting ended - restore focus status if active
            restoreFocusStatusIfNeeded()
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
              meeting.meetLink != nil,
              !dndService.isDNDActive else { return }

        dndService.activateDND()
    }

    private func restoreFocusStatusIfNeeded() {
        // Deactivate DND if we activated it for a meeting
        if dndForMeetings && dndService.isDNDActive {
            dndService.deactivateDND()
        }

        // Note: We don't automatically restore focus session status here
        // because the FocusTimerService already manages that on session end
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        cancellables.removeAll()
    }
}
```

### Model Extension: CalendarEvent
Add convenience property for meeting detection:

```swift
// In CalendarEvent.swift
var isMeetingWithCall: Bool {
    meetLink != nil
}
```

### Settings UI Updates
Update `IntegrationsSettingsView.swift` to add Calendar settings:

```swift
// Add inside calendarCard, after the connection section
VStack(alignment: .leading, spacing: FocallySpacing.medium) {
    Text("Calendar Integration Settings")
        .font(.focallyBodyBold)
        .foregroundStyle(Color.focallyOnSurface)

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
    .disabled(!calendarService.isSignedIn)

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
    .disabled(!calendarService.isSignedIn)
}
.padding(.top, FocallySpacing.medium)

// Bindings
private var showMeetingTitleBinding: Binding<Bool> {
    Binding(
        get: { calendarSlackIntegrationService?.showMeetingTitle ?? true },
        set: { calendarSlackIntegrationService?.showMeetingTitle = $0 }
    )
}

private var dndForMeetingsBinding: Binding<Bool> {
    Binding(
        get: { calendarSlackIntegrationService?.dndForMeetings ?? true },
        set: { calendarSlackIntegrationService?.dndForMeetings = $0 }
    )
}
```

### AppDelegate Updates
Add to `OnItFocusApp.swift`:

1. Add service instance:
```swift
let calendarSlackIntegrationService = CalendarSlackIntegrationService()
```

2. Add to environment objects in MenuBarDropdownView and MainWindow:
```swift
.environmentObject(calendarSlackIntegrationService)
```

3. Start monitoring on launch:
```swift
// In applicationDidFinishLaunching
if calendarService.isEnabled {
    calendarService.fetchTodayEvents()
    calendarSlackIntegrationService.startPeriodicCheck()
}
```

### Conflict Resolution
When both a focus session and a meeting are active:
- Focus session status takes precedence (don't override with meeting)
- DND remains active regardless of source

### Testing Checklist
- [ ] Meeting status updates in Slack with title shown
- [ ] Meeting status updates in Slack with title hidden
- [ ] DND activates for meetings with meet links
- [ ] DND does NOT activate for meetings without meet links
- [ ] DND setting toggles work correctly
- [ ] Focus session status not overridden by meetings
- [ ] Meeting status clears when meeting ends
- [ ] Periodic refresh works (30s intervals)
- [ ] Settings persist across app restarts

## Files to Modify
1. `Focally/Services/CalendarSlackIntegrationService.swift` (NEW)
2. `Focally/Models/CalendarEvent.swift` (EXTEND)
3. `Focally/Views/Settings/IntegrationsSettingsView.swift` (UPDATE)
4. `Focally/OnItFocusApp.swift` (UPDATE)

## Estimated Time
2-3 hours
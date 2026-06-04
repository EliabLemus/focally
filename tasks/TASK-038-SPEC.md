# TASK-038-SPEC: Meeting Category with Time Selection and Slack Google Meet Icon

**ID:** TASK-038
**Priority:** HIGH
**Estimated Time:** 5-6 hours
**Created:** 2025-01-23
**Status:** Draft

---

## 🎯 Objective

Implement a new **Meeting category** that allows users to select a specific time duration for meetings and automatically updates Slack status with the `:google-meet:` emoji icon when the meeting starts.

**User Requirements:**
- New task type: "Meeting" category ✅ (NEW)
- Time selection: Choose meeting duration (15m, 30m, 45m, 60m, 90m, 120m) ✅ (NEW)
- Slack integration: Auto-set status with `:google-meet:` emoji ✅ (NEW)
- **macOS DND: Block ALL notifications during meeting (Slack, email, system, etc.)** ✅ (NEW - CRITICAL)
- Start meeting timer with selected duration ✅ (NEW)
- Clean up Slack status after meeting ends ✅ (NEW)
- Restore macOS notifications after meeting ends ✅ (NEW)

---

## 🔍 Current State Analysis

### What's Working
- `PredefinedTask` model exists with basic task properties ✅
- `SlackService.setSlackFocusStatus()` can update status with custom emoji ✅
- `FocusIntegrationService` handles Slack status updates ✅
- Timer functionality works with `FocusTimerService` ✅
- Predefined tasks list displays in UI ✅

### What's NOT Working
- No way to distinguish between different task types (Pomodoro vs Meeting) ❌
- No time selection UI for meetings ❌
- All tasks use the same Slack emoji regardless of type ❌
- No meeting-specific task type exists ❌
- **macOS notifications are NOT blocked during meetings** ❌ (NEW)
- **Meeting mode doesn't activate Do Not Disturb** ❌ (NEW)

### Root Cause
`PredefinedTask` model doesn't have a `taskType` property to distinguish between task types. Slack status updates don't check task type to determine the appropriate emoji. UI doesn't provide time selection for meeting-type tasks. **DNDService is not integrated with meeting sessions to block notifications during meetings.**

---

## 📋 Tasks

### 1. PredefinedTask Model - Add Task Type Support

**File:** `Focally/Models/PredefinedTask.swift`

**Add enum:**
```swift
enum TaskType: String, Codable, CaseIterable {
    case pomodoro = "pomodoro"
    case deepWork = "deepWork"
    case meeting = "meeting"

    var displayName: String {
        switch self {
        case .pomodoro: return "Pomodoro"
        case .deepWork: return "Deep Work"
        case .meeting: return "Meeting"
        }
    }
}
```

**Add properties to PredefinedTask struct:**
```swift
struct PredefinedTask: Identifiable, Codable, Equatable {
    // ... existing properties ...

    var taskType: TaskType
    var availableDurations: [Int] // Durations available in minutes

    init(id: UUID = UUID(),
         name: String,
         emoji: String,
         icon: String,
         iconBgColor: String,
         iconFgColor: String,
         durationMinutes: Int = 25,
         cycles: Int = 1,
         taskType: TaskType = .pomodoro,
         availableDurations: [Int] = []) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.icon = icon
        self.iconBgColor = iconBgColor
        self.iconFgColor = iconFgColor
        self.durationMinutes = durationMinutes
        self.cycles = cycles
        self.taskType = taskType
        self.availableDurations = availableDurations.isEmpty ? [durationMinutes] : availableDurations
    }
}
```

**Update defaultTasks array:**
```swift
static let defaultTasks: [PredefinedTask] = [
    // Existing tasks with taskType: .pomodoro
    PredefinedTask(name: "Pomodoro", emoji: "🍅", icon: "timer", iconBgColor: "FFE4E6", iconFgColor: "E11D48", durationMinutes: 25, cycles: 4, taskType: .pomodoro),
    // ... other existing tasks ...

    // NEW: Meeting task
    PredefinedTask(
        name: "Meeting",
        emoji: "📅",
        icon: "calendar",
        iconBgColor: "E0F2FE",
        iconFgColor: "0369A1",
        durationMinutes: 30,
        cycles: 1,
        taskType: .meeting,
        availableDurations: [15, 30, 45, 60, 90, 120]
    )
]
```

---

### 2. UI Component - Meeting Duration Picker

**New File:** `Focally/Views/Shared/MeetingDurationPicker.swift`

```swift
import SwiftUI

struct MeetingDurationPicker: View {
    @Binding var selectedDuration: Int
    let availableDurations: [Int]
    let onDurationSelected: (Int) -> Void

    var body: some View {
        VStack(spacing: .extraSmall) {
            Text("Meeting Duration")
                .font(.focallyBodyBold)
                .foregroundStyle(Color.focallyOnSurface)

            Picker("Duration", selection: $selectedDuration) {
                ForEach(availableDurations, id: \.self) { minutes in
                    Text(durationText(minutes)).tag(minutes)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedDuration) { _, newValue in
                onDurationSelected(newValue)
            }
        }
        .padding(.medium)
        .background(Color.focallySurfaceContainer)
        .cornerRadius(.medium)
    }

    private func durationText(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
    }
}

#Preview {
    MeetingDurationPicker(
        selectedDuration: .constant(30),
        availableDurations: [15, 30, 45, 60, 90, 120],
        onDurationSelected: { _ in }
    )
}
```

---

### 3. FocusIntegrationService - Slack Status with Task Type

**File:** `Focally/Services/FocusIntegrationService.swift`

**Modify updateSlackStatus to check task type:**

Find the method that updates Slack status and modify it:

```swift
private func updateSlackStatus(for task: PredefinedTask) {
    let emoji: String
    let statusText: String

    // NEW: Check task type and set appropriate emoji
    switch task.taskType {
    case .meeting:
        // Use :google-meet: emoji for meetings
        emoji = ":google-meet:"
        statusText = "En meeting"
    case .deepWork:
        emoji = "🧠"
        statusText = "Deep work"
    case .pomodoro:
        // Use task's default emoji for pomodoro
        emoji = task.emoji
        statusText = "Focus time"
    }

    // NEW: Set expiration timestamp based on duration
    let expirationTimestamp = Int(Date().addingTimeInterval(TimeInterval(task.durationMinutes * 60)).timeIntervalSince1970)

    slackService.setStatus(
        text: statusText,
        expirationTimestamp: expirationTimestamp,
        taskEmoji: emoji
    )
}
```

**Important:** Add this method call in both:
- `startSession(for:)` - when meeting starts
- `updateSession(for:)` - when meeting duration changes

---

### 4. FocusIntegrationService - macOS DND Integration for Meetings

**File:** `Focally/Services/FocusIntegrationService.swift`

**Add DND activation/deactivation for meetings:**

Modify the `startSession(for:)` method to activate DND for meetings:

```swift
func startSession(for task: PredefinedTask, duration: Int) async {
    // Update Slack status
    updateSlackStatus(for: task)

    // NEW: Activate macOS DND for meetings
    if task.taskType == .meeting {
        logger.info("Activating macOS DND for meeting session")
        dndService.activateDND()
    }

    // Start timer
    await focusTimerService.startSession(
        activity: task.name,
        emoji: task.emoji,
        durationMinutes: duration,
        cycles: task.cycles
    )
}
```

Modify the `endSession()` method to deactivate DND for meetings:

```swift
func endSession() async {
    let currentTaskType = getCurrentTaskType()

    // NEW: Deactivate macOS DND if ending a meeting
    if currentTaskType == .meeting {
        logger.info("Deactivating macOS DND after meeting session")
        dndService.deactivateDND()
    }

    // Clear Slack status
    slackService.clearStatus()

    // Stop timer
    await focusTimerService.stopSession()
}

// Helper method to get current task type
private func getCurrentTaskType() -> TaskType? {
    // This depends on how FocusIntegrationService tracks current task
    // Implement based on existing state management
    return .meeting // Placeholder - update with actual implementation
}
```

---

### 5. PredefinedTasksList - Show Task Type and Duration Picker

**File:** `Focally/Views/Tasks/PredefinedTasksList.swift`

**Add UI to show task type:**

```swift
struct TaskRowView: View {
    let task: PredefinedTask
    @State private var selectedDuration: Int
    let onTaskSelected: (Int) -> Void

    init(task: PredefinedTask, onTaskSelected: @escaping (Int) -> Void) {
        self.task = task
        self._selectedDuration = State(initialValue: task.durationMinutes)
        self.onTaskSelected = onTaskSelected
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .extraSmall) {
            HStack {
                // Task name with type badge
                Text(task.name)
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyOnSurface)

                // NEW: Task type badge
                Text(task.taskType.displayName.uppercased())
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
                    .padding(.extraSmall)
                    .background(Color.focallySurfaceContainerHigh)
                    .cornerRadius(.extraSmall)
            }

            // NEW: Show duration picker for meeting type
            if task.taskType == .meeting {
                MeetingDurationPicker(
                    selectedDuration: $selectedDuration,
                    availableDurations: task.availableDurations
                ) { duration in
                    // Duration changed, update selection
                }
            } else {
                // Show default duration for non-meeting tasks
                Text("\(task.durationMinutes) min")
                    .font(.focallyBody)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
            }
        }
        .padding(.medium)
        .background(Color.focallySurface)
        .cornerRadius(.medium)
        .onTapGesture {
            onTaskSelected(selectedDuration)
        }
    }
}
```

---

## 🎨 UI/UX Requirements

### Design Tokens Usage
- Use `Color.focallySurface` for task row background
- Use `Color.focallySurfaceContainer` for picker background
- Use `.medium` spacing and `.medium` corner radius
- Use `.focallyBodyBold` for headings
- Use `.focallyBody` for body text

### Visual Hierarchy
1. Task name (bold) + type badge (small, subtle)
2. Duration picker (only for meetings)
3. Action button (start task)

### Accessibility
- MeetingDurationPicker should have proper labels
- Picker should be keyboard accessible
- Duration selection should announce changes with VoiceOver

---

## 🧪 Testing

### Manual Testing Checklist

#### 1. Meeting Task in List
- [ ] "Meeting" task appears in predefined tasks list
- [ ] Task type badge "MEETING" is visible
- [ ] Default duration is 30 minutes

#### 2. Duration Selection
- [ ] Duration picker appears when meeting task is visible
- [ ] All durations are available: 15m, 30m, 45m, 60m, 90m, 120m
- [ ] Duration text formats correctly: "15m", "1h", "1h 30m", "2h"
- [ ] Selecting different durations updates the selected value

#### 3. Start Meeting
- [ ] Tapping meeting task starts timer with correct duration
- [ ] Timer countdown matches selected duration
- [ ] Session info shows "En meeting" with correct time

#### 4. Slack Integration
- [ ] When meeting starts, Slack status shows "En meeting"
- [ ] Slack emoji is `:google-meet:` (or Unicode equivalent if not available)
- [ ] Status expiration time is set correctly (meeting end time)
- [ ] When meeting ends, Slack status is cleared

#### 5. macOS DND (Do Not Disturb) - CRITICAL
- [ ] When meeting starts, macOS DND is activated
- [ ] ALL notifications are blocked (Slack, email, system, iMessage, etc.)
- [ ] No notification icons bounce or appear in menu bar during meeting
- [ ] When meeting ends naturally, macOS DND is deactivated
- [ ] When meeting is stopped early, macOS DND is deactivated immediately
- [ ] DND state is restored to user's previous preference after meeting

#### 6. Non-Meeting Tasks
- [ ] Pomodoro tasks still work as before
- [ ] Deep Work tasks still work as before
- [ ] Duration picker does NOT appear for non-meeting tasks

### Edge Cases

#### Meeting with No Slack Connection
- [ ] Meeting timer starts without Slack integration
- [ ] No error shown if Slack is disabled
- [ ] App continues to work normally

#### Meeting Interrupted
- [ ] Stopping meeting early clears Slack status
- [ ] Stopping meeting early deactivates macOS DND IMMEDIATELY
- [ ] Timer stops immediately
- [ ] Session is recorded correctly in history

#### DND Failure Handling
- [ ] If DNDService fails to activate, meeting continues with warning
- [ ] If DNDService fails to deactivate, attempt retry on next session
- [ ] Log DND activation/deactivation failures to Logger.dnd

#### Workspace Without :google-meet: Emoji
- [ ] If emoji is not available, use fallback "📅"
- [ ] No crash or error if emoji is invalid

---

## 🔒 Breaking Changes

### Migration Required
- `PredefinedTask` struct has new properties: `taskType` and `availableDurations`
- Existing user-defined tasks in UserDefaults need migration
- Default values should be `.pomodoro` and `[durationMinutes]` for backward compatibility

**Migration Strategy:**
```swift
// In PredefinedTaskStore
private static func loadTasks(from defaults: UserDefaults) -> [PredefinedTask] {
    guard let data = defaults.data(forKey: PredefinedTask.defaultsKey),
          var tasks = try? JSONDecoder().decode([PredefinedTask].self, from: data) else {
        return PredefinedTask.defaultTasks
    }

    // NEW: Add taskType and availableDurations to existing tasks if missing
    tasks = tasks.map { task in
        // Check if task was saved before taskType existed
        // If so, provide default values for new properties
        // This is handled by default values in init()
        return task
    }

    return tasks
}
```

---

## 📝 Notes

### Slack Emoji Format
- Slack uses shortcode format: `:google-meet:`
- If the workspace doesn't have this emoji installed, Slack will show the shortcode text
- Consider adding a check in `SlackService` to validate if emoji exists
- Fallback emoji: "📅" (calendar) or "📞" (phone)

### Time Persistence
- Selected meeting duration should be saved to UserDefaults
- Use key: `focally.meeting.defaultDuration`
- Restore last selected duration on next meeting

### Future Enhancements
- Custom duration input (manual minute entry)
- Sync with Google Calendar events
- More meeting categories: "Code Review", "1:1", "Standup"
- Meeting notes integration

---

## 🔗 Dependencies

### Files to Modify
1. `Focally/Models/PredefinedTask.swift` - Add task type and durations
2. `Focally/Services/FocusIntegrationService.swift` - Slack emoji logic + DND activation
3. `Focally/Views/Tasks/PredefinedTasksList.swift` - Show picker for meetings
4. `Focally/Views/Tasks/TaskRowView.swift` - Task row with duration picker
5. `Focally/Services/DNDService.swift` - Ensure proper DND blocking implementation

### Files to Create
1. `Focally/Views/Shared/MeetingDurationPicker.swift` - New component

### Related Specs
- TASK-028-SPEC.md - Slack integration
- TASK-025.md - Focus integration

---

## ✅ Acceptance Criteria

- [ ] User can select "Meeting" from predefined tasks
- [ ] User can choose meeting duration from available options
- [ ] Timer starts with selected duration
- [ ] Slack status updates to "En meeting" with `:google-meet:` emoji
- [ ] **macOS DND is activated when meeting starts** ✅ CRITICAL
- [ ] **ALL notifications are blocked during meeting (no bouncing icons)** ✅ CRITICAL
- [ ] Status expires automatically when meeting ends
- [ ] **macOS DND is deactivated when meeting ends** ✅ CRITICAL
- [ ] **macOS DND is deactivated immediately when meeting is stopped early** ✅ CRITICAL
- [ ] Non-meeting tasks continue to work unchanged
- [ ] All tests pass (manual and automated)
- [ ] No breaking changes for existing users
- [ ] Design tokens are used correctly
- [ ] Accessibility requirements are met

---

## 📊 Effort Breakdown

| Task | Hours | Owner | Status |
|------|-------|-------|--------|
| Add TaskType enum to PredefinedTask | 0.5h | Codex | Pending |
| Update PredefinedTask init with new properties | 0.5h | Codex | Pending |
| Create MeetingDurationPicker component | 1h | Codex | Pending |
| Update FocusIntegrationService for meeting emoji | 0.5h | Codex | Pending |
| **Integrate DNDService for meetings (activate/deactivate)** | **1h** | **Codex** | **Pending** |
| Update PredefinedTasksList UI | 1h | Codex | Pending |
| Add migration logic for existing tasks | 0.5h | Codex | Pending |
| **Verify DND blocks all notifications (Slack, email, system)** | **0.5h** | **Eliab** | **Pending** |
| Manual testing and validation | 0.5h | Eliab | Pending |
| **Total** | **5.5h** | | |

---

**Implementation blocked on:** None
**Dependencies merged:** None
**Next step:** Delegate to Codex for implementation
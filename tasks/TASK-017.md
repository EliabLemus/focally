# TASK-017: Split SettingsView into Tab Views

## Status: TODO

## Date: 2026-05-01

## Objective
`SettingsView.swift` is 941 lines — a God View that makes it hard to find anything, risky to edit, and impossible to reuse components. Split it into 6 separate tab view files plus a shared components file.

## Files to Create
- `Focally/Views/Settings/TimerSettingsTab.swift` (~100 lines)
- `Focally/Views/Settings/PomodoroSettingsTab.swift` (~120 lines)
- `Focally/Views/Settings/TasksSettingsTab.swift` (~80 lines)
- `Focally/Views/Settings/ConnectionsSettingsTab.swift` (~100 lines)
- `Focally/Views/Settings/SecretsSettingsTab.swift` (~120 lines)
- `Focally/Views/Settings/AppearanceSettingsTab.swift` (~50 lines)
- `Focally/Views/Settings/SharedSettingsComponents.swift` (~80 lines)

## Files to Modify
- `Focally/Views/SettingsView.swift` → Slim coordinator (~120 lines: frame, tabs, save button, load/save, draft management)

## Detailed Specification

### New Architecture

```
SettingsView (coordinator)
├── TimerSettingsTab (durations, sounds)
├── PomodoroSettingsTab (work/break durations, rounds, sounds per phase)
├── TasksSettingsTab (predefined tasks CRUD)
├── ConnectionsSettingsTab (Slack toggle, Google toggle, status emoji)
├── SecretsSettingsTab (Slack token, Google credentials)
└── AppearanceSettingsTab (theme toggle)
```

### SharedSettingsComponents.swift

Extract reusable components that multiple tabs need:

```swift
import SwiftUI

// Shared between TimerSettingsTab and PomodoroSettingsTab
struct SoundPickerRow: View {
    let soundOption: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(soundOption)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(isSelected ? 0.16 : 0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

// Shared scroll container for consistent tab layout
struct SettingsTabContent<Content: View>: View {
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
```

This eliminates the **duplicated `soundRow` and `soundPickerRows` functions** (issue M3 from code review).

### SettingsView.swift (coordinator)

Slim down to:

```swift
struct SettingsView: View {
    @EnvironmentObject var slackService: SlackService
    @EnvironmentObject var calendarService: GoogleCalendarService
    var onSave: (() -> Void)? = nil
    
    // Draft state
    @State private var draft = SettingsDraft.default
    
    // Input states
    @State private var newDuration = ""
    @State private var newTaskName = ""
    @State private var newTaskEmoji = "📝"
    @State private var saveButtonTitle = "Save Changes"
    @FocusState private var focusedField: Field?
    
    // Secrets (Keychain, not UserDefaults)
    @State private var draftSlackToken = ""
    @State private var draftGoogleClientID = ""
    @State private var draftGoogleClientSecret = ""
    
    var body: some View {
        VStack(spacing: 0) {
            TabView {
                SettingsTabContent {
                    TimerSettingsTab(draft: $draft, newDuration: $newDuration)
                }
                .tabItem { Label("Timer", systemImage: "timer") }
                
                SettingsTabContent {
                    PomodoroSettingsTab(draft: $draft)
                }
                .tabItem { Label("Pomodoro", systemImage: "flame") }
                
                SettingsTabContent {
                    TasksSettingsTab(draft: $draft, newTaskName: $newTaskName, newTaskEmoji: $newTaskEmoji)
                }
                .tabItem { Label("Tasks", systemImage: "checklist") }
                
                SettingsTabContent {
                    ConnectionsSettingsTab(draft: $draft, slackService: slackService)
                }
                .tabItem { Label("Connections", systemImage: "link") }
                
                SettingsTabContent {
                    SecretsSettingsTab(
                        slackService: slackService,
                        calendarService: calendarService,
                        slackToken: $draftSlackToken,
                        googleClientID: $draftGoogleClientID,
                        googleClientSecret: $draftGoogleClientSecret,
                        focusedField: _focusedField
                    )
                }
                .tabItem { Label("Secrets", systemImage: "key.fill") }
                
                SettingsTabContent {
                    AppearanceSettingsTab(draft: $draft)
                }
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            }
            .frame(maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
            
            Divider()
            
            HStack {
                Spacer()
                Button(saveButtonTitle) { saveSettings() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!hasUnsavedChanges)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 420, minHeight: 430)
        .onAppear(perform: loadSettings)
    }
}
```

### TimerSettingsTab.swift

Receives `draft: Binding<SettingsDraft>` and `newDuration: Binding<String>`.
Contains: focus durations grid, add/remove duration, alert sound toggle, sound picker, repeat stepper.

### PomodoroSettingsTab.swift

Contains: work/break/long-break duration steppers, rounds until long break, auto-start toggle, per-phase sound pickers, volume slider.

### TasksSettingsTab.swift

Contains: predefined tasks CRUD (add/remove), task name input, emoji picker.

### ConnectionsSettingsTab.swift

Contains: Slack toggle + status + emoji picker, Google Calendar toggle + sign in/out button + connection status.

### SecretsSettingsTab.swift

Contains: Slack token input, Google Client ID + Client Secret inputs, test connection buttons.

### AppearanceSettingsTab.swift

Contains: system theme toggle.

## Acceptance Criteria
- [ ] 7 new files created in `Focally/Views/Settings/`
- [ ] `SettingsView.swift` reduced to ~120-150 lines (coordinator only)
- [ ] No duplicated sound picker code (`soundRow` + `soundPickerRows` → single `SoundPickerRow`)
- [ ] All tabs work identically to current behavior
- [ ] Save/Load still works across all tabs
- [ ] Build succeeds
- [ ] Double padding in secretsTab (L5) fixed

## Priority
**v0.6.0** — Prep work for TASK-016 (@Observable migration is easier with smaller files)

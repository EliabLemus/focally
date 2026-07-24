# Task: Focus Mode Edit Sheet Improvements

**Assignee**: Codex (OpenAI CLI)
**Target Version**: v0.9.0
**Priority**: High
**Effort Estimate**: 2-3 hours
**Risk**: Low (UI-only changes)

---

## Context

User feedback on v0.9.0 testing revealed:
1. Emoji picker not discoverable (users must know to type `:`)
2. UI hierarchy confusing (3-level nesting: DND → Pomodoro → Settings)
3. Status message field lacks emoji support (inconsistent UX)

**Research documented**: `docs/research/v0.9.0-focus-mode-edit-improvements.md`

---

## Objective

Improve Focus Mode Edit Sheet UX with:
1. Visible emoji trigger buttons on all emoji fields
2. Simplified 2-level UI hierarchy
3. Emoji picker for Status Message field
4. Multi-language support (EN/ES/PT)

---

## Implementation

### Phase 1: Emoji Trigger Buttons

#### 1.1 Mode Emoji Field (`FocusModeEditSheet.swift`)

**Location**: Line 56-61

**Current code**:
```swift
TextField(
    draftMode.name.isEmpty ? String(localized: "edit_mode_emoji_placeholder_search") : draftMode.emoji,
    text: $draftMode.emoji
)
.textFieldStyle(.roundedBorder)
```

**Replace with**:
```swift
HStack(spacing: 8) {
    TextField(
        draftMode.name.isEmpty ? String(localized: "edit_mode_emoji_placeholder_search") : draftMode.emoji,
        text: $draftMode.emoji
    )
    .textFieldStyle(.roundedBorder)

    Button {
        showEmojiPicker.toggle()
        if showEmojiPicker {
            recentEmojis = usageTracker.getRecentEmojis(forWorkspace: slackService.workspaceEmojiCodes)
        }
    } label: {
        Image(systemName: "face.smiling")
            .font(.system(size: 16))
            .foregroundStyle(Color.focallyOnSurfaceVariant)
    }
    .buttonStyle(.plain)
    .help(String(localized: "emoji_picker_help"))
}
```

---

#### 1.2 Break Label Field (`FocusModeEditSheet.swift`)

**Location**: Line 181-183

**Current code**:
```swift
TextField(String(localized: "edit_mode_break_placeholder"), text: breakLabelBinding)
    .textFieldStyle(.roundedBorder)
```

**Replace with**:
```swift
HStack(spacing: 8) {
    TextField(String(localized: "edit_mode_break_placeholder"), text: breakLabelBinding)
        .textFieldStyle(.roundedBorder)

    Button {
        showBreakLabelEmojiPicker.toggle()
        if showBreakLabelEmojiPicker {
            breakLabelRecentEmojis = usageTracker.getRecentEmojis(forWorkspace: slackService.workspaceEmojiCodes)
        }
    } label: {
        Image(systemName: "face.smiling")
            .font(.system(size: 16))
            .foregroundStyle(Color.focallyOnSurfaceVariant)
    }
    .buttonStyle(.plain)
    .help(String(localized: "emoji_picker_help"))
}
```

---

#### 1.3 Status Message Field (`FocusModeEditSheet.swift`)

**Location**: Line 171-175

**Current code**:
```swift
VStack(alignment: .leading, spacing: 8) {
    Text("edit_mode_status_message")
        .font(.focallyBodyBold)
    TextField(String(localized: "edit_mode_status_placeholder"), text: $draftMode.statusText)
        .textFieldStyle(.roundedBorder)
}
```

**Replace with**:
```swift
VStack(alignment: .leading, spacing: 8) {
    Text("edit_mode_status_message")
        .font(.focallyBodyBold)

    HStack(spacing: 8) {
        TextField(String(localized: "edit_mode_status_placeholder"), text: $draftMode.statusText)
            .textFieldStyle(.roundedBorder)

        Button {
            showStatusEmojiPicker.toggle()
            if showStatusEmojiPicker {
                statusRecentEmojis = usageTracker.getRecentEmojis(forWorkspace: slackService.workspaceEmojiCodes)
            }
        } label: {
            Image(systemName: "face.smiling")
                .font(.system(size: 16))
                .foregroundStyle(Color.focallyOnSurfaceVariant)
        }
        .buttonStyle(.plain)
        .help(String(localized: "emoji_picker_help"))
    }

    // Emoji picker overlay for status message (same UI as mode emoji picker)
    if showStatusEmojiPicker && (!statusRecentEmojis.isEmpty || !statusSearchResults.isEmpty) {
        VStack(alignment: .leading, spacing: 4) {
            ScrollView {
                if !statusSearchResults.isEmpty {
                    LazyVStack(spacing: 2) {
                        ForEach(statusSearchResults, id: \.shortcode) { item in
                            Button {
                                draftMode.statusText += item.shortcode
                                showStatusEmojiPicker = false
                                statusSearchResults = []
                            } label: {
                                HStack(spacing: 8) {
                                    Text(item.emoji.isEmpty ? "🔗" : item.emoji)
                                        .font(.system(size: 20))
                                        .frame(width: 30, alignment: .center)
                                    Text(item.shortcode)
                                        .font(.focallyBody)
                                        .foregroundStyle(Color.focallyOnSurface)
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                        ForEach(statusRecentEmojis, id: \.self) { emoji in
                            let display = EmojiValidator.convertShortcodeToUnicode(emoji, workspaceEmojis: slackService.workspaceEmojiCodes) ?? emoji
                            Button {
                                draftMode.statusText += emoji
                                showStatusEmojiPicker = false
                            } label: {
                                Text(display)
                                    .font(.system(size: 22))
                                    .frame(width: 36, height: 36)
                                    .background(Color.focallySurfaceVariant.opacity(0.3))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .help(emoji)
                        }
                    }
                }
            }
            .frame(maxHeight: 140)
        }
        .padding(8)
        .background(Color.focallySurfaceVariant)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .offset(y: 36)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.easeOut(duration: 0.15), value: showStatusEmojiPicker)
    }
}
```

---

#### 1.4 Add State Variables for Status Message Picker

**Location**: Top of struct (after line 44)

**Add**:
```swift
@State private var showStatusEmojiPicker = false
@State private var statusRecentEmojis: [String] = []
@State private var statusSearchResults: [(shortcode: String, emoji: String)] = []
```

---

#### 1.5 Add Search Query for Status Message

**Location**: After line 39 (after `breakLabelSearchQuery`)

**Add**:
```swift
private var statusSearchQuery: String {
    let t = draftMode.statusText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard t.hasPrefix(":"), t.count > 1 else { return "" }
    return String(t.dropFirst()).trimmingCharacters(in: CharacterSet(charactersIn: ": "))
}
```

---

#### 1.6 Add Search Logic for Status Message

**Location**: After line 199 (after `breakLabelBinding` onChange)

**Add**:
```swift
.onChange(of: draftMode.statusText) { _, newValue in
    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed == ":" {
        showStatusEmojiPicker = true
        statusRecentEmojis = usageTracker.getRecentEmojis(forWorkspace: slackService.workspaceEmojiCodes)
        statusSearchResults = []
    } else if trimmed.hasPrefix(":") && trimmed.count > 1 {
        showStatusEmojiPicker = true
        statusRecentEmojis = []
        let q = String(trimmed.dropFirst()).trimmingCharacters(in: CharacterSet(charactersIn: ": "))
        statusSearchResults = EmojiValidator.searchShortcodes(q, workspaceEmojiCodes: slackService.workspaceEmojiCodes)
    } else {
        showStatusEmojiPicker = false
        statusSearchResults = []
    }
}
```

---

#### 1.7 Close Picker on Tap

**Location**: Line 317-321 (current `onTapGesture`)

**Update**:
```swift
.onTapGesture {
    if showEmojiPicker {
        showEmojiPicker = false
    }
    if showBreakLabelEmojiPicker {
        showBreakLabelEmojiPicker = false
    }
    if showStatusEmojiPicker {
        showStatusEmojiPicker = false
    }
}
```

---

### Phase 2: UI Hierarchy Simplification

#### 2.1 Restructure ScrollView Content

**Location**: Line 51-291 (ScrollView body)

**Current structure** (3-level nesting):
```swift
ScrollView {
    VStack(alignment: .leading, spacing: 18) {
        // Mode Emoji
        // Status Message
        // Break Label (if pomodoro)
        // Duration
        // Toggle: Enable DND
        // Toggle: Enable Pomodoro (if DND)
        // DisclosureGroup: Pomodoro Settings (if DND + Pomodoro)
    }
}
```

**Replace with** (2-level structure):
```swift
ScrollView {
    VStack(alignment: .leading, spacing: 20) {
        // ========== Section: Basic Settings ==========
        Text("edit_mode_section_basic")
            .font(.focallyH3)
            .foregroundStyle(Color.focallyOnSurface)

        VStack(alignment: .leading, spacing: 18) {
            // Mode Emoji field (from Phase 1)
            VStack(alignment: .leading, spacing: 8) {
                Text("edit_mode_emoji")
                    .font(.focallyBodyBold)

                // Mode emoji picker with trigger button (from 1.1)
                // ... (existing emoji picker code)
            }

            // Status Message field (from Phase 1)
            VStack(alignment: .leading, spacing: 8) {
                Text("edit_mode_status_message")
                    .font(.focallyBodyBold)

                // Status message with emoji picker (from 1.3)
                // ... (new status message code)
            }

            // Break Label field (always visible, not hidden in pomodoro)
            VStack(alignment: .leading, spacing: 8) {
                Text("edit_mode_break_label")
                    .font(.focallyBodyBold)

                // Break label with emoji picker (from 1.2)
                // ... (existing break label code)
            }

            // Duration
            VStack(alignment: .leading, spacing: 8) {
                Text("edit_mode_duration")
                    .font(.focallyBodyBold)
                Stepper("\(draftMode.durationMinutes) min", value: $draftMode.durationMinutes, in: 5...120, step: 5)
            }
        }

        Divider()
            .background(Color.focallyOutlineVariant)
            .padding(.vertical, 8)

        // ========== Section: Advanced Settings ==========
        Text("edit_mode_section_advanced")
            .font(.focallyH3)
            .foregroundStyle(Color.focallyOnSurface)

        VStack(alignment: .leading, spacing: 18) {
            // DND Toggle (independent, not parent of Pomodoro)
            Toggle("edit_mode_enable_dnd", isOn: $draftMode.enableDND)
                .font(.focallyBody)

            // Pomodoro Toggle (independent, not nested in DND)
            Toggle("edit_mode_enable_pomodoro", isOn: $draftMode.enablePomodoro)
                .font(.focallyBody)

            // Pomodoro Settings (DisclosureGroup, independent of DND)
            if draftMode.enablePomodoro {
                DisclosureGroup("edit_mode_pomodoro_settings") {
                    VStack(alignment: .leading, spacing: 12) {
                        Stepper(String(format: String(localized: "edit_mode_work"), draftMode.pomodoroWorkMinutes), value: $draftMode.pomodoroWorkMinutes, in: 5...120, step: 5)
                        Stepper(String(format: String(localized: "edit_mode_short_break"), draftMode.pomodoroBreakMinutes), value: $draftMode.pomodoroBreakMinutes, in: 1...30, step: 1)
                        Stepper(String(format: String(localized: "edit_mode_long_break"), draftMode.pomodoroLongBreakMinutes), value: $draftMode.pomodoroLongBreakMinutes, in: 5...60, step: 5)
                        Stepper(String(format: String(localized: "edit_mode_rounds"), draftMode.pomodoroRounds), value: $draftMode.pomodoroRounds, in: 1...12, step: 1)
                    }
                    .padding(.top, 8)
                }
                .padding(.top, 8)
            }
        }
    }
}
```

---

### Phase 3: Multi-Language Strings

#### 3.1 Add to `Focally/Resources/en.lproj/Localizable.strings`

**Add 3 keys**:
```strings
/* Focus Mode Edit Sheet - Section Headers */
"edit_mode_section_basic" = "Basic Settings";
"edit_mode_section_advanced" = "Advanced Settings";
"emoji_picker_help" = "Insert emoji";
```

---

#### 3.2 Add to `Focally/Resources/es.lproj/Localizable.strings`

**Add 3 keys**:
```strings
/* Focus Mode Edit Sheet - Section Headers */
"edit_mode_section_basic" = "Configuración Básica";
"edit_mode_section_advanced" = "Configuración Avanzada";
"emoji_picker_help" = "Insertar emoji";
```

---

#### 3.3 Add to `Focally/Resources/pt.lproj/Localizable.strings`

**Add 3 keys**:
```strings
/* Focus Mode Edit Sheet - Section Headers */
"edit_mode_section_basic" = "Configurações Básicas";
"edit_mode_section_advanced" = "Configurações Avançadas";
"emoji_picker_help" = "Inserir emoji";
```

---

## Files to Modify

1. `Focally/Views/Timer/FocusModeEditSheet.swift` (primary)
   - Add emoji trigger buttons (3 fields)
   - Add status message emoji picker
   - Restructure UI hierarchy (2 levels)
   - Add state variables for status picker

2. `Focally/Resources/en.lproj/Localizable.strings` (add 3 keys)
3. `Focally/Resources/es.lproj/Localizable.strings` (add 3 keys)
4. `Focally/Resources/pt.lproj/Localizable.strings` (add 3 keys)

---

## Validation Criteria

### Phase 1: Emoji Trigger Buttons

- ✅ Mode emoji field has visible 😊 button next to text field
- ✅ Break label field has visible 😊 button next to text field
- ✅ Status message field has visible 😊 button next to text field
- ✅ Clicking 😊 button opens emoji picker (grid of recent emojis)
- ✅ Type `:` in any emoji field triggers search
- ✅ Clicking emoji inserts shortcode into text field
- ✅ Status message picker works with search and recent emojis

### Phase 2: UI Hierarchy

- ✅ All basic settings visible without opening any accordion
- ✅ Section headers visible ("Basic Settings", "Advanced Settings")
- ✅ DND and Pomodoro toggles are independent (not nested)
- ✅ Pomodoro settings in DisclosureGroup (not nested under DND)
- ✅ Maximum nesting level: 2 (not 3)

### Phase 3: Multi-Language

- ✅ Strings added to EN/ES/PT files
- ✅ Section headers display correctly in all languages
- ✅ Emoji picker help text displays correctly

### Build & Tests

- ✅ `xcodebuild -configuration Release build` → SUCCEEDED
- ✅ `xcodebuild test` → SUCCEEDED (34 tests)
- ✅ No SwiftUI preview errors
- ✅ No runtime crashes

---

## Technical Constraints

- **Do not modify**: `EmojiValidator.swift`, `EmojiUsageTracker.swift`, `SlackService.swift`
- **Preserve**: Existing emoji picker logic (search, recent emojis, caching)
- **Compatibility**: Must work with both Unicode emojis and custom Slack workspace emojis
- **FocusModeEditSheet frame**: Keep at `width: 420, height: 520` (or adjust if needed for ScrollView)

---

## Edge Cases

### Emoji Picker Overlap

- **Scenario**: Multiple emoji pickers open simultaneously
- **Solution**: Close other pickers when one opens (auto-exclusive)

### Status Message Emoji Insertion

- **Scenario**: User clicks emoji in picker → should append to existing text
- **Solution**: `draftMode.statusText += item.shortcode` (append, not replace)

### Empty Fields

- **Scenario**: User leaves emoji fields empty
- **Solution**: Preserve existing behavior (default emoji or validation)

### Long Status Messages

- **Scenario**: User types long status message + emoji
- **Solution**: TextField handles scrolling, no extra validation needed

---

## Testing Checklist

**Manual Testing** (after build):
1. Open Focus Mode Edit Sheet
2. Click 😊 button on Mode Emoji → picker opens
3. Type `:rocket:` → search results show
4. Click emoji → inserted into field
5. Repeat for Break Label field
6. Repeat for Status Message field
7. Verify section headers display in EN/ES/PT
8. Verify DND and Pomodoro toggles are independent
9. Verify Pomodoro settings in DisclosureGroup
10. Test all language switches

**Automated Testing**:
- Build: `xcodebuild -project Focally.xcodeproj -scheme Focally -configuration Release build`
- Test: `xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS'`

---

## Success Metrics

- ✅ 3/3 emoji fields have visible trigger button
- ✅ UI nesting reduced from 3 levels to 2 levels
- ✅ All basic settings visible without opening accordions
- ✅ Build succeeds
- ✅ All 34 tests pass
- ✅ No SwiftUI preview errors

---

## Notes

**Emoji Picker UI Pattern**: Reuse existing emoji picker UI structure (lines 90-146) for status message field. Only change is appending emoji to text instead of replacing.

**UI Hierarchy**: Make Pomodoro toggle independent of DND. This matches user expectation: DND controls system notifications, Pomodoro controls session rhythm. They are orthogonal features.

**Section Headers**: Use `Text("edit_mode_section_basic").font(.focallyH3)` to match existing Focally typography system.

**Button Help Text**: Use `.help(String(localized: "emoji_picker_help"))` for accessibility and discoverability.

---

## References

- Research: `docs/research/v0.9.0-focus-mode-edit-improvements.md`
- Current file: `Focally/Views/Timer/FocusModeEditSheet.swift`
- String files: `Focally/Resources/{en,es,pt}.lproj/Localizable.strings`
- Typography system: Check `Focally/Design/` for `.focallyH3` definition

---

**When complete**: Commit changes with message "feat: improve focus mode edit sheet UX - emoji triggers + 2-level hierarchy"
# TASK-041: Implement Apple Shortcuts Onboarding Wizard

## Overview
Create a complete onboarding experience for first-time users to set up Apple Shortcuts integration with Focally.

## Goals
- Guide users through shortcut generation and importation on first launch
- Verify shortcuts are properly installed and working
- Allow users to skip and continue using Focally without shortcuts
- Provide ability to reset onboarding for testing

## Requirements

### 1. Onboarding View (`Focally/Views/Onboarding/ShortcutOnboardingView.swift`)
Create a new SwiftUI view with:

**UI Components:**
- Title: "Setup Apple Shortcuts"
- Subtitle: "Connect Focally to Apple Focus modes"
- Card with steps (checklist):
  1. ✅ Generate Shortcuts
  2. 📁 Shortcuts Ready
  3. 📥 Import to Focally
  4. ✅ Verified

**Status Indicators:**
- "Generating..." (when shortcuts are being created)
- "Shortcuts Created ✅" (when ready to import)
- "Drag & Drop Below ↓" (visual cue for drop zone)
- "Import Failed ❌" (if verification fails)
- "Setup Complete ✅" (all steps done)

**Buttons:**
- "Generate Shortcuts" (initial state)
- "Open Shortcuts App" (when shortcuts exist)
- "Open Focally" (when onboarding is done)
- "Skip for Now" (always available, leads to main app)

**Visual Cues:**
- Drop zone at bottom when shortcuts are ready
- Instructions: "Drag shortcuts here to import"
- Animated checkmark when complete

### 2. OnItFocusApp Integration
Modify `Focally/OnItFocusApp.swift`:

- Add `@AppStorage("hasCompletedOnboarding")` flag
- Show `ShortcutOnboardingView` as full-screen sheet or window if not completed
- Pass dependencies: `TestShortcutGenerator`, `ShortcutDropHandler`
- Auto-close onboarding when user clicks "Done" or "Skip"

### 3. TestShortcutGenerator Enhancements
Modify `Focally/Services/TestShortcutGenerator.swift`:

Add new methods:

```swift
// Check if shortcut files exist in Application Support
func shortcutsExist() -> Bool

// Verify shortcuts are installed in Apple Shortcuts app
func verifyShortcutsInstalled() throws -> Bool

// Clear the generation flag (for testing/onboarding reset)
func resetGenerationFlag()
```

### 4. Integrations Settings Enhancement
Modify `Focally/Views/Settings/IntegrationsSettingsView.swift`:

- Add "Reset Onboarding" button in Apple Focus section
- Clears both flags:
  - `hasCompletedOnboarding`
  - `hasGeneratedTestShortcuts`
- Requires confirmation alert

## Technical Details

### State Management
Use `@Published` properties in `ShortcutOnboardingViewModel`:

```swift
class ShortcutOnboardingViewModel: ObservableObject {
    @Published var isGenerating: Bool = false
    @Published var shortcutsGenerated: Bool = false
    @Published var shortcutsVerified: Bool = false
    @Published var generationError: String?

    func generateShortcuts()
    func verifyShortcuts()
    func completeOnboarding()
}
```

### Verification Logic

**File existence check:**
```swift
fileManager.fileExists(atPath: "Focally Start Focus.shortcut")
fileManager.fileExists(atPath: "Focally End Focus.shortcut")
```

**Apple Shortcuts app check:**
```swift
// Try to run shortcuts
shortcuts run "Focally Start Focus"
// If exit code == 0 → installed
```

### File Structure
```
Focally/
├── Views/
│   └── Onboarding/
│       └── ShortcutOnboardingView.swift (NEW)
├── ViewModels/
│   └── ShortcutOnboardingViewModel.swift (NEW)
├── Services/
│   └── TestShortcutGenerator.swift (MODIFY)
├── OnItFocusApp.swift (MODIFY)
└── Views/Settings/
    └── IntegrationsSettingsView.swift (MODIFY)
```

## Acceptance Criteria

### Must Have:
- [ ] Onboarding shows on first launch
- [ ] Shortcuts generate successfully
- [ ] User can drag & drop shortcuts to import
- [ ] Verification confirms shortcuts work
- [ ] "Skip for Now" allows normal usage without shortcuts
- [ ] "Reset Onboarding" button in Settings works
- [ ] All builds compile without errors

### Should Have:
- [ ] Smooth animations for state transitions
- [ ] Clear visual feedback for drag & drop
- [ ] Helpful error messages if generation fails
- [ ] Accessible labels for all UI elements

### Nice to Have:
- [ ] Progress indicator during generation
- [ ] Screenshot or diagram showing the flow
- [ ] Success celebration animation

## Testing

**Test Case 1: First Launch (Fresh Install)**
1. Reset all flags (delete defaults)
2. Open Focally
3. Expected: Onboarding appears
4. Click "Generate Shortcuts"
5. Expected: Shortcuts created, status updates
6. Drag shortcuts to drop zone
7. Expected: Import success, verification passes
8. Click "Done"
9. Expected: Onboarding closes, main app opens

**Test Case 2: Skip Onboarding**
1. Reset all flags
2. Open Focally
3. Click "Skip for Now"
4. Expected: Main app opens, Focus Integration shows as disabled

**Test Case 3: Reset Onboarding**
1. Complete onboarding
2. Open Settings → Integrations
3. Click "Reset Onboarding"
4. Confirm dialog
5. Close and reopen Focally
6. Expected: Onboarding appears again

## Notes

- Onboarding should be **skippable** at any time
- Shortcuts should be **regenerable** if user deletes them
- Focus Integration should work normally even if onboarding is skipped
- Store shortcuts in: `~/Library/Application Support/Focally/Shortcuts/`

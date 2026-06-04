# TASK-039: Fix Meeting category display, version in About, and Slack DND

**Priority:** High
**Target Version:** v0.7.29

## Summary

Fix three critical issues discovered in v0.7.28:

1. **Meeting category not visible in presets** - The new Meeting task type is not appearing in the predefined tasks list
2. **Missing version display in About view** - Users cannot see which version they're running
3. **Slack DND not working for meetings** - Slack Do Not Disturb (snooze) is not being activated during meetings

## Issues

### Issue 1: Meeting category not visible in presets
**Current Behavior:**
- The "Meeting" task with `taskType: .meeting` exists in `defaultTasks` array in `PredefinedTask.swift` (lines 68-78)
- Migration logic adds Meeting task if missing (lines 212-227)
- BUT users report that the Meeting option does not appear in the presets UI

**Expected Behavior:**
- Meeting task should be visible in the predefined tasks list immediately after v0.7.28 installation
- When tapped, should show duration picker (15m, 30m, 45m, 60m, 90m, 120m)

**Possible Root Causes:**
1. Migration only runs on app launch, but users may have existing UserDefaults data that bypasses `defaultTasks`
2. The `loadTasks` function (lines 177-185) returns existing tasks from UserDefaults without calling migration
3. Migration is called but the task is not being added correctly to the UI

**Required Fix:**
- Verify that `migrateTasksIfNeeded()` is actually adding the Meeting task to the list
- Ensure that when users upgrade from v0.7.27 (without Meeting task), the migration properly injects it
- Add logging to verify migration path
- Consider force-resetting `predefinedTasks` on major version changes if migration is unreliable

### Issue 2: Version not visible in About view
**Current Behavior:**
- Users cannot see the app version in the About screen

**Expected Behavior:**
- About view should display: "Focally v0.7.28" (or current version)

**Required Fix:**
- Locate the About view implementation
- Add version label using `Bundle.main.infoDictionary?["CFBundleShortVersionString"]` or similar
- Format: "Focally v{VERSION}"
- Add build number if needed: "(Build {BUILD_NUMBER})"

### Issue 3: Slack DND not working for meetings
**Current Behavior:**
- User reports "No se esta poniendo en modo no molestar el slack" (Slack is not going into DND mode)
- User confirmed: Expect BOTH Slack DND snooze AND macOS system DND to be activated

**Expected Behavior:**
- When a meeting starts, BOTH should activate:
  1. **macOS System DND** (already implemented in `FocusIntegrationService.performDirectFocusAction`)
  2. **Slack DND snooze** (pause Slack notifications for meeting duration)
  3. **Slack status** "En meeting" with emoji `:google-meet:`
- When meeting ends, BOTH should deactivate:
  1. macOS System DND (preserving previous state if user had it on)
  2. Slack DND snooze
  3. Slack status

**Current Implementation (FocusIntegrationService.swift):**
- Lines 246-279: `performSlackFocusAction` handles Slack integration
- Line 250: `slackService.setSlackDNDSnooze(minutes: duration)` - SHOULD activate DND snooze
- Lines 254-259: Meeting case sets status with `:google-meet:` emoji
- Lines 277-278: On end, calls `clearStatus()` and `disableSlackDND()`

**Possible Root Causes:**
1. **Slack DND snooze not working**: The `setSlackDNDSnooze` method in `SlackService` might have a bug
2. **Slack connection issue**: User's Slack connection might be broken or token expired
3. **Meeting type not passed correctly**: `taskType` might not be `.meeting` when starting
4. **Slack DND requires different API**: Maybe the DND API call is incorrect

**Required Fix:**
1. Review `SlackService.swift` implementation of `setSlackDNDSnooze()`
2. Verify the Slack DND API endpoint and parameters
3. Add detailed logging to `FocusIntegrationService.performSlackFocusAction`:
   - Log when `setSlackDNDSnooze` is called
   - Log success/failure of DND activation
   - Log status update success/failure
4. Test with real Slack API:
   - Verify that `dnd.setSnooze` API is being called with correct `num_minutes`
   - Check if user has permissions to set DND
5. Add error handling and user feedback if Slack DND fails

## Files to Review

1. **Focally/Models/PredefinedTask.swift**
   - Lines 177-185: `loadTasks` - migration trigger
   - Lines 187-232: `migrateTasksIfNeeded` - Meeting task injection
   - Add logging to verify migration is running

2. **Focally/Views/** (Find About view)
   - Search for "About" in Views directory
   - Add version display

3. **Focally/Services/SlackService.swift**
   - Find `setSlackDNDSnooze` method
   - Verify API implementation
   - Add error handling

4. **Focally/Services/FocusIntegrationService.swift**
   - Lines 246-279: `performSlackFocusAction`
   - Add comprehensive logging

## Implementation Plan

### Phase 1: Add Logging & Investigation
1. Add logging to `PredefinedTaskStore.migrateTasksIfNeeded()`:
   - Log "Migration started"
   - Log "Existing tasks: [names]"
   - Log "Meeting task found: [bool]"
   - Log "Meeting task added: [bool]"

2. Add logging to `FocusIntegrationService.performSlackFocusAction()`:
   - Log "Slack action: [start/end], taskType: [type], duration: [mins]"
   - Log "setSlackDNDSnooze called with [mins] minutes"
   - Log "Slack DND result: [success/error]"
   - Log "Slack status update result: [success/error]"

3. Locate About view and understand current implementation

### Phase 2: Implement Fixes
1. **Fix Meeting display issue:**
   - If migration logic is correct but not running, ensure it's called on every app launch
   - Consider adding a "reset to defaults" option if migration fails
   - Verify that UI is observing `PredefinedTaskStore.tasks` correctly

2. **Add version to About view:**
   - Find the view file (likely `AboutView.swift` or similar)
   - Add:
     ```swift
     VStack {
         // existing content
         if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
             Text("Focally v\(version)")
                 .font(.caption)
                 .foregroundColor(.secondary)
         }
     }
     ```

3. **Fix Slack DND:**
   - Review `SlackService.setSlackDNDSnooze()` implementation
   - Ensure it calls the correct Slack API endpoint:
     ```
     POST https://slack.com/api/dnd.setSnooze
     {
       "num_minutes": 30
     }
     ```
   - Add error handling to surface any API errors
   - Verify that the Slack token has `dnd:write` scope
   - Consider adding a "Test Slack DND" button in settings for debugging

### Phase 3: Testing
1. Clean install test:
   - Remove UserDefaults (reset app)
   - Install v0.7.29
   - Verify Meeting appears in list
   - Verify About shows correct version

2. Upgrade test:
   - Install v0.7.27 (without Meeting)
   - Upgrade to v0.7.29
   - Verify Meeting is added via migration

3. Slack integration test:
   - Connect Slack
   - Start a meeting (30m)
   - Verify Slack status shows "En meeting :google-meet:"
   - Verify Slack DND is active (send test message - should show silenced indicator)
   - Wait for meeting to end
   - Verify Slack status cleared
   - Verify Slack DND deactivated

## Acceptance Criteria

✅ Meeting task appears in predefined tasks list on fresh install of v0.7.29
✅ Meeting task is added automatically when upgrading from v0.7.27 to v0.7.29
✅ Tapping Meeting shows duration picker with 15m, 30m, 45m, 60m, 90m, 120m options
✅ About view displays "Focally v0.7.29" (or current version)
✅ Starting a meeting activates Slack DND snooze for the selected duration
✅ Starting a meeting sets Slack status to "En meeting" with :google-meet: emoji
✅ Ending a meeting deactivates Slack DND snooze
✅ Ending a meeting clears Slack status
✅ Error logging shows detailed information if Slack integration fails

## Questions for Eliab

1. **About view location**: Can you confirm where the About view is located? (Search didn't find "AboutView.swift")
2. **Meeting visibility**: Can you check if there's any custom filtering in the UI that might be hiding the Meeting task? (e.g., filtering by taskType)
3. **Slack DND**: When you say "no se está poniendo en modo no molestar el slack", do you mean:
   - The Slack status is not updating at all?
   - The status updates but the DND/silence feature is not working?
   - Both?
4. **Testing**: Would you like me to add a "Reset to Default Tasks" button in settings to help with debugging migration issues?
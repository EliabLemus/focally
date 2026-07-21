# TASK-028: UI AUTOMATED TESTS (END-TO-END FLOWS)

## Status
**Priority**: High
**Est. Time**: 1-2 hours
**Dependencies**: None

## Goal
Crear suite completa de tests UI automatizados para cubrir todos los flujos de Focally sin intervención humana.

## Context
- Ya existe `FocallyUITests/FocallyUITests.swift` con tests básicos
- Tests de bajo nivel pasan 70% (existe testing-swift skill)
- Flujos manuales pendientes:
  - DND activation flow
  - Complete timer flow
  - Google Calendar integration
  - Slack Status integration

## Requirements

### 1. Timer Flow Complete
Test must verify:
- Launch app → Open popover
- Enter task name
- Click "Start Pomodoro" → Verify timer shows 25:00 and counts up
- Click "Pause" → Verify timer stops, button changes to "Resume"
- Click "Resume" → Verify timer continues from paused time
- Click "Finish" → Verify timer resets to 0:00, button becomes "Start"
- Verify no errors in console/logs

**Implementation:**
```swift
func testCompleteTimerFlow() throws {
    // Launch and open popover
    let app = XCUIApplication()
    app.launch()
    let menuBar = app.menuBars.element(boundBy: 0)
    let focallyMenuItem = menuBar.menubarItems["Focally"]
    XCTAssertTrue(focallyMenuItem.waitForExistence(timeout: 5))
    focallyMenuItem.click()

    // Enter task
    let taskInput = app.textFields["taskInputTextField"]
    XCTAssertTrue(taskInput.waitForExistence(timeout: 5))
    taskInput.tap()
    taskInput.typeText("Test Task")

    // Start timer
    let startButton = app.buttons["startPomodoroButton"]
    XCTAssertTrue(startButton.exists)
    startButton.click()

    // Verify timer started (check pause/play button exists)
    let pauseButton = app.buttons.matching(identifier: "pause.circle.fill").firstMatch
    let playButton = app.buttons.matching(identifier: "play.circle.fill").firstMatch
    XCTAssertTrue(
        pauseButton.exists || playButton.exists,
        "Timer should show pause or play button after start"
    )

    // Pause timer
    if pauseButton.exists {
        pauseButton.click()
        // Verify play button appears
        XCTAssertTrue(playButton.waitForExistence(timeout: 2))
    }

    // Resume timer
    if playButton.exists {
        playButton.click()
        // Verify pause button appears
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 2))
    }

    // Finish timer
    let finishButton = app.buttons["finishPomodoroButton"] ?? app.buttons["finishButton"]
    if finishButton.exists {
        finishButton.click()
        // Verify timer reset
        let timerDisplay = app.staticTexts.matching(identifier: "timerDisplay").firstMatch
        // Timer should be 0:00 or empty
        // Note: Actual verification depends on UI implementation
    }
}
```

### 2. DND Auto-Activation Flow
Test must verify:
- Timer starts → DND should be activated
- Timer finishes → DND should be deactivated
- Check DND status programmatically (via AppleScript or Cocoa API)

**Implementation:**
```swift
func testDNDActivationDeactivation() throws {
    // Launch and start timer
    let app = XCUIApplication()
    app.launch()
    // ... setup timer (same as above)

    // Activate timer
    // ... start timer code ...

    // Check DND status (via AppleScript)
    let script = "tell application \"System Events\" to get the value of the accessibility element of UI element 1 of pop up button 1 of group 1 of sheet 1 of window 1"
    let dndStatus = app.queues.firstMatch?.executeCommand(script) ?? ""

    // DND should be ON when timer is running
    // Note: Exact accessibility element names depend on UI implementation
}
```

**Alternative approach**: Use Cocoa API to check DND status via `NSWorkspace.sessionActivationPolicy`

### 3. Google Calendar Integration
Test must verify:
- Calendar events are fetched and displayed
- Conflicts are detected and shown
- No crashes with invalid/empty calendar

**Implementation:**
```swift
func testCalendarIntegration() throws {
    // This test requires mocking or real calendar data
    // Option 1: Use test calendar with known events
    // Option 2: Mock CalendarService to return test data

    let app = XCUIApplication()
    app.launch()

    // Open settings and check calendar integration
    let settingsButton = app.buttons["settingsButton"]
    XCTAssertTrue(settingsButton.exists)
    settingsButton.click()

    // Verify calendar-related UI elements exist
    // (depend on implementation)
}
```

### 4. Slack Status Integration
Test must verify:
- Status updates when timer starts/finishes
- Status clears when timer finishes
- No errors when Slack is not connected

**Implementation:**
```swift
func testSlackIntegration() throws {
    let app = XCUIApplication()
    app.launch()

    // Start timer
    // ... setup and start timer ...

    // Verify Slack integration (if connected)
    // Note: Requires Slack token/credentials in test environment
}
```

## Testing Strategy

### Unit Tests First
1. Create separate `FocallyTests/` for unit tests
2. Test individual services (TimerService, DNDService, CalendarService, SlackService)
3. Use mocking for dependencies

### UI Tests Second
1. Complete `FocallyUITests/FocallyUITests.swift`
2. Use `XCUIScreen.screenshot()` to capture screenshots on failure
3. Run tests with `xcodebuild test -scheme Focally -destination 'platform=macOS'`

### Continuous Integration
1. Configure GitHub Actions to run tests on PR
2. Require all tests to pass before merge
3. Set up test coverage reporting (target: 80%)

## Success Criteria

✅ All timer flows pass (start, pause, resume, finish)
✅ DND activation/deactivation verified
✅ Calendar integration tested (with mock or real data)
✅ Slack integration tested (with mock or real credentials)
✅ Test suite passes with 80%+ coverage
✅ Tests are idempotent and run in <5 minutes
✅ Screenshot capture on failure enabled

## Deliverables

1. **Updated `FocallyUITests/FocallyUITests.swift`** with complete test suite
2. **Unit tests** in `FocallyTests/` for all services
3. **Test configuration** in `project.yml` (if needed)
4. **CI/CD pipeline** configuration (if not exists)
5. **Test coverage report** showing coverage percentage

## Notes

- UI accessibility elements depend on SwiftUI implementation
- Use `accessibilityIdentifier` on views for reliable targeting
- Tests should be isolated (no shared state between tests)
- Use `try await` for async operations where appropriate
- Mock external services (Calendar, Slack) for reliability

## Related Tasks

- TASK-015: Tests de i18n (partial)
- TASK-026: App Store submission preparation
- TASK-027: v0.6.0 release preparation

## References

- Apple UI Testing documentation: https://developer.apple.com/documentation/xctest
- Swift concurrency guide: https://docs.swift.org/concurrency/

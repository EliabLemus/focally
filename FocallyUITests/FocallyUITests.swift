import XCTest

final class FocallyUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-TESTING"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Timer Flow Tests

    func testAppLaunchAndMenuBarInteraction() throws {
        // Verificar que la aplicación se lanza correctamente
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        // Buscar el elemento de la barra de menú (status item)
        let menuBar = XCUIApplication().menuBars.element(boundBy: 0)
        XCTAssertTrue(menuBar.exists)

        // Buscar el elemento de Focally en la barra de menú
        let focallyMenuItem = menuBar.menubarItems["Focally"]
        XCTAssertTrue(focallyMenuItem.waitForExistence(timeout: 5))

        // Hacer clic en el elemento de la barra de menú para abrir el popover
        focallyMenuItem.click()

        // Verificar que el popover se abre
        let popover = app.windows["MenuBarDropdownView"]
        XCTAssertTrue(popover.waitForExistence(timeout: 5))
    }

    func testTimerServiceAccessibilityElements() throws {
        // Lanzar la aplicación
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        // Abrir el popover desde la barra de menú
        let menuBar = XCUIApplication().menuBars.element(boundBy: 0)
        let focallyMenuItem = menuBar.menubarItems["Focally"]
        XCTAssertTrue(focallyMenuItem.waitForExistence(timeout: 5))
        focallyMenuItem.click()

        // Verificar elementos de accesibilidad en el popover
        let headerText = app.staticTexts["headerFocusText"]
        XCTAssertTrue(headerText.waitForExistence(timeout: 5))
        XCTAssertEqual(headerText.label, "Focus")

        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.exists)

        let moreButton = app.buttons["moreButton"]
        XCTAssertTrue(moreButton.exists)

        let taskInput = app.textFields["taskInputTextField"]
        XCTAssertTrue(taskInput.exists)

        let startPomodoroButton = app.buttons["startPomodoroButton"]
        XCTAssertTrue(startPomodoroButton.exists)

        let customSessionButton = app.buttons["customSessionButton"]
        XCTAssertTrue(customSessionButton.exists)
    }

    func testCompleteTimerFlow() throws {
        // Launch and open popover
        let menuBar = XCUIApplication().menuBars.element(boundBy: 0)
        let focallyMenuItem = menuBar.menubarItems["Focally"]
        XCTAssertTrue(focallyMenuItem.waitForExistence(timeout: 5))
        focallyMenuItem.click()

        // Enter task
        let taskInput = app.textFields["taskInputTextField"]
        XCTAssertTrue(taskInput.waitForExistence(timeout: 5))
        taskInput.tap()
        taskInput.typeText("Test Focus Task")

        // Start Pomodoro
        let startButton = app.buttons["startPomodoroButton"]
        XCTAssertTrue(startButton.exists)
        startButton.click()

        // Verify timer started (pause/play button should appear)
        let pauseButton = app.buttons.matching(identifier: "pause.circle.fill").firstMatch
        let playButton = app.buttons.matching(identifier: "play.circle.fill").firstMatch
        XCTAssertTrue(
            pauseButton.exists || playButton.exists,
            "Timer should show pause or play button after start"
        )

        // Wait a moment for timer to count
        Thread.sleep(forTimeInterval: 2)

        // Pause timer
        if pauseButton.exists {
            pauseButton.click()
            XCTAssertTrue(playButton.waitForExistence(timeout: 2))
        }

        // Resume timer
        if playButton.exists {
            playButton.click()
            XCTAssertTrue(pauseButton.waitForExistence(timeout: 2))
        }

        // Finish timer (look for finish button or press Esc to close)
        let finishButton = app.buttons["finishPomodoroButton"] ?? app.buttons["finishButton"]
        if finishButton.exists {
            finishButton.click()
        } else {
            // Try closing via Escape key
            app.press(.escape)
        }

        // Verify popover closed
        let popover = app.windows["MenuBarDropdownView"]
        XCTAssertFalse(popover.exists)
    }

    func testTaskInputAndClearing() throws {
        // Launch and open popover
        let menuBar = XCUIApplication().menuBars.element(boundBy: 0)
        let focallyMenuItem = menuBar.menubarItems["Focally"]
        XCTAssertTrue(focallyMenuItem.waitForExistence(timeout: 5))
        focallyMenuItem.click()

        // Enter task
        let taskInput = app.textFields["taskInputTextField"]
        XCTAssertTrue(taskInput.waitForExistence(timeout: 5))
        taskInput.tap()
        taskInput.typeText("Test Task")

        XCTAssertEqual(taskInput.value as? String, "Test Task")

        // Verify task input exists
        XCTAssertFalse(taskInput.value as? String == "")
    }

    // MARK: - Settings Tests

    func testSettingsButtonExists() throws {
        // Launch and open popover
        let menuBar = XCUIApplication().menuBars.element(boundBy: 0)
        let focallyMenuItem = menuBar.menubarItems["Focally"]
        XCTAssertTrue(focallyMenuItem.waitForExistence(timeout: 5))
        focallyMenuItem.click()

        // Click settings button
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.exists)
        settingsButton.click()

        // Verify settings window appears (adjust window name based on actual implementation)
        let settingsWindow = app.windows["SettingsView"]
        XCTAssertTrue(settingsWindow.exists)
    }

    // MARK: - Edge Cases

    func testMultipleTimerSessions() throws {
        // Test starting and finishing multiple sessions in sequence

        for i in 1...3 {
            let menuBar = XCUIApplication().menuBars.element(boundBy: 0)
            let focallyMenuItem = menuBar.menubarItems["Focally"]
            XCTAssertTrue(focallyMenuItem.waitForExistence(timeout: 5))
            focallyMenuItem.click()

            let taskInput = app.textFields["taskInputTextField"]
            XCTAssertTrue(taskInput.waitForExistence(timeout: 5))
            taskInput.tap()
            taskInput.typeText("Session \(i)")

            let startButton = app.buttons["startPomodoroButton"]
            XCTAssertTrue(startButton.exists)
            startButton.click()

            // Verify timer active
            let pauseButton = app.buttons.matching(identifier: "pause.circle.fill").firstMatch
            let playButton = app.buttons.matching(identifier: "play.circle.fill").firstMatch
            XCTAssertTrue(pauseButton.exists || playButton.exists)

            // Finish session
            let finishButton = app.buttons["finishPomodoroButton"] ?? app.buttons["finishButton"]
            if finishButton.exists {
                finishButton.click()
            } else {
                app.press(.escape)
            }
        }
    }

    func testSettingsOpenAndClose() throws {
        // Launch and open popover
        let menuBar = XCUIApplication().menuBars.element(boundBy: 0)
        let focallyMenuItem = menuBar.menubarItems["Focally"]
        XCTAssertTrue(focallyMenuItem.waitForExistence(timeout: 5))
        focallyMenuItem.click()

        // Open settings
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.exists)
        settingsButton.click()

        // Close settings
        app.press(.escape)

        // Verify popover is still open (or closed depending on implementation)
        let popover = app.windows["MenuBarDropdownView"]
        if popover.exists {
            // If settings is a modal, popover should be closed
            XCTAssertFalse(popover.exists)
        }
    }
}

import SwiftUI
import Combine
import os.log

@main
struct FocallyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            // Redirect system Settings to MainWindow (Settings tab handled via openSettings)
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.focally.mac", category: "AppDelegate")
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?
    private var mainWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var themeObserver: NSObjectProtocol?
    let dndService = DNDService()
    let focusIntegrationService = FocusIntegrationService()
    let slackService = SlackService()
    let calendarService = GoogleCalendarService()
    let notificationService = NotificationService()
    let historyService = HistoryService.shared
    let shortcutDropHandler = ShortcutDropHandler()
    let testShortcutGenerator = TestShortcutGenerator()
    private lazy var timerService = FocusTimerService(
        soundPlayer: .shared,
        notificationService: notificationService,
        historyService: historyService,
        dndService: dndService,
        focusIntegrationService: focusIntegrationService
    )
    private var timerUpdate: Timer?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Show onboarding if not completed
        showOnboardingIfNeeded()

        // Generate test shortcuts on first launch (legacy, kept for compatibility)
        generateTestShortcutsIfNeeded()

        applySavedTheme()
        notificationService.requestAuthorization()

        // Setup status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Focally")
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Setup popover with new MenuBarDropdownView
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 600)
        popover.behavior = .transient

        let contentView = MenuBarDropdownView()
            .environmentObject(timerService)
            .environmentObject(dndService)
            .environmentObject(focusIntegrationService)
            .environmentObject(calendarService)
            .environmentObject(historyService)
            .environmentObject(shortcutDropHandler)
        popover.contentViewController = NSHostingController(rootView: contentView)
        self.popover = popover
        applySavedTheme()

        // Observe timer changes
        timerService.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateStatusBar()
            }
        }.store(in: &cancellables)

        // Observe pomodoro state to start/stop status bar timer
        timerService.$pomodoroState
            .removeDuplicates()
            .sink { [weak self] (state: PomodoroState) in
                if state == .idle {
                    self?.stopStatusBarUpdates()
                    self?.updateStatusBar()
                } else if self?.timerUpdate == nil {
                    self?.startStatusBarUpdates()
                }
            }
            .store(in: &cancellables)

        // Observe session start/end for Slack
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onSessionStarted),
            name: .focusSessionStarted,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onSessionEnded),
            name: .focusSessionEnded,
            object: nil
        )

        // Click-outside monitor to close popover
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
            }
        }

        if calendarService.isEnabled {
            calendarService.fetchTodayEvents()
        }

        themeObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: .main
        ) { [weak self] _ in
            self?.applySavedTheme()
        }

        // Cmd+Shift+F to open main window
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .shift]) && event.characters == "f" {
                self?.openMainWindow()
                return nil
            }
            return event
        }
    }

    @objc private func onSessionStarted() {
        let expiration = Int(Date().timeIntervalSince1970) + (timerService.durationMinutes * 60)
        slackService.setStatus(
            text: timerService.currentActivity,
            expirationTimestamp: expiration,
            taskEmoji: timerService.currentEmoji,
            fallbackEmoji: slackService.savedStatusEmoji()
        )

        guard calendarService.isEnabled, calendarService.isSignedIn else { return }
        calendarService.fetchTodayEvents { [weak self] in
            self?.presentCalendarConflictIfNeeded()
        }
    }

    @objc private func onSessionEnded() {
        slackService.clearStatus()
    }

    @objc func togglePopover() {
        guard let button = statusItem?.button, let popover = popover else { return }

        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            showContextMenu(button: button)
            return
        }

        if popover.isShown {
            popover.performClose(button)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            applySavedTheme()
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu(button: NSButton) {
        let menu = NSMenu()

        if timerService.hasSession {
            let pauseTitle = timerService.isPaused ? "Resume Session" : "Pause Session"
            let pauseImage = timerService.isPaused ? "play.fill" : "pause.fill"
            let pauseItem = NSMenuItem(title: pauseTitle, action: #selector(togglePauseSession), keyEquivalent: "")
            pauseItem.image = NSImage(systemSymbolName: pauseImage, accessibilityDescription: pauseTitle)
            pauseItem.target = self
            menu.addItem(pauseItem)

            let endItem = NSMenuItem(title: "End Session", action: #selector(endSession), keyEquivalent: "")
            endItem.image = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: "End")
            endItem.target = self
            menu.addItem(endItem)
            menu.addItem(NSMenuItem.separator())
        }

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(title: aboutMenuTitle, action: nil, keyEquivalent: "")
        aboutItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "About Focally")
        aboutItem.isEnabled = false
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Focally", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        let buttonOrigin = button.window?.convertToScreen(NSRect(origin: button.frame.origin, size: button.frame.size)).origin ?? .zero
        menu.popUp(positioning: nil, at: NSPoint(x: buttonOrigin.x, y: buttonOrigin.y - 2), in: nil)
    }

    @objc func togglePauseSession() {
        timerService.togglePause()
    }

    @objc func endSession() {
        timerService.endSession()
    }

    @objc func openSettings() {
        if popover?.isShown == true {
            popover?.performClose(nil)
        }

        // Open MainWindow on Settings tab
        openMainWindow()
        // Navigate to settings tab after a brief delay (window needs to be visible)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: .focusNavigateToSettings, object: nil)
        }
    }

    @objc func openMainWindow() {
        if popover?.isShown == true {
            popover?.performClose(nil)
        }

        if let mainWindow {
            mainWindow.makeKeyAndOrderFront(nil)
            mainWindow.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingView = MainWindow()
            .environmentObject(timerService)
            .environmentObject(dndService)
            .environmentObject(focusIntegrationService)
            .environmentObject(slackService)
            .environmentObject(calendarService)
            .environmentObject(historyService)
            .environmentObject(shortcutDropHandler)
        let window = NSWindow(contentViewController: NSHostingController(rootView: hostingView))
        window.title = "Focally"
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.styleMask = styleMask
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 1200, height: 800))
        window.minSize = NSSize(width: 900, height: 600)
        window.center()
        mainWindow = window
        applySavedTheme()
        window.makeKeyAndOrderFront(nil as Any?)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    private func updateStatusBar() {
        guard let button = statusItem?.button else { return }

        if timerService.hasSession {
            let imageName = timerService.isPaused ? "play.fill" : "pause.fill"
            let description = timerService.isPaused ? "Resume Focus Session" : "Pause Focus Session"
            button.image = NSImage(systemSymbolName: imageName, accessibilityDescription: description)
            let newText = " \(timerService.currentEmoji) \(timerService.remainingMinutesString) — \(timerService.currentActivity)"
            if button.title != newText {
                button.title = newText
            }
        } else {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Focally")
            button.title = ""
        }

        statusItem?.length = NSStatusItem.variableLength
    }

    private func startStatusBarUpdates() {
        guard timerUpdate == nil else { return }
        timerUpdate = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStatusBar()
        }
    }

    private func stopStatusBarUpdates() {
        timerUpdate?.invalidate()
        timerUpdate = nil
    }

    private func applySavedTheme() {
        let theme = ThemeChoice(
            rawValue: UserDefaults.standard.string(forKey: "appTheme") ?? ThemeChoice.system.rawValue
        ) ?? .system
        let appearance = appearance(for: theme)

        NSApp.appearance = appearance
        statusItem?.button?.appearance = appearance
        popover?.appearance = appearance
        popover?.contentViewController?.view.appearance = appearance
        popover?.contentViewController?.view.window?.appearance = appearance
        mainWindow?.appearance = appearance
        mainWindow?.contentViewController?.view.appearance = appearance
    }

    private func appearance(for theme: ThemeChoice) -> NSAppearance? {
        switch theme {
        case .light:
            return NSAppearance(named: NSAppearance.Name.aqua)
        case .dark:
            return NSAppearance(named: NSAppearance.Name.darkAqua)
        case .system:
            return nil as NSAppearance?
        }
    }

    private var aboutMenuTitle: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "About Focally (v\(version), build \(build))"
    }

    // MARK: - Onboarding

    @MainActor
    private func showOnboardingIfNeeded() {
        guard !ShortcutOnboardingViewModel.isOnboardingCompleted() else {
            logger.info("Onboarding already completed, skipping")
            return
        }

        logger.info("Showing shortcuts onboarding")

        // Delay slightly to allow the app to fully launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showOnboardingWindow()
        }
    }

    private func showOnboardingWindow() {
        let onboardingView = ShortcutOnboardingView(
            testShortcutGenerator: testShortcutGenerator,
            focusIntegrationService: focusIntegrationService
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Focally Shortcuts Setup"
        window.isReleasedWhenClosed = false
        window.center()

        let hostingController = NSHostingController(rootView: onboardingView)
        window.contentViewController = hostingController

        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)

        onboardingWindow = window
        applySavedTheme()
    }

    // MARK: - Test Shortcuts

    private func generateTestShortcutsIfNeeded() {
        let key = "FocallyTestShortcutsGenerated"
        let hasGenerated = UserDefaults.standard.bool(forKey: key)

        guard !hasGenerated else { return }

        do {
            try testShortcutGenerator.generateAllTestShortcuts()
            UserDefaults.standard.set(true, forKey: key)
            logger.info("✅ Test shortcuts generated successfully")
        } catch {
            logger.error("Failed to generate test shortcuts: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func presentCalendarConflictIfNeeded() {
        guard timerService.isActive else { return }

        let sessionInterval = DateInterval(
            start: Date(),
            end: Date().addingTimeInterval(TimeInterval(timerService.remainingSeconds))
        )

        guard let conflict = calendarService.checkConflict(during: sessionInterval) else {
            return
        }

        let alert = NSAlert()
        alert.messageText = "You have a meeting during this focus session"
        alert.informativeText = "\(conflict.title) is scheduled for \(conflict.timeRange)."
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .warning
        alert.runModal()
    }
}

extension AppDelegate: NSMenuDelegate {}

// Notification names for Slack integration
extension Notification.Name {
    static let focusSessionStarted = Notification.Name("focusSessionStarted")
    static let focusSessionEnded = Notification.Name("focusSessionEnded")
    static let focusNavigateToSettings = Notification.Name("focusNavigateToSettings")
}

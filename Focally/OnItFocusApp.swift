import Observation
import SwiftUI
import os.log

@main
struct FocallyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger.app
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?
    private var mainWindow: NSWindow?
    private var setupWindow: NSWindow?
    private var themeObserver: NSObjectProtocol?
    let dndService = DNDService.shared
    let focusIntegrationService = FocusIntegrationService.shared
    let slackService = SlackService()
    let notificationService = NotificationService()
    let focusModeStore = FocusModeStore()
    let usageTracker = EmojiUsageTracker.shared
    let emojiCacheService = EmojiCacheService.shared
    private lazy var settingsStore = SettingsStore()
    private lazy var timerService = FocusTimerService(
        settingsStore: settingsStore,
        soundPlayer: .shared,
        notificationService: notificationService,
        dndService: dndService,
        focusIntegrationService: focusIntegrationService
    )
    private var timerUpdate: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        SoundPlayerService.shared.syncFromSettingsStore(settingsStore)
        showSetupIfNeeded()
        applySavedTheme()
        notificationService.requestAuthorization()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Focally")
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 520)
        popover.behavior = .transient
        let contentView = MenuBarDropdownView()
            .environment(settingsStore)
            .environment(SoundPlayerService.shared)
            .environment(timerService)
            .environment(dndService)
            .environment(focusIntegrationService)
            .environment(slackService)
            .environment(focusModeStore)
            .environment(usageTracker)
        popover.contentViewController = NSHostingController(rootView: contentView)
        self.popover = popover
        observeTimerService()
        observeSlackEmojiCatalog()
        warmEmojiCacheIfNeeded()

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
            }
        }

        themeObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.settingsStore.loadFromDefaults()
                if let settingsStore = self?.settingsStore {
                    SoundPlayerService.shared.syncFromSettingsStore(settingsStore)
                }
                self?.applySavedTheme()
            }
        }

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .shift]) && event.characters == "f" {
                self?.openMainWindow()
                return nil
            }
            return event
        }
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

        let setupItem = NSMenuItem(title: "Setup…", action: #selector(openSetupWindow), keyEquivalent: "")
        setupItem.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Setup")
        setupItem.target = self
        menu.addItem(setupItem)

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
        openMainWindow()
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
            .environment(settingsStore)
            .environment(SoundPlayerService.shared)
            .environment(timerService)
            .environment(dndService)
            .environment(focusIntegrationService)
            .environment(slackService)
            .environment(focusModeStore)
            .environment(usageTracker)
        let window = NSWindow(contentViewController: NSHostingController(rootView: hostingView))
        window.title = "Focally"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
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

    @objc func openSetupWindow() {
        if popover?.isShown == true {
            popover?.performClose(nil)
        }
        showSetupWindow()
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
            let currentEmoji = timerService.currentEmoji
            if EmojiValidator.isCustomWorkspaceEmoji(currentEmoji, workspaceEmojiCodes: slackService.workspaceEmojiCodes) {
                logger.warning("Custom Slack emoji cannot render in the menu bar title; falling back to shortcode text")
            }
            let emojiDisplay = EmojiValidator.convertShortcodeToUnicode(
                currentEmoji,
                workspaceEmojis: slackService.workspaceEmojiCodes
            ) ?? currentEmoji
            let newText = " \(emojiDisplay) \(timerService.remainingMinutesString) — \(timerService.currentActivity)"
            if button.title != newText {
                button.title = newText
            }
        } else {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Focally")
            button.title = ""
        }

        statusItem?.length = NSStatusItem.variableLength
    }

    private func observeTimerService() {
        withObservationTracking {
            _ = timerService.pomodoroState
            _ = timerService.hasSession
            _ = timerService.isPaused
            _ = timerService.currentEmoji
            _ = timerService.currentActivity
            _ = timerService.remainingMinutesString
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handleTimerServiceChange()
                self.observeTimerService()
            }
        }

        handleTimerServiceChange()
    }

    private func handleTimerServiceChange() {
        updateStatusBar()

        if timerService.pomodoroState == .idle {
            stopStatusBarUpdates()
            updateStatusBar()
        } else if timerUpdate == nil {
            startStatusBarUpdates()
        }
    }

    private func observeSlackEmojiCatalog() {
        withObservationTracking {
            _ = slackService.workspaceEmojiImageURLs
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.warmEmojiCacheIfNeeded()
                self.observeSlackEmojiCatalog()
            }
        }
    }

    private func warmEmojiCacheIfNeeded() {
        let emojiURLs = slackService.workspaceEmojiImageURLs
        guard !emojiURLs.isEmpty else { return }

        Task(priority: .utility) {
            await self.emojiCacheService.warmCache(with: emojiURLs)
        }
    }

    private func startStatusBarUpdates() {
        guard timerUpdate == nil else { return }
        timerUpdate = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateStatusBar()
            }
        }
    }

    private func stopStatusBarUpdates() {
        timerUpdate?.invalidate()
        timerUpdate = nil
    }

    private func applySavedTheme() {
        let appearance = appearance(for: settingsStore.appTheme)
        NSApp.appearance = appearance
        statusItem?.button?.appearance = appearance
        popover?.appearance = appearance
        popover?.contentViewController?.view.appearance = appearance
        popover?.contentViewController?.view.window?.appearance = appearance
        mainWindow?.appearance = appearance
        mainWindow?.contentViewController?.view.appearance = appearance
        setupWindow?.appearance = appearance
    }

    private func appearance(for theme: ThemeChoice) -> NSAppearance? {
        switch theme {
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        case .system:
            return nil
        }
    }

    private var aboutMenuTitle: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "About Focally (v\(version), build \(build))"
    }

    private func showSetupIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: "FocallySimpleSetupCompleted") else {
            logger.info("Simple setup already completed")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showSetupWindow()
        }
    }

    private func showSetupWindow() {
        if let setupWindow {
            setupWindow.makeKeyAndOrderFront(nil)
            setupWindow.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Focally Setup"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentViewController = NSHostingController(rootView: FocusSetupView())
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        setupWindow = window
        applySavedTheme()
    }
}

extension AppDelegate: NSMenuDelegate {}

extension Notification.Name {
    static let focusNavigateToSettings = Notification.Name("focusNavigateToSettings")
}

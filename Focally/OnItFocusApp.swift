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
    let shortcutsService = ManagedFocusShortcutsService.shared
    let slackService = SlackService()
    private lazy var calendarService = CalendarSlackIntegrationService(
        slackService: slackService,
        dndService: dndService
    )
    let notificationService = NotificationService()
    let focusModeStore = FocusModeStore()
    let usageTracker = EmojiUsageTracker.shared
    let emojiCacheService = EmojiCacheService.shared
    let updateChecker = UpdateCheckerService.shared
    let permissionService = PermissionService.shared
    private lazy var settingsStore = SettingsStore()
    let appLanguage = AppLanguage.shared
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

        // Auto-reconnect Slack if token exists and not already attempted (post-update)
        slackService.attemptAutoReconnectionIfNeeded()

        // Check permissions post-update (detect if lost)
        permissionService.checkAllPermissions()
        if permissionService.detectPermissionLoss() {
            logger.info("Permissions lost post-update detected. Showing permission alert.")
            showPermissionLossAlert()
        } else {
            permissionService.markPermissionsVerified()
        }

        showSetupIfNeeded()
        applySavedTheme()
        notificationService.requestAuthorization()

        setupStatusBar()

        NotificationCenter.default.addObserver(
            self, selector: #selector(screenDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 520)
        popover.behavior = .transient
        let contentView = MenuBarDropdownView(onAddMode: { [weak self] in
            self?.openAddMode()
        })
            .environment(settingsStore)
            .environment(SoundPlayerService.shared)
            .environment(timerService)
            .environment(dndService)
            .environment(focusIntegrationService)
            .environment(shortcutsService)
            .environment(slackService)
            .environment(calendarService)
            .environment(focusModeStore)
            .environment(usageTracker)
            .environment(updateChecker)
            .environment(appLanguage)
            .environment(\.locale, appLanguage.locale)
        popover.contentViewController = NSHostingController(rootView: contentView)
        self.popover = popover
        observeTimerService()
        observeSlackEmojiCatalog()
        warmEmojiCacheIfNeeded()
        calendarService.startIfEnabled()

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
            // Multi-monitor fix: Detect screen del button y forzar posicionamiento correcto
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            applySavedTheme()
            
            // Forzar key window en el screen correcto
            if let popoverWindow = popover.contentViewController?.view.window {
                popoverWindow.makeKey()
                popoverWindow.orderFrontRegardless()
            }
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

    @objc func openAddMode() {
        if popover?.isShown == true {
            popover?.performClose(nil)
        }
        openMainWindow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: .focusAddMode, object: nil)
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
            .environment(shortcutsService)
            .environment(slackService)
            .environment(calendarService)
            .environment(focusModeStore)
            .environment(usageTracker)
            .environment(updateChecker)
            .environment(appLanguage)
            .environment(\.locale, appLanguage.locale)
        let window = NSWindow(contentViewController: NSHostingController(rootView: hostingView))
        window.title = "Focally Settings"
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

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Focally")
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateStatusBar()
    }

    @objc private func screenDidChange(_ notification: Notification) {
        if statusItem == nil || statusItem?.button == nil {
            logger.info("Status item lost after screen change, recreating")
            setupStatusBar()
        }
    }

    private func updateStatusBar() {
        guard let button = statusItem?.button else { return }

        if timerService.hasSession {
            let currentEmoji = timerService.currentEmoji
            let emojiString = EmojiValidator.convertShortcodeToUnicode(
                currentEmoji,
                workspaceEmojis: slackService.workspaceEmojiCodes
            ) ?? currentEmoji

            // Try to load custom emoji from cache as NSImage
            var emojiImage: NSImage? = nil
            if EmojiValidator.isCustomWorkspaceEmoji(currentEmoji, workspaceEmojiCodes: slackService.workspaceEmojiCodes),
               let urlString = slackService.workspaceEmojiImageURLs[currentEmoji],
               let url = URL(string: urlString) {
                // Synchronous load from cache (already downloaded by EmojiCacheService)
                if let cached = emojiCacheService.cachedEmojiURL(for: currentEmoji),
                   let nsImg = NSImage(contentsOf: cached) {
                    emojiImage = nsImg
                }
            }

            // Build composite image: emoji + time text
            let timeText = timerService.remainingMinutesString
            let composite = Self.renderMenuBarImage(
                emoji: emojiString,
                emojiImage: emojiImage,
                timeText: timeText,
                isPaused: timerService.isPaused
            )
            button.image = composite
            button.title = "  \(timerService.currentActivity)"
        } else {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Focally")
            button.title = ""
        }

        statusItem?.length = NSStatusItem.variableLength
    }

    /// Renders a composite NSImage for the menu bar: emoji + time text.
    private static func renderMenuBarImage(emoji: String, emojiImage: NSImage?, timeText: String, isPaused: Bool) -> NSImage {
        let emojiSize: CGFloat = 11
        let fontSize: CGFloat = 12
        let padding: CGFloat = 2
        let gap: CGFloat = 4

        // Measure text
        let textFont = NSFont.systemFont(ofSize: fontSize)
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: textFont,
            .foregroundColor: NSColor.labelColor
        ]
        let textString = NSAttributedString(string: " \(timeText)", attributes: textAttrs)
        let textSize = textString.size()

        // Emoji dimension — fix to menu bar height
        let emojiFont = NSFont.systemFont(ofSize: emojiSize)
        let emojiAttrs: [NSAttributedString.Key: Any] = [.font: emojiFont]
        let emojiAttrStr = NSAttributedString(string: emoji, attributes: emojiAttrs)
        let emojiMeasureSize = emojiAttrStr.size()
        let emojiDim = emojiSize  // Fixed size, don't let it grow

        // Pause/play icon
        let iconDim: CGFloat = 10
        let iconFont = NSFont.systemFont(ofSize: iconDim)
        let iconStr = isPaused ? "▶" : "⏸"
        let iconAttrs: [NSAttributedString.Key: Any] = [.font: iconFont, .foregroundColor: NSColor.secondaryLabelColor]
        let iconAttrStr = NSAttributedString(string: iconStr, attributes: iconAttrs)
        let iconSize = iconAttrStr.size()

        let totalWidth = padding + emojiDim + gap + iconSize.width + gap + textSize.width + padding
        let totalHeight: CGFloat = max(22, emojiDim + 4)

        let img = NSImage(size: NSSize(width: totalWidth, height: totalHeight))
        img.lockFocus()

        // Draw emoji
        let emojiPoint = NSPoint(x: padding, y: (totalHeight - emojiMeasureSize.height) / 2)
        if let emojiImage {
            let resized = emojiImage.resized(to: NSSize(width: emojiDim, height: emojiDim))
            resized.draw(in: NSRect(origin: emojiPoint, size: NSSize(width: emojiDim, height: emojiDim)))
        } else {
            emojiAttrStr.draw(at: emojiPoint)
        }

        // Draw pause/play icon
        let iconY = (totalHeight - iconSize.height) / 2
        iconAttrStr.draw(at: NSPoint(x: padding + emojiDim + gap, y: iconY))

        // Draw time text
        let textY = (totalHeight - textSize.height) / 2
        textString.draw(at: NSPoint(x: padding + emojiDim + gap + iconSize.width + gap, y: textY))

        img.unlockFocus()
        return img
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
        window.contentViewController = NSHostingController(rootView: FocusSetupView()
            .environment(appLanguage)
            .environment(\.locale, appLanguage.locale))
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        setupWindow = window
        applySavedTheme()
    }

    private func showPermissionLossAlert() {
        let alert = NSAlert()
        alert.messageText = AppLanguage.shared.localizedString("permission_loss_title")
        alert.informativeText = AppLanguage.shared.localizedString("permission_loss_message")
        alert.alertStyle = .warning
        alert.addButton(withTitle: AppLanguage.shared.localizedString("permission_loss_open_settings"))
        alert.addButton(withTitle: AppLanguage.shared.localizedString("permission_loss_dismiss"))

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openMainWindow()
            // Esperar un momento y luego abrir settings
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: .focusNavigateToSettings, object: nil)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.info("Application terminating - forcing cleanup of active sessions and focus integration")

        // Reset any active timer session to ensure DND is deactivated
        if timerService.isActive {
            logger.info("Terminating active timer session")
            timerService.resetToIdle()
        }

        // Explicitly deactivate focus integration (macOS DND + Slack)
        focusIntegrationService.deactivateFocus()
    }
}

extension AppDelegate: NSMenuDelegate {}

extension Notification.Name {
    static let focusNavigateToSettings = Notification.Name("focusNavigateToSettings")
    static let focusAddMode = Notification.Name("focusAddMode")
}

private extension NSImage {
    func resized(to size: NSSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        self.draw(in: NSRect(origin: .zero, size: size),
                  from: NSRect(origin: .zero, size: self.size),
                  operation: .copy,
                  fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
}

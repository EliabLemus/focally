import AppKit
import ApplicationServices
import Foundation
import Observation

@MainActor
protocol NotificationCenterSystemControlling: AnyObject {
    var isTrusted: Bool { get }
    var isVisible: Bool { get }
    func open() async -> Bool
    func close() async -> Bool
}

@MainActor
protocol NotificationCenterPresenting: AnyObject {
    var isAvailable: Bool { get }
    var ownsVisiblePanel: Bool { get }
    func openForBreak() async -> Bool
    func closeIfOwned() async
}

@MainActor
@Observable
final class NotificationCenterPresenter: NotificationCenterPresenting {
    static let shared = NotificationCenterPresenter(system: MacNotificationCenterSystem())

    private let system: NotificationCenterSystemControlling
    private(set) var ownsVisiblePanel = false
    private(set) var lastError: String?

    var isAvailable: Bool { system.isTrusted }

    init(system: NotificationCenterSystemControlling) {
        self.system = system
    }

    func openForBreak() async -> Bool {
        guard system.isTrusted else {
            ownsVisiblePanel = false
            lastError = "Accessibility permission is required to open Notification Center."
            return false
        }

        if system.isVisible {
            // The user already had the panel open; Focally must not claim it.
            ownsVisiblePanel = false
            lastError = nil
            return true
        }

        let opened = await system.open()
        ownsVisiblePanel = opened && system.isVisible
        lastError = ownsVisiblePanel ? nil : "Notification Center could not be opened."
        return ownsVisiblePanel
    }

    func closeIfOwned() async {
        guard ownsVisiblePanel else { return }
        guard system.isVisible else {
            // The user changed the panel state, so our lease is no longer valid.
            ownsVisiblePanel = false
            return
        }

        let closed = await system.close()
        if closed || !system.isVisible {
            ownsVisiblePanel = false
            lastError = nil
        } else {
            lastError = "Notification Center could not be closed."
        }
    }
}

@MainActor
final class MacNotificationCenterSystem: NotificationCenterSystemControlling {
    var isTrusted: Bool { AXIsProcessTrusted() }
    var isVisible: Bool { Self.notificationCenterIsVisible() }

    func open() async -> Bool {
        guard isTrusted else { return false }
        return await toggleAndWait(forVisibleState: true)
    }

    func close() async -> Bool {
        guard isTrusted else { return false }
        return await toggleAndWait(forVisibleState: false)
    }

    private func toggleAndWait(forVisibleState target: Bool) async -> Bool {
        if isVisible == target { return true }

        Self.postNotificationCenterShortcut()
        for _ in 0..<12 {
            try? await Task.sleep(nanoseconds: 50_000_000)
            if isVisible == target { return true }
        }
        return isVisible == target
    }

    nonisolated private static func postNotificationCenterShortcut() {
        // Apple documents Fn-N as the system shortcut for Notification Center.
        let source = CGEventSource(stateID: .hidSystemState)
        let keyCode: CGKeyCode = 45 // N on the ANSI keyboard layout
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        down?.flags = .maskSecondaryFn
        up?.flags = .maskSecondaryFn
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    nonisolated private static func notificationCenterIsVisible() -> Bool {
        guard let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return false
        }

        return windows.contains { window in
            let owner = (window[kCGWindowOwnerName as String] as? String ?? "").lowercased()
            let name = (window[kCGWindowName as String] as? String ?? "").lowercased()
            let combined = "\(owner) \(name)"
            return combined.contains("notification center") || combined.contains("notificationcenter")
        }
    }
}

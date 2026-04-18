import AppKit
import ApplicationServices
import Foundation

class DNDService: ObservableObject {
    @Published var isDNDActive = false
    private var hasShownSetupAlert = false

    func activateDND() {
        guard !isDNDActive else { return }
        guard ensureAccessibilityPermission(prompt: true) else {
            presentAccessibilityAlert()
            return
        }

        if toggleDNDShortcut() {
            isDNDActive = true
            print("[Focally] DND activated")
        } else {
            presentFocusShortcutAlert()
        }
    }

    func deactivateDND() {
        guard isDNDActive else { return }
        guard ensureAccessibilityPermission(prompt: false) else { return }

        if toggleDNDShortcut() {
            isDNDActive = false
            print("[Focally] DND deactivated")
        } else {
            print("[Focally] Failed to deactivate DND")
        }
    }

    private func toggleDNDShortcut() -> Bool {
        let primaryShortcut = """
        tell application "System Events"
            key code 101 using {control down, option down, command down}
        end tell
        """

        if executeAppleScript(primaryShortcut) {
            return true
        }

        let fallbackShortcut = """
        tell application "System Events"
            key code 107 using {control down, option down, command down}
        end tell
        """

        if executeAppleScript(fallbackShortcut) {
            print("[Focally] DND toggled using fallback shortcut")
            return true
        }

        return false
    }

    private func ensureAccessibilityPermission(prompt: Bool) -> Bool {
        if AXIsProcessTrusted() {
            return true
        }

        if prompt {
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
            _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        }

        print("[Focally] Accessibility permission required: System Settings > Privacy & Security > Accessibility > Add Focally")
        return false
    }

    @discardableResult
    private func executeAppleScript(_ script: String) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus == 0 { return true }
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            print("[Focally] AppleScript error: \(output)")
        } catch {
            print("[Focally] AppleScript error: \(error.localizedDescription)")
        }
        return false
    }

    private func presentAccessibilityAlert() {
        guard !hasShownSetupAlert else { return }
        hasShownSetupAlert = true

        DispatchQueue.main.async { [weak self] in
            let alert = NSAlert()
            alert.messageText = "Accessibility permission is required"
            alert.informativeText = "Focally needs Accessibility access to trigger your Focus shortcut. Enable it in System Settings > Privacy & Security > Accessibility."
            alert.addButton(withTitle: "Open Accessibility Settings")
            alert.addButton(withTitle: "OK")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self?.openAccessibilitySettings()
            }

            self?.hasShownSetupAlert = false
        }
    }

    private func presentFocusShortcutAlert() {
        guard !hasShownSetupAlert else { return }
        hasShownSetupAlert = true

        DispatchQueue.main.async { [weak self] in
            let alert = NSAlert()
            alert.messageText = "Focally could not toggle Do Not Disturb"
            alert.informativeText = "macOS usually requires a Focus keyboard shortcut for this automation. Set one in System Settings > Keyboard > Keyboard Shortcuts > Focus, then try again."
            alert.addButton(withTitle: "Open Keyboard Settings")
            alert.addButton(withTitle: "Open Accessibility Settings")
            alert.addButton(withTitle: "OK")

            let response = alert.runModal()
            switch response {
            case .alertFirstButtonReturn:
                self?.openKeyboardSettings()
            case .alertSecondButtonReturn:
                self?.openAccessibilitySettings()
            default:
                break
            }

            self?.hasShownSetupAlert = false
        }
    }

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func openKeyboardSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

import Foundation
import UserNotifications
import ApplicationServices

class DNDService: ObservableObject {
    @Published var isDNDActive = false

    func activateDND() {
        guard !isDNDActive else { return }
        guard ensureAccessibilityPermission() else { return }

        // Toggle Focus/DND using Control Center shortcut
        let script = """
        tell application "System Events"
            key code 101 using {control down, option down, command down}
        end tell
        """
        if executeAppleScript(script) {
            isDNDActive = true
            print("[Focally] DND activated")
        } else {
            // Fallback: try another known shortcut variant
            let fallback = """
            tell application "System Events"
                key code 107 using {control down, option down, command down}
            end tell
            """
            if executeAppleScript(fallback) {
                isDNDActive = true
                print("[Focally] DND activated (fallback)")
            } else {
                print("[Focally] Failed to activate DND - you may need to set a Focus shortcut in System Settings > Keyboard > Keyboard Shortcuts > Focus")
            }
        }
    }

    func deactivateDND() {
        guard isDNDActive else { return }
        guard ensureAccessibilityPermission() else { return }

        let script = """
        tell application "System Events"
            key code 101 using {control down, option down, command down}
        end tell
        """
        if executeAppleScript(script) {
            isDNDActive = false
            print("[Focally] DND deactivated")
        } else {
            let fallback = """
            tell application "System Events"
                key code 107 using {control down, option down, command down}
            end tell
            """
            if executeAppleScript(fallback) {
                isDNDActive = false
                print("[Focally] DND deactivated (fallback)")
            } else {
                print("[Focally] Failed to deactivate DND")
            }
        }
    }

    private func ensureAccessibilityPermission() -> Bool {
        guard AXIsProcessTrusted() else {
            print("[Focally] ⚠️ Accessibility permission required: System Settings > Privacy & Security > Accessibility > Add Focally")
            return false
        }
        return true
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
}

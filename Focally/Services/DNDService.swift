import Foundation
import UserNotifications

class DNDService: ObservableObject {
    @Published var isDNDActive = false

    func activateDND() {
        // Use AppleScript to toggle Do Not Disturb via Focus mode
        let script = """
        tell application "System Events"
            tell its appearance preferences
                set dark mode to dark mode
            end tell
        end tell
        """

        // Alternative: Use Focus Filters API (macOS 14+)
        // FocusFilterSet requires the app to be a focus filter extension
        // Fallback: Use osascript to activate DND
        let dndScript = """
        do shell script "defaults read com.apple.controlcenter 'NSStatusItem Visible FocusModes'"
        """

        // Use the modern approach with FocusFilterSet
        activateFocusMode()
        isDNDActive = true
        print("[Focally] DND activated")
    }

    func deactivateDND() {
        deactivateFocusMode()
        isDNDActive = false
        print("[Focally] DND deactivated")
    }

    private func activateFocusMode() {
        // Toggle DND via System Events
        let appleScript = """
        tell application "System Events"
            key code 101 using {option down, control down, command down}
        end tell
        """
        executeAppleScript(appleScript)
    }

    private func deactivateFocusMode() {
        let appleScript = """
        tell application "System Events"
            key code 101 using {option down, control down, command down}
        end tell
        """
        executeAppleScript(appleScript)
    }

    private func executeAppleScript(_ script: String) {
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            print("[Focally] AppleScript error: \(error.localizedDescription)")
            // Fallback: try with accessibility API
            print("[Focally] Make sure Focally has Accessibility permissions in System Settings")
        }
    }
}

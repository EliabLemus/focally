import Cocoa
import Observation
import os.log

@Observable
final class DNDService {
    static let shared = DNDService()

    private static let notificationCenterAppId = "com.apple.notificationcenterui" as CFString

    private let logger = Logger.dnd

    /// TASK-060: on macOS 14+ the signed "Set Focus by Name" shortcut is the
    /// primary activation layer; the CFPreferences write below is a legacy-tier
    /// fallback (macOS ≤ 13) whose result never counts as verification.
    nonisolated static let prefersShortcutsFirst =
        DNDReliabilityService.isOperatingSystemAtLeastShortcutsFirst()

    /// TASK-057 Layer 2/3: when set, every activation/deactivation write is
    /// followed by a verify → escalate-at-most-once pass.
    var reliabilityService: DNDReliabilityService?

    var isDNDActive: Bool = false
    var lastError: String?
    init() {
        isDNDActive = Self.prefersShortcutsFirst ? false : Self.checkDNDStatus()
    }

    func activateDND() {
        guard !isDNDActive else { return }
        // TASK-060: macOS 14+ — shortcut-first. The CFPreferences write path is
        // NOT executed and its result never counts as success or verification.
        if Self.prefersShortcutsFirst, reliabilityService != nil {
            logger.info("Activating Focus via signed shortcut (macOS 14+)")
            lastError = nil
            isDNDActive = true
            notifyReliabilityActivation()
            return
        } else if Self.prefersShortcutsFirst {
            // Not expected: shortcut tier without a wired reliability service.
            // Keep the legacy write as a last resort but never surface it as
            // shortcut-verified success.
            logger.warning("macOS 14+ without reliability service — falling back to legacy CFPreferences write")
        } else {
            logger.info("Activating Do Not Disturb via CFPreferences")
        }
        lastError = nil

        // Attempt to set preferences
        Self.setPreference("doNotDisturb", value: true as CFPropertyList)
        Self.setPreference("doNotDisturbDate", value: Date() as CFPropertyList)

        // Commit and check if successful
        let commitSuccess = Self.commitChanges()
        if !commitSuccess {
            let errorMsg = "Failed to commit DND preferences"
            logger.error(errorMsg)
            lastError = errorMsg
            return
        }

        let restartSuccess = Self.restartNotificationCenter()
        if !restartSuccess {
            let errorMsg = "Failed to restart Notification Center"
            logger.error(errorMsg)
            lastError = errorMsg
            return
        }
        notifyReliabilityActivation()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            let actuallyActive = Self.checkDNDStatus()
            if !actuallyActive {
                let errorMsg = "DND activation failed - status still inactive"
                self.logger.error(errorMsg)
                self.lastError = errorMsg
                self.isDNDActive = false
            } else {
                self.logger.info("DND activation successful")
                self.lastError = nil
                self.isDNDActive = true
            }
        }
    }

    func deactivateDND() {
        guard isDNDActive else { return }
        // TASK-060: macOS 14+ — shortcut-first (same tiering as activation).
        if Self.prefersShortcutsFirst, reliabilityService != nil {
            logger.info("Deactivating Focus via signed shortcut (macOS 14+)")
            lastError = nil
            isDNDActive = false
            notifyReliabilityDeactivation()
            return
        }
        if !Self.prefersShortcutsFirst {
            logger.info("Deactivating Do Not Disturb via CFPreferences")
        }
        lastError = nil

        Self.setPreference("doNotDisturb", value: false as CFPropertyList)
        Self.setPreference("doNotDisturbDate", value: nil)

        let commitSuccess = Self.commitChanges()
        if !commitSuccess {
            let errorMsg = "Failed to commit DND deactivation"
            logger.error(errorMsg)
            lastError = errorMsg
            return
        }

        Self.restoreMenubarIcon()
        let restartSuccess = Self.restartNotificationCenter()
        if !restartSuccess {
            let errorMsg = "Failed to restart Notification Center after deactivation"
            logger.error(errorMsg)
            lastError = errorMsg
            return
        }
        notifyReliabilityDeactivation()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            let actuallyInactive = !Self.checkDNDStatus()
            if !actuallyInactive {
                let errorMsg = "DND deactivation failed - status still active"
                self.logger.error(errorMsg)
                self.lastError = errorMsg
                self.isDNDActive = true
            } else {
                self.logger.info("DND deactivation successful")
                self.lastError = nil
                self.isDNDActive = false
            }
        }
    }

    @discardableResult
    func refreshDNDStatus() -> Bool {
        // TASK-060: the legacy CFPreferences key is ignored on macOS 14+ —
        // state there is owned by the shortcut-first flow.
        guard !Self.prefersShortcutsFirst else { return isDNDActive }
        let active = Self.checkDNDStatus()
        isDNDActive = active
        return active
    }

    // MARK: - DND reliability (TASK-057)

    private func notifyReliabilityActivation() {
        guard let reliabilityService else { return }
        if Thread.isMainThread {
            MainActor.assumeIsolated { reliabilityService.activationRequested() }
        }
    }

    private func notifyReliabilityDeactivation() {
        guard let reliabilityService else { return }
        if Thread.isMainThread {
            MainActor.assumeIsolated { reliabilityService.deactivationRequested() }
        }
    }

    private static func setPreference(_ key: String, value: CFPropertyList?) {
        CFPreferencesSetValue(
            key as CFString,
            value,
            notificationCenterAppId,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        )
    }

    private static func commitChanges() -> Bool {
        let syncSuccess = CFPreferencesSynchronize(
            notificationCenterAppId,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        )

        if !syncSuccess {
            Logger.dnd.error("CFPreferencesSynchronize failed")
        }

        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("com.apple.notificationcenterui.dndprefs_changed"),
            object: nil,
            deliverImmediately: true
        )

        return syncSuccess
    }

    private static func restartNotificationCenter() -> Bool {
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("com.apple.notificationcenterui.dndprefs_changed"),
            object: nil,
            deliverImmediately: true
        )
        return true
    }

    private static func restoreMenubarIcon() {
        setPreference("dndStart", value: 0 as CFPropertyList)
        setPreference("dndEnd", value: 1440 as CFPropertyList)
        setPreference("dndStart", value: nil)
        setPreference("dndEnd", value: nil)
        _ = commitChanges()
    }

    private static func checkDNDStatus() -> Bool {
        CFPreferencesGetAppBooleanValue(
            "doNotDisturb" as CFString,
            notificationCenterAppId,
            nil
        )
    }
}

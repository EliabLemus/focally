import Cocoa
import Observation
import os.log

@Observable
final class DNDService {
    static let shared = DNDService()

    private static let notificationCenterAppId = "com.apple.notificationcenterui" as CFString

    private let logger = Logger.dnd

    var isDNDActive: Bool = false
    var lastError: String?
    init() {
        isDNDActive = Self.checkDNDStatus()
    }

    func activateDND() {
        guard !isDNDActive else { return }
        logger.info("Activating Do Not Disturb via CFPreferences")
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
        logger.info("Deactivating Do Not Disturb via CFPreferences")
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
        let active = Self.checkDNDStatus()
        isDNDActive = active
        return active
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

import Cocoa
import os.log

final class DNDService: ObservableObject {
    static let shared = DNDService()

    private static let notificationCenterAppId = "com.apple.notificationcenterui" as CFString

    private let logger = Logger.dnd

    @Published var isDNDActive: Bool = false
    init() {
        isDNDActive = Self.checkDNDStatus()
    }

    func activateDND() {
        guard !isDNDActive else { return }
        logger.info("Activating Do Not Disturb via CFPreferences")

        Self.setPreference("doNotDisturb", value: true as CFPropertyList)
        Self.setPreference("doNotDisturbDate", value: Date() as CFPropertyList)
        Self.commitChanges()
        Self.restartNotificationCenter()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            self.isDNDActive = Self.checkDNDStatus()
            self.logger.info("DND activation result: \(self.isDNDActive)")
        }

        isDNDActive = true
    }

    func deactivateDND() {
        guard isDNDActive else { return }
        logger.info("Deactivating Do Not Disturb via CFPreferences")

        Self.setPreference("doNotDisturb", value: false as CFPropertyList)
        Self.setPreference("doNotDisturbDate", value: nil)
        Self.commitChanges()
        Self.restoreMenubarIcon()
        Self.restartNotificationCenter()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            self.isDNDActive = Self.checkDNDStatus()
            self.logger.info("DND deactivation result: \(self.isDNDActive)")
        }

        isDNDActive = false
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

    private static func commitChanges() {
        CFPreferencesSynchronize(
            notificationCenterAppId,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        )

        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("com.apple.notificationcenterui.dndprefs_changed"),
            object: nil,
            deliverImmediately: true
        )
    }

    private static func restartNotificationCenter() {
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("com.apple.notificationcenterui.dndprefs_changed"),
            object: nil,
            deliverImmediately: true
        )
        Thread.sleep(forTimeInterval: 0.2)
    }

    private static func restoreMenubarIcon() {
        setPreference("dndStart", value: 0 as CFPropertyList)
        setPreference("dndEnd", value: 1440 as CFPropertyList)
        Thread.sleep(forTimeInterval: 0.4)
        setPreference("dndStart", value: nil)
        setPreference("dndEnd", value: nil)
        commitChanges()
    }

    private static func checkDNDStatus() -> Bool {
        CFPreferencesGetAppBooleanValue(
            "doNotDisturb" as CFString,
            notificationCenterAppId,
            nil
        )
    }
}

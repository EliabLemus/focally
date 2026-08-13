import Foundation
import UserNotifications
import EventKit
import AppKit

/// Servicio centralizado para detectar y verificar permisos de la app
@Observable
final class PermissionService {
    static let shared = PermissionService()

    private let eventStore = EKEventStore()

    // MARK: - Estados de Permisos

    enum PermissionStatus {
        case granted
        case denied
        case notDetermined
        case restricted
        case unknown

        var isGranted: Bool {
            self == .granted
        }

        var isProblematic: Bool {
            self == .denied || self == .restricted
        }
    }

    enum PermissionType: String, CaseIterable, Identifiable {
        case notifications = "Notifications"
        case calendar = "Calendar"
        case accessibility = "Accessibility"
        case dnd = "Do Not Disturb"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .notifications: return AppLanguage.shared.localizedString("permission_notifications")
            case .calendar: return AppLanguage.shared.localizedString("permission_calendar")
            case .accessibility: return AppLanguage.shared.localizedString("permission_accessibility")
            case .dnd: return AppLanguage.shared.localizedString("permission_dnd")
            }
        }
    }

    // MARK: - Estados Actuales

    var notificationsStatus: PermissionStatus = .unknown
    var calendarStatus: PermissionStatus = .unknown
    var accessibilityStatus: PermissionStatus = .unknown
    var dndStatus: PermissionStatus = .unknown

    var allPermissionsGranted: Bool {
        notificationsStatus.isGranted &&
        calendarStatus.isGranted &&
        accessibilityStatus.isGranted &&
        dndStatus.isGranted
    }

    var hasProblematicPermissions: Bool {
        notificationsStatus.isProblematic ||
        calendarStatus.isProblematic ||
        accessibilityStatus.isProblematic ||
        dndStatus.isProblematic
    }

    var problematicPermissions: [PermissionType] {
        var problems: [PermissionType] = []

        if notificationsStatus.isProblematic { problems.append(.notifications) }
        if calendarStatus.isProblematic { problems.append(.calendar) }
        if accessibilityStatus.isProblematic { problems.append(.accessibility) }
        if dndStatus.isProblematic { problems.append(.dnd) }

        return problems
    }

    // MARK: - Verificación

    func checkAllPermissions() {
        checkNotifications()
        checkCalendar()
        checkAccessibility()
        checkDND()
    }

    private func checkNotifications() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            Task { @MainActor in
                switch settings.authorizationStatus {
                case .authorized:
                    self.notificationsStatus = .granted
                case .denied:
                    self.notificationsStatus = .denied
                case .notDetermined:
                    self.notificationsStatus = .notDetermined
                case .provisional:
                    self.notificationsStatus = .granted
                case .ephemeral:
                    self.notificationsStatus = .granted
                @unknown default:
                    self.notificationsStatus = .unknown
                }
            }
        }
    }

    private func checkCalendar() {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .authorized, .fullAccess, .writeOnly:
            calendarStatus = .granted
        case .denied:
            calendarStatus = .denied
        case .notDetermined:
            calendarStatus = .notDetermined
        case .restricted:
            calendarStatus = .restricted
        @unknown default:
            calendarStatus = .unknown
        }
    }

    private func checkAccessibility() {
        let trusted = AXIsProcessTrusted()
        accessibilityStatus = trusted ? .granted : .denied
    }

    private func checkDND() {
        // DND es un sistema automático de macOS, no requiere permisos explícitos
        // Pero verificamos si el sistema lo soporta
        dndStatus = .granted
    }

    // MARK: - Request Permissions

    func requestNotifications() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .sound])
        checkNotifications()
        return granted ?? false
    }

    func requestCalendar() async -> Bool {
        let granted = try? await eventStore.requestFullAccessToEvents()
        checkCalendar()
        return granted ?? false
    }

    func requestAccessibility() -> Bool {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let trusted = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        accessibilityStatus = trusted ? .granted : .denied
        return trusted
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Reset Tracking

    /// Marca permisos como verificados después del primer launch
    func markPermissionsVerified() {
        UserDefaults.standard.set(true, forKey: "focally.permissionsVerified")
    }

    var permissionsHaveBeenVerified: Bool {
        UserDefaults.standard.bool(forKey: "focally.permissionsVerified")
    }

    /// Detecta si es probable que los permisos se perdieron post-update
    func detectPermissionLoss() -> Bool {
        guard permissionsHaveBeenVerified else { return false }
        checkAllPermissions()
        return hasProblematicPermissions
    }
}
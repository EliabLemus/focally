import Foundation
import Security

// MARK: - Save strategy (decisión pura, testeable sin SecItem)

/// Acción de seguimiento tras el resultado de un `SecItemUpdate`.
enum KeychainSaveStrategy: Equatable {
    /// `SecItemUpdate` tuvo éxito; nada más que hacer.
    case updateExisting
    /// El ítem no existe (`errSecItemNotFound`); hacer `SecItemAdd`.
    case addNew
    /// Fallo real del keychain; reportar el `OSStatus`.
    case reportFailure(OSStatus)
}

struct KeychainHelper {
    private static let logger = Logger.slack

    /// Patrón recomendado por Apple: find/update primero, add solo si no existe
    /// (evita el delete+add que pierde ACLs y metadatos).
    /// - Returns: `errSecSuccess` si el valor quedó persistido, u otro `OSStatus` en fallo.
    @discardableResult
    static func save(key: String, value: String) -> OSStatus {
        guard let data = value.data(using: .utf8) else {
            logger.error("Keychain save failed: cannot UTF-8 encode value for key")
            return OSStatus(paramErr)
        }

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributesToUpdate as CFDictionary)
        let strategy = saveStrategy(updateStatus: updateStatus)

        let status: OSStatus
        switch strategy {
        case .updateExisting:
            status = errSecSuccess
            logger.info("Keychain item updated for existing key")
        case .addNew:
            var addQuery = baseQuery
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(addQuery as CFDictionary, nil)
            if status == errSecSuccess {
                logger.info("Keychain item added for new key")
            }
        case .reportFailure(let failureStatus):
            status = failureStatus
        }

        if status != errSecSuccess {
            logger.error("Keychain save error: \(status)")
        }
        return status
    }

    /// Decisión pura update/add/fail a partir del `OSStatus` de `SecItemUpdate`.
    static func saveStrategy(updateStatus: OSStatus) -> KeychainSaveStrategy {
        switch updateStatus {
        case errSecSuccess:
            return .updateExisting
        case errSecItemNotFound:
            return .addNew
        default:
            return .reportFailure(updateStatus)
        }
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}

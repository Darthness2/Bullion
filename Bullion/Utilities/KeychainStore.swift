import Foundation
import Security

/// Thin Keychain wrapper for storing the backend session token.
/// SnapTrade `userSecret` never reaches the app — only our backend's
/// session token is stored here.
enum KeychainStore {
    private static let service = "com.bullion.app"

    /// Stores `value` for `key`, returning whether the write succeeded.
    /// The result is discardable for call sites that don't care, but failures
    /// are surfaced (and logged) rather than swallowed silently.
    @discardableResult
    static func set(_ value: String, for key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        // Delete any existing item first. errSecItemNotFound is fine; anything
        // else (other than success) is a real failure we shouldn't ignore.
        let deleteStatus = SecItemDelete(baseQuery as CFDictionary)
        guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
            print("KeychainStore: delete failed for \(key) (OSStatus \(deleteStatus))")
            return false
        }
        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        // Restrict to this device, available after first unlock — not synced to
        // iCloud Keychain, sensible for a session token.
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            print("KeychainStore: add failed for \(key) (OSStatus \(addStatus))")
            return false
        }
        return true
    }

    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func remove(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
import Foundation
import os.log

/// Stores Plaid credentials on-device. The `accessToken` (returned by the
/// backend's token-exchange endpoint) is stored in the iOS Keychain. The
/// `backendURL` (where the thin serverless function lives) is in UserDefaults
/// so the user can configure it. Plaid `client_id` and `secret` stay on the
/// server — they never touch the device.
enum PlaidKeyStore {
    private static let logger = Logger(subsystem: "com.bullion.app", category: "plaid")
    private static let accessTokenKeychain = "plaid.accessToken"
    private static let itemIdKeychain = "plaid.itemId"
    private static let backendURLDefaults = "plaid.backendURL"
    private static let institutionNameDefaults = "plaid.institutionName"

    /// The Plaid access token — returned by the server's exchange endpoint
    /// after the user completes Plaid Link. Used for all data calls
    /// (holdings, transactions, balances) directly from the device to Plaid.
    static var accessToken: String? {
        get { KeychainStore.get(accessTokenKeychain) }
        set {
            if let v = newValue, !v.isEmpty { KeychainStore.set(v, for: accessTokenKeychain) }
            else { KeychainStore.remove(accessTokenKeychain) }
        }
    }

    /// The Plaid item ID (identifies the linked institution).
    static var itemId: String? {
        get { KeychainStore.get(itemIdKeychain) }
        set {
            if let v = newValue, !v.isEmpty { KeychainStore.set(v, for: itemIdKeychain) }
            else { KeychainStore.remove(itemIdKeychain) }
        }
    }

    /// The URL of the thin backend server that handles the token exchange.
    /// Set by the user in Settings. Defaults to localhost for development.
    static var backendURL: String {
        get { UserDefaults.standard.string(forKey: backendURLDefaults) ?? "http://127.0.0.1:8787" }
        set { UserDefaults.standard.set(newValue, forKey: backendURLDefaults) }
    }

    /// The name of the linked institution (e.g. "Fidelity", "Schwab") for
    /// display in the connect screen.
    static var institutionName: String? {
        get { UserDefaults.standard.string(forKey: institutionNameDefaults) }
        set { UserDefaults.standard.set(newValue, forKey: institutionNameDefaults) }
    }

    /// Whether an access token is stored (user has linked a brokerage).
    static var isLinked: Bool {
        !(accessToken?.isEmpty ?? true)
    }

    /// Remove the linked Plaid item (access token + item ID). Keeps the
    /// backend URL so the user doesn't have to re-enter it.
    static func clearLink() {
        accessToken = nil
        itemId = nil
        institutionName = nil
    }
}
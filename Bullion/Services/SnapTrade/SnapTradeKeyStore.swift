import Foundation

/// Stores SnapTrade credentials for the backend-less (direct) integration.
///
/// Secrets (`consumerKey`, `userSecret`) live in the iOS Keychain via
/// `KeychainStore`. The non-secret `clientId` and the generated `userId` live
/// in UserDefaults. This mirrors `AIKeyStore` — the app talks to SnapTrade
/// directly, so the partner `consumerKey` is on-device (acceptable for a
/// personal, single-user build; not for multi-user distribution).
enum SnapTradeKeyStore {
    private static let consumerKeyKeychain = "snaptrade.consumerKey"
    private static let userSecretKeychain = "snaptrade.userSecret"
    private static let clientIdDefaults = "snaptrade.clientId"
    private static let userIdDefaults = "snaptrade.userId"

    /// Partner client id (not secret) — from the SnapTrade dashboard.
    static var clientId: String? {
        get { UserDefaults.standard.string(forKey: clientIdDefaults) }
        set { UserDefaults.standard.set(newValue, forKey: clientIdDefaults) }
    }

    /// Partner consumer key (secret) — used to HMAC-sign every request.
    static var consumerKey: String? {
        get { KeychainStore.get(consumerKeyKeychain) }
        set {
            if let v = newValue, !v.isEmpty { KeychainStore.set(v, for: consumerKeyKeychain) }
            else { KeychainStore.remove(consumerKeyKeychain) }
        }
    }

    /// SnapTrade user id (generated once on first registration).
    static var userId: String? {
        get { UserDefaults.standard.string(forKey: userIdDefaults) }
        set { UserDefaults.standard.set(newValue, forKey: userIdDefaults) }
    }

    /// SnapTrade user secret (secret) — returned by registerUser.
    static var userSecret: String? {
        get { KeychainStore.get(userSecretKeychain) }
        set {
            if let v = newValue, !v.isEmpty { KeychainStore.set(v, for: userSecretKeychain) }
            else { KeychainStore.remove(userSecretKeychain) }
        }
    }

    /// Whether partner credentials are present (we can sign requests).
    static var hasPartnerCredentials: Bool {
        !(clientId?.isEmpty ?? true) && !(consumerKey?.isEmpty ?? true)
    }

    /// Whether a SnapTrade user has been registered (we hold a user secret).
    static var isRegistered: Bool {
        !(userId?.isEmpty ?? true) && !(userSecret?.isEmpty ?? true)
    }

    /// Remove the registered user (keeps partner credentials).
    static func clearRegistration() {
        userSecret = nil
        UserDefaults.standard.removeObject(forKey: userIdDefaults)
    }

    /// Remove everything (partner credentials + registration).
    static func clearAll() {
        consumerKey = nil
        clearRegistration()
        UserDefaults.standard.removeObject(forKey: clientIdDefaults)
    }
}

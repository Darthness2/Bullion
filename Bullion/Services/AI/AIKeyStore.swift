import Foundation

/// Stores AI API keys in the iOS Keychain. Never in UserDefaults, never in plaintext.
/// Ollama needs no key (runs locally).
enum AIKeyStore {
    private static let anthropicKey = "ai.anthropic.key"
    private static let openaiKey = "ai.openai.key"

    static var anthropicAPIKey: String? {
        get { KeychainStore.get(anthropicKey) }
        set {
            if let newValue { KeychainStore.set(newValue, for: anthropicKey) }
            else { KeychainStore.remove(anthropicKey) }
        }
    }

    static var openAIAPIKey: String? {
        get { KeychainStore.get(openaiKey) }
        set {
            if let newValue { KeychainStore.set(newValue, for: openaiKey) }
            else { KeychainStore.remove(openaiKey) }
        }
    }

    static func clearAll() {
        KeychainStore.remove(anthropicKey)
        KeychainStore.remove(openaiKey)
    }
}
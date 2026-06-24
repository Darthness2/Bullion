import Foundation

/// User-configurable AI settings. Non-secret prefs go in UserDefaults;
/// API keys go in Keychain via AIKeyStore.
@Observable
final class AISettingsStore {
    enum StorageKeys {
        static let provider = "ai.provider"
        static let model = "ai.model"
        static let ollamaEndpoint = "ai.ollama.endpoint"
    }

    var providerType: AIProviderType {
        get {
            if let raw = UserDefaults.standard.string(forKey: StorageKeys.provider),
               let p = AIProviderType(rawValue: raw) {
                return p
            }
            return .ollama  // default: local, no key needed
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: StorageKeys.provider) }
    }

    var selectedModel: String {
        get { UserDefaults.standard.string(forKey: StorageKeys.model) ?? providerType.defaultModels.first ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: StorageKeys.model) }
    }

    var ollamaEndpoint: String {
        get { UserDefaults.standard.string(forKey: StorageKeys.ollamaEndpoint) ?? "http://localhost:11434" }
        set { UserDefaults.standard.set(newValue, forKey: StorageKeys.ollamaEndpoint) }
    }

    var anthropicAPIKey: String {
        get { AIKeyStore.anthropicAPIKey ?? "" }
        set { AIKeyStore.anthropicAPIKey = newValue.isEmpty ? nil : newValue }
    }

    var openAIAPIKey: String {
        get { AIKeyStore.openAIAPIKey ?? "" }
        set { AIKeyStore.openAIAPIKey = newValue.isEmpty ? nil : newValue }
    }

    /// Whether the current provider is configured and ready to use.
    var isConfigured: Bool {
        switch providerType {
        case .anthropic: return !anthropicAPIKey.isEmpty
        case .openai:    return !openAIAPIKey.isEmpty
        case .ollama:    return !ollamaEndpoint.isEmpty
        }
    }

    func makeProvider() -> any AIProvider {
        switch providerType {
        case .anthropic: return AnthropicProvider()
        case .openai:    return OpenAIProvider()
        case .ollama:    return OllamaProvider(baseURL: URL(string: ollamaEndpoint) ?? URL(string: "http://localhost:11434")!)
        }
    }

    func currentAPIKey() -> String? {
        switch providerType {
        case .anthropic: return anthropicAPIKey.isEmpty ? nil : anthropicAPIKey
        case .openai:    return openAIAPIKey.isEmpty ? nil : openAIAPIKey
        case .ollama:    return nil
        }
    }

    func clearKeys() {
        AIKeyStore.clearAll()
        anthropicAPIKey = ""
        openAIAPIKey = ""
    }
}
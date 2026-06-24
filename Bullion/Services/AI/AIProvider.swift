import Foundation

/// Provider-agnostic LLM interface for the research agent.
/// Supports Anthropic (Claude), OpenAI (GPT), and Ollama (local models).
/// All use plain URLSession + async/await — no third-party SDKs.
protocol AIProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    var requiresAPIKey: Bool { get }
    var models: [String] { get }
    func analyze(context: MarketContext, model: String, apiKey: String?) async throws -> AIAnalysis
}

enum AIProviderType: String, CaseIterable, Identifiable, Sendable {
    case anthropic, openai, ollama
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic (Claude)"
        case .openai:    return "OpenAI (GPT)"
        case .ollama:    return "Ollama (Local)"
        }
    }
    var defaultModels: [String] {
        switch self {
        case .anthropic: return ["claude-sonnet-4-5-20250929", "claude-opus-4-1-20250805", "claude-haiku-4-5-20251001"]
        case .openai:    return ["gpt-4o", "gpt-4o-mini", "o3-mini"]
        case .ollama:    return ["llama3.1", "llama3", "qwen2.5", "mistral", "phi3"]
        }
    }
    func requiresAPIKey(_ endpoint: String?) -> Bool {
        switch self {
        case .anthropic, .openai: return true
        case .ollama:             return false
        }
    }
}
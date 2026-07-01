import Foundation

/// Role in a multi-turn conversation.
enum ChatRole: String, Sendable {
    case user
    case assistant
}

/// Provider-agnostic LLM interface for the research agent.
/// Supports Anthropic (Claude), OpenAI (GPT), and Ollama (local models).
/// All use plain URLSession + async/await — no third-party SDKs.
protocol AIProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    var requiresAPIKey: Bool { get }
    var models: [String] { get }
    func analyze(context: MarketContext, model: String, apiKey: String?) async throws -> AIAnalysis
    /// Multi-turn follow-up chat with conversation history. `history` is the
    /// prior turns (user/assistant alternating) as raw message dicts ready for
    /// the provider's API. Returns the assistant's plain-text reply.
    func chatStream(
        systemPrompt: String,
        userPrompt: String,
        history: [[String: Any]],
        model: String,
        apiKey: String?
    ) async throws -> String
    /// Token-by-token streaming of the analysis. Yields text deltas as they
    /// arrive from the LLM. The final accumulated text is NOT parsed — the
    /// caller parses it after the stream completes. Cancellation via the
    /// calling Task propagates to the underlying bytes task.
    func analyzeStream(context: MarketContext, model: String, apiKey: String?) async throws -> AsyncThrowingStream<String, Error>
}

extension AIProvider {
    /// Default non-streaming implementation for providers that haven't
    /// adopted the history-aware chat yet.
    func chatStream(
        systemPrompt: String,
        userPrompt: String,
        history: [[String: Any]],
        model: String,
        apiKey: String?
    ) async throws -> String {
        throw AIError.invalidResponse("This provider does not support follow-up chat.")
    }

    /// Default streaming falls back to the non-streaming analyze and yields
    /// the full text in one chunk. Providers override with real SSE parsing.
    func analyzeStream(context: MarketContext, model: String, apiKey: String?) async throws -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let analysis = try await self.analyze(context: context, model: model, apiKey: apiKey)
                    let text = try JSONEncoder().encode(analysis)
                    continuation.yield(String(data: text, encoding: .utf8) ?? "")
                } catch {
                    continuation.finish(throwing: error)
                    return
                }
                continuation.finish()
            }
        }
    }
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
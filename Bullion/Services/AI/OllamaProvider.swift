import Foundation

/// Ollama provider — runs locally, no API key required.
/// Docs: https://github.com/ollama/ollama/blob/main/docs/api.md
struct OllamaProvider: AIProvider {
    let id = "ollama"
    let displayName = "Ollama (Local)"
    let requiresAPIKey = false
    let models = AIProviderType.ollama.defaultModels

    // Default local endpoint; user can override in Settings.
    var baseURL: URL

    init(baseURL: URL = URL(string: "http://localhost:11434")!) {
        self.baseURL = baseURL
    }

    // MARK: - Shared send

    private func send(
        body: [String: Any], timeout: TimeInterval = 120
    ) async throws -> Data {
        let endpoint = baseURL.appendingPathComponent("api/chat")
        let data = try JSONSerialization.data(withJSONObject: body)
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = timeout
        req.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw AIError.invalidResponse("No HTTP response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            throw AIError.httpError(http.statusCode, body)
        }
        return responseData
    }

    struct OllamaResponse: Codable {
        struct Message: Codable { let role: String; let content: String }
        let message: Message
        let done: Bool?
    }

    func analyze(context: MarketContext, model: String, apiKey: String?) async throws -> AIAnalysis {
        let body: [String: Any] = [
            "model": model,
            "stream": false,
            "format": "json",
            "messages": [
                ["role": "system", "content": AIPromptBuilder.systemPrompt],
                ["role": "user", "content": AIPromptBuilder.userPrompt(for: context)]
            ]
        ]
        let data = try await send(body: body)
        let decoded = try JSONDecoder().decode(OllamaResponse.self, from: data)
        return try AIPromptBuilder.parseAnalysis(decoded.message.content)
    }

    func chatStream(
        systemPrompt: String,
        userPrompt: String,
        history: [[String: Any]],
        model: String,
        apiKey: String?
    ) async throws -> String {
        var messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt]
        ]
        messages.append(contentsOf: history)
        messages.append(["role": "user", "content": userPrompt])

        let body: [String: Any] = [
            "model": model,
            "stream": false,
            "messages": messages
        ]
        let data = try await send(body: body)
        let decoded = try JSONDecoder().decode(OllamaResponse.self, from: data)
        return decoded.message.content
    }
}
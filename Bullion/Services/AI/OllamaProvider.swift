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

    func analyze(context: MarketContext, model: String, apiKey: String?) async throws -> AIAnalysis {
        let endpoint = baseURL.appendingPathComponent("api/chat")
        let requestBody: [String: Any] = [
            "model": model,
            "stream": false,
            "format": "json",
            "messages": [
                ["role": "system", "content": AIPromptBuilder.systemPrompt],
                ["role": "user", "content": AIPromptBuilder.userPrompt(for: context)]
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: requestBody)
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw AIError.invalidResponse("No HTTP response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            throw AIError.httpError(http.statusCode, body)
        }

        struct OllamaResponse: Codable {
            struct Message: Codable { let role: String; let content: String }
            let message: Message
        }
        let decoded = try JSONDecoder().decode(OllamaResponse.self, from: responseData)
        return try AIPromptBuilder.parseAnalysis(decoded.message.content)
    }

    func chat(systemPrompt: String, userPrompt: String, model: String, apiKey: String?) async throws -> String {
        let endpoint = baseURL.appendingPathComponent("api/chat")
        let requestBody: [String: Any] = [
            "model": model,
            "stream": false,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: requestBody)
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 120   // local models can be slow
        req.httpBody = data
        let (responseData, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw AIError.invalidResponse("No HTTP response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw AIError.httpError(http.statusCode, String(data: responseData, encoding: .utf8) ?? "Unknown error")
        }
        struct OllamaResponse: Codable {
            struct Message: Codable { let role: String; let content: String }
            let message: Message
        }
        let decoded = try JSONDecoder().decode(OllamaResponse.self, from: responseData)
        return decoded.message.content
    }
}
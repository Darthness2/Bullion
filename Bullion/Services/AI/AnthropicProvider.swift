import Foundation

/// Anthropic Claude provider — uses the Messages API.
/// Docs: https://docs.anthropic.com/en/api/messages
struct AnthropicProvider: AIProvider {
    let id = "anthropic"
    let displayName = "Anthropic (Claude)"
    let requiresAPIKey = true
    let models = AIProviderType.anthropic.defaultModels

    private let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private let apiKeyHeader = "x-api-key"
    private let versionHeader = "anthropic-version"
    private let apiVersion = "2023-06-01"

    func analyze(context: MarketContext, model: String, apiKey: String?) async throws -> AIAnalysis {
        guard let apiKey, !apiKey.isEmpty else { throw AIError.noAPIKey }

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": AIPromptBuilder.systemPrompt,
            "messages": [
                ["role": "user", "content": AIPromptBuilder.userPrompt(for: context)]
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: requestBody)
        var req = URLRequest(url: baseURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: apiKeyHeader)
        req.setValue(apiVersion, forHTTPHeaderField: versionHeader)
        req.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw AIError.invalidResponse("No HTTP response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            throw AIError.httpError(http.statusCode, body)
        }

        // Parse Anthropic response: { content: [{ type: "text", text: "..." }] }
        struct AnthropicResponse: Codable {
            struct Content: Codable { let type: String; let text: String? }
            let content: [Content]
        }
        let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: responseData)
        guard let text = decoded.content.first(where: { $0.type == "text" })?.text else {
            throw AIError.invalidResponse("No text in Anthropic response.")
        }
        return try AIPromptBuilder.parseAnalysis(text)
    }
}
import Foundation

/// OpenAI GPT provider — uses the Chat Completions API.
/// Docs: https://platform.openai.com/docs/api-reference/chat
struct OpenAIProvider: AIProvider {
    let id = "openai"
    let displayName = "OpenAI (GPT)"
    let requiresAPIKey = true
    let models = AIProviderType.openai.defaultModels

    private let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    func analyze(context: MarketContext, model: String, apiKey: String?) async throws -> AIAnalysis {
        guard let apiKey, !apiKey.isEmpty else { throw AIError.noAPIKey }

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "temperature": 0.3,
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": AIPromptBuilder.systemPrompt],
                ["role": "user", "content": AIPromptBuilder.userPrompt(for: context)]
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: requestBody)
        var req = URLRequest(url: baseURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw AIError.invalidResponse("No HTTP response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            throw AIError.httpError(http.statusCode, body)
        }

        struct OpenAIResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable { let role: String; let content: String }
                let message: Message
            }
            let choices: [Choice]
        }
        let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: responseData)
        guard let text = decoded.choices.first?.message.content else {
            throw AIError.invalidResponse("No content in OpenAI response.")
        }
        return try AIPromptBuilder.parseAnalysis(text)
    }
}
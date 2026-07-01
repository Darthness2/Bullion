import Foundation

/// OpenAI GPT provider — uses the Chat Completions API.
/// Docs: https://platform.openai.com/docs/api-reference/chat
struct OpenAIProvider: AIProvider {
    let id = "openai"
    let displayName = "OpenAI (GPT)"
    let requiresAPIKey = true
    let models = AIProviderType.openai.defaultModels

    private let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    /// o-series reasoning models (o1, o3, o4) reject `temperature` and use
    /// `max_completion_tokens` instead of `max_tokens`. Sending the wrong
    /// parameter name causes an immediate HTTP 400 on every request.
    private func isReasoningModel(_ model: String) -> Bool {
        model.hasPrefix("o1") || model.hasPrefix("o3") || model.hasPrefix("o4")
    }

    /// Build the request body, adjusting parameters for the model family.
    private func requestBody(
        messages: [[String: Any]], model: String, forAnalysis: Bool
    ) -> [String: Any] {
        var body: [String: Any] = [
            "model": model,
            "messages": messages
        ]
        if isReasoningModel(model) {
            body["max_completion_tokens"] = forAnalysis ? 4096 : 2048
        } else {
            body["max_tokens"] = forAnalysis ? 4096 : 2048
            body["temperature"] = 0.3
        }
        if forAnalysis {
            body["response_format"] = ["type": "json_object"]
        }
        return body
    }

    // MARK: - Shared send + decode (eliminates duplication between analyze/chat)

    private func send(
        body: [String: Any], apiKey: String?, timeout: TimeInterval = 120
    ) async throws -> Data {
        guard let apiKey, !apiKey.isEmpty else { throw AIError.noAPIKey }
        let data = try JSONSerialization.data(withJSONObject: body)
        var req = URLRequest(url: baseURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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

    struct OpenAIResponse: Codable {
        struct Choice: Codable {
            struct Message: Codable { let role: String; let content: String }
            let message: Message
            let finishReason: String?
            enum CodingKeys: String, CodingKey {
                case message
                case finishReason = "finish_reason"
            }
        }
        let choices: [Choice]
    }

    func analyze(context: MarketContext, model: String, apiKey: String?) async throws -> AIAnalysis {
        let body = requestBody(
            messages: [
                ["role": "system", "content": AIPromptBuilder.systemPrompt],
                ["role": "user", "content": AIPromptBuilder.userPrompt(for: context)]
            ],
            model: model, forAnalysis: true
        )
        let data = try await send(body: body, apiKey: apiKey)
        let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let text = decoded.choices.first?.message.content else {
            throw AIError.invalidResponse("No content in OpenAI response.")
        }
        if let finish = decoded.choices.first?.finishReason, finish == "length" {
            throw AIError.invalidResponse("The model's response was truncated (max_tokens limit reached). Try again or simplify the request.")
        }
        return try AIPromptBuilder.parseAnalysis(text)
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

        let body = requestBody(messages: messages, model: model, forAnalysis: false)
        let data = try await send(body: body, apiKey: apiKey, timeout: 90)
        let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let text = decoded.choices.first?.message.content else {
            throw AIError.invalidResponse("No content in OpenAI response.")
        }
        return text
    }
}
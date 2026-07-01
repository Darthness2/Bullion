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

    // MARK: - Shared send + decode

    private func send(
        body: [String: Any], apiKey: String?, timeout: TimeInterval = 120
    ) async throws -> Data {
        guard let apiKey, !apiKey.isEmpty else { throw AIError.noAPIKey }
        let data = try JSONSerialization.data(withJSONObject: body)
        var req = URLRequest(url: baseURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: apiKeyHeader)
        req.setValue(apiVersion, forHTTPHeaderField: versionHeader)
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

    struct AnthropicResponse: Codable {
        struct Content: Codable { let type: String; let text: String? }
        let content: [Content]
        let stopReason: String?
        enum CodingKeys: String, CodingKey {
            case content
            case stopReason = "stop_reason"
        }
    }

    func analyze(context: MarketContext, model: String, apiKey: String?) async throws -> AIAnalysis {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": AIPromptBuilder.systemPrompt,
            "messages": [
                ["role": "user", "content": AIPromptBuilder.userPrompt(for: context)]
            ]
        ]
        let data = try await send(body: body, apiKey: apiKey)
        let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        guard let text = decoded.content.first(where: { $0.type == "text" })?.text else {
            throw AIError.invalidResponse("No text in Anthropic response.")
        }
        if let stop = decoded.stopReason, stop == "max_tokens" {
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
        var messages: [[String: Any]] = []
        messages.append(contentsOf: history)
        messages.append(["role": "user", "content": userPrompt])

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "system": systemPrompt,
            "messages": messages
        ]
        let data = try await send(body: body, apiKey: apiKey, timeout: 90)
        let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        guard let text = decoded.content.first(where: { $0.type == "text" })?.text else {
            throw AIError.invalidResponse("No text in Anthropic response.")
        }
        return text
    }

    // MARK: - Streaming

    func analyzeStream(context: MarketContext, model: String, apiKey: String?) async throws -> AsyncThrowingStream<String, Error> {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "stream": true,
            "system": AIPromptBuilder.systemPrompt,
            "messages": [
                ["role": "user", "content": AIPromptBuilder.userPrompt(for: context)]
            ]
        ]

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let data = try JSONSerialization.data(withJSONObject: body)
                    var req = URLRequest(url: baseURL)
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    if let apiKey, !apiKey.isEmpty {
                        req.setValue(apiKey, forHTTPHeaderField: apiKeyHeader)
                    }
                    req.setValue(apiVersion, forHTTPHeaderField: versionHeader)
                    req.timeoutInterval = 120
                    req.httpBody = data

                    let (bytes, response) = try await URLSession.shared.bytes(for: req)
                    guard let http = response as? HTTPURLResponse else {
                        continuation.finish(throwing: AIError.invalidResponse("No HTTP response."))
                        return
                    }
                    guard (200..<300).contains(http.statusCode) else {
                        continuation.finish(throwing: AIError.httpError(http.statusCode, "Anthropic stream error"))
                        return
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        // Anthropic SSE: "event: content_block_delta" then
                        // "data: {"type":"content_block_delta","delta":{"text":"..."}}"
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = line.dropFirst(6)
                        guard let chunkData = payload.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: chunkData) as? [String: Any],
                              let delta = json["delta"] as? [String: Any],
                              let text = delta["text"] as? String
                        else { continue }
                        continuation.yield(text)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
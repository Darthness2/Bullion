import Foundation

/// Shared prompt builder + JSON parsing for all AI providers.
enum AIPromptBuilder {

    static let systemPrompt = """
    You are a senior equity research analyst. You analyze stocks, ETFs, and futures \
    using technical indicators, recent news, and market movements to determine whether \
    a stock is a good buy. You are objective, data-driven, and conservative.

    Always respond with ONLY valid JSON matching this exact schema (no markdown, no prose):
    {
      "recommendation": "Strong Buy" | "Buy" | "Hold" | "Sell" | "Strong Sell",
      "confidence": "Low" | "Medium" | "High",
      "summary": "2-3 sentence thesis",
      "bullishFactors": ["factor1", "factor2", ...],
      "bearishFactors": ["factor1", "factor2", ...],
      "technicalOutlook": "1-2 sentence technical read",
      "newsSentiment": "Positive" | "Neutral" | "Negative" | "Mixed",
      "riskLevel": "Low" | "Moderate" | "High" | "Very High",
      "timeHorizon": "Short-term (days to weeks)" | "Medium-term (1-3 months)" | "Long-term (3+ months)"
    }

    Be balanced. Cite specific data points from the context. If data is insufficient, \
    set confidence to "Low". This is for informational purposes only, not investment advice.
    """

    static func userPrompt(for context: MarketContext) -> String {
        var lines: [String] = []
        lines.append("Analyze \(context.symbol) (\(context.name)) — \(context.type)")
        lines.append("")
        lines.append("## Price & Fundamentals")
        lines.append("Current price: \(String(format: "%.2f", context.currentPrice))")
        if let ch = context.dayChange, let pct = context.dayChangePercent {
            lines.append("Day change: \(String(format: "%.2f", ch)) (\(String(format: "%.2f", pct))%)")
        }
        if let pc = context.previousClose {
            lines.append("Previous close: \(String(format: "%.2f", pc))")
        }
        if let lo = context.week52Low, let hi = context.week52High {
            lines.append("52-week range: \(String(format: "%.2f", lo)) – \(String(format: "%.2f", hi))")
        }
        if let v = context.volume { lines.append("Volume: \(String(format: "%.0f", v))") }
        if let av = context.avgVolume { lines.append("Avg volume: \(String(format: "%.0f", av))") }
        if let mc = context.marketCap { lines.append("Market cap: \(String(format: "%.0f", mc))") }
        if let pe = context.peRatio { lines.append("P/E (TTM): \(String(format: "%.1f", pe))") }
        if let eps = context.eps { lines.append("EPS (TTM): \(String(format: "%.2f", eps))") }
        if let dy = context.dividendYield { lines.append("Dividend yield: \(String(format: "%.2f", dy))%") }
        if let beta = context.beta { lines.append("Beta: \(String(format: "%.2f", beta))") }
        if let sector = context.sector { lines.append("Sector: \(sector)") }
        if let industry = context.industry { lines.append("Industry: \(industry)") }
        lines.append("")
        lines.append("## Technical Indicators")
        if let rsi = context.rsi14 { lines.append("RSI(14): \(String(format: "%.1f", rsi))") }
        if let sma20 = context.sma20 { lines.append("SMA(20): \(String(format: "%.2f", sma20))") }
        if let sma50 = context.sma50 { lines.append("SMA(50): \(String(format: "%.2f", sma50))") }
        if let ema12 = context.ema12 { lines.append("EMA(12): \(String(format: "%.2f", ema12))") }
        if let ema26 = context.ema26 { lines.append("EMA(26): \(String(format: "%.2f", ema26))") }
        if let macd = context.macd, let sig = context.macdSignal, let hist = context.macdHistogram {
            lines.append("MACD: \(String(format: "%.3f", macd)), Signal: \(String(format: "%.3f", sig)), Histogram: \(String(format: "%.3f", hist))")
        }
        if let bu = context.bollingerUpper, let bm = context.bollingerMiddle, let bl = context.bollingerLower {
            lines.append("Bollinger(20,2): Upper \(String(format: "%.2f", bu)), Mid \(String(format: "%.2f", bm)), Lower \(String(format: "%.2f", bl))")
        }
        lines.append("Volume trend: \(context.volumeTrend)")
        lines.append("Price position: \(context.pricePosition)")
        lines.append("Recent closes (last 10): \(context.recentCloses.map { String(format: "%.2f", $0) }.joined(separator: ", "))")
        lines.append("")
        lines.append("## Recent News")
        if context.recentHeadlines.isEmpty {
            lines.append("No recent news available.")
        } else {
            for (i, headline) in context.recentHeadlines.enumerated() {
                let src = context.newsSources.indices.contains(i) ? context.newsSources[i] : "—"
                lines.append("- [\(src)] \(headline)")
            }
        }
        lines.append("")
        lines.append("Provide your analysis as JSON only.")
        return lines.joined(separator: "\n")
    }

    static func parseAnalysis(_ json: String) throws -> AIAnalysis {
        // Some models wrap JSON in markdown fences — strip them.
        var cleaned = json.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            if let start = cleaned.firstIndex(of: "{"),
               let end = cleaned.lastIndex(of: "}") {
                cleaned = String(cleaned[start...end])
            }
        }
        guard let data = cleaned.data(using: .utf8) else {
            throw AIError.invalidResponse("Could not encode response as UTF-8.")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            var analysis = try decoder.decode(AIAnalysis.self, from: data)
            // If the model omitted generatedAt, use now.
            return analysis
        } catch {
            // Fallback: try to decode with a default date.
            struct RawAnalysis: Codable {
                let recommendation: AIAnalysis.Recommendation
                let confidence: AIAnalysis.Confidence
                let summary: String
                let bullishFactors: [String]
                let bearishFactors: [String]
                let technicalOutlook: String
                let newsSentiment: String
                let riskLevel: AIAnalysis.RiskLevel
                let timeHorizon: AIAnalysis.TimeHorizon
            }
            let raw = try decoder.decode(RawAnalysis.self, from: data)
            return AIAnalysis(
                recommendation: raw.recommendation,
                confidence: raw.confidence,
                summary: raw.summary,
                bullishFactors: raw.bullishFactors,
                bearishFactors: raw.bearishFactors,
                technicalOutlook: raw.technicalOutlook,
                newsSentiment: raw.newsSentiment,
                riskLevel: raw.riskLevel,
                timeHorizon: raw.timeHorizon,
                generatedAt: Date()
            )
        }
    }
}

enum AIError: LocalizedError {
    case noAPIKey
    case invalidResponse(String)
    case httpError(Int, String)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:              return "No API key configured. Add one in Settings."
        case .invalidResponse(let m): return "AI returned an invalid response: \(m)"
        case .httpError(let code, let m): return "AI request failed (HTTP \(code)): \(m)"
        case .network(let e):        return e.localizedDescription
        }
    }
}
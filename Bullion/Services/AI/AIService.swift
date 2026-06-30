import Foundation

/// Orchestrates the AI research: gathers market data, computes technical
/// indicators, builds the prompt context, calls the configured LLM, and
/// returns a structured analysis.
final class AIService: @unchecked Sendable {
    let settings: AISettingsStore

    init(settings: AISettingsStore = AISettingsStore()) {
        self.settings = settings
    }

    /// Assemble MarketContext from live provider data + computed indicators.
    func buildContext(
        instrument: Instrument,
        quote: Quote?,
        stats: KeyStats?,
        candles: [Candle],
        news: [NewsItem]
    ) -> MarketContext {
        let closes = candles.map(\.c)
        let rsi14 = TechnicalIndicators.rsi(closes: closes)
        let sma20 = TechnicalIndicators.sma(values: closes, period: 20)
        let sma50 = TechnicalIndicators.sma(values: closes, period: 50)
        let ema12 = TechnicalIndicators.ema(values: closes, period: 12)
        let ema26 = TechnicalIndicators.ema(values: closes, period: 26)
        let macd = TechnicalIndicators.macd(closes: closes)
        let bollinger = TechnicalIndicators.bollinger(closes: closes)

        return MarketContext(
            symbol: instrument.symbol,
            name: instrument.name,
            type: instrument.type.displayName,
            currentPrice: quote?.last ?? 0,
            dayChange: quote?.change,
            dayChangePercent: quote?.changePercent,
            previousClose: quote?.previousClose ?? stats?.previousClose,
            week52Low: stats?.week52Low,
            week52High: stats?.week52High,
            volume: quote?.volume ?? stats?.volume,
            avgVolume: stats?.avgVolume,
            marketCap: stats?.marketCap,
            peRatio: stats?.peRatio,
            eps: stats?.eps,
            dividendYield: stats?.dividendYield,
            beta: stats?.beta,
            sector: stats?.sector,
            industry: stats?.industry,
            rsi14: rsi14,
            sma20: sma20,
            sma50: sma50,
            ema12: ema12,
            ema26: ema26,
            macd: macd?.macd,
            macdSignal: macd?.signal,
            macdHistogram: macd?.histogram,
            bollingerUpper: bollinger?.upper,
            bollingerMiddle: bollinger?.middle,
            bollingerLower: bollinger?.lower,
            volumeTrend: TechnicalIndicators.volumeTrend(candles: candles).rawValue,
            pricePosition: TechnicalIndicators.pricePosition(
                last: quote?.last ?? closes.last ?? 0,
                bollinger: bollinger
            ).rawValue,
            recentHeadlines: news.map(\.headline),
            newsSources: news.map(\.source),
            recentCloses: Array(closes.suffix(10))
        )
    }

    /// Run the full research analysis.
    func analyze(instrument: Instrument, provider: any MarketDataProvider) async throws -> AIAnalysis {
        guard settings.isConfigured else {
            throw AIError.noAPIKey
        }

        // Gather all data concurrently.
        async let quoteTask = provider.quote(instrument.symbol)
        async let statsTask = provider.stats(instrument.symbol)
        async let candlesTask = provider.candles(instrument.symbol, range: .threeM)
        async let newsTask = provider.news(instrument.symbol)

        let quote = try await quoteTask
        let stats = try await statsTask
        let candles = try await candlesTask
        let news = try await newsTask

        let context = buildContext(
            instrument: instrument, quote: quote, stats: stats,
            candles: candles, news: news
        )

        let aiProvider = settings.makeProvider()
        let model = settings.selectedModel
        let apiKey = settings.currentAPIKey()

        return try await aiProvider.analyze(context: context, model: model, apiKey: apiKey)
    }

    /// Free-form follow-up question about the most recent analysis. Reuses
    /// cached market data when available so it's cheap; falls back to a
    /// fresh context gather if needed. Returns the assistant's plain-text
    /// reply (no JSON parsing — follow-ups are conversational).
    func followUp(
        question: String,
        instrument: Instrument,
        provider: any MarketDataProvider,
        priorAnalysis: AIAnalysis?
    ) async throws -> String {
        guard settings.isConfigured else { throw AIError.noAPIKey }
        // Best-effort context: gather fresh (cheap, cached) so the answer is
        // grounded in current data even if the initial analysis is stale.
        let context: MarketContext
        do {
            async let quoteTask = provider.quote(instrument.symbol)
            async let statsTask = provider.stats(instrument.symbol)
            async let candlesTask = provider.candles(instrument.symbol, range: .threeM)
            async let newsTask = provider.news(instrument.symbol)
            context = buildContext(
                instrument: instrument,
                quote: try? await quoteTask,
                stats: try? await statsTask,
                candles: (try? await candlesTask) ?? [],
                news: (try? await newsTask) ?? []
            )
        } catch {
            context = buildContext(
                instrument: instrument, quote: nil, stats: nil,
                candles: [], news: []
            )
        }
        let systemPrompt = """
        \(AIPromptBuilder.systemPrompt)

        You previously produced this structured analysis of \(instrument.symbol):
        Recommendation: \(priorAnalysis?.recommendation.rawValue ?? "n/a")
        Confidence: \(priorAnalysis?.confidence.rawValue ?? "n/a")
        Summary: \(priorAnalysis?.summary ?? "n/a")
        Bullish: \(priorAnalysis?.bullishFactors.joined(separator: "; ") ?? "n/a")
        Bearish: \(priorAnalysis?.bearishFactors.joined(separator: "; ") ?? "n/a")

        The user is asking a follow-up question. Answer concisely in plain
        text (no JSON), grounded in the market context. If the answer isn't
        knowable from the data, say so honestly. For informational purposes
        only — not investment advice.
        """
        let userPrompt = """
        \(AIPromptBuilder.userPrompt(for: context))

        Follow-up question: \(question)
        """
        let aiProvider = settings.makeProvider()
        return try await aiProvider.chat(
            systemPrompt: systemPrompt, userPrompt: userPrompt,
            model: settings.selectedModel, apiKey: settings.currentAPIKey()
        )
    }
}
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

    /// Run the full research analysis. Gathers market data concurrently;
    /// individual source failures (news, stats) are tolerated — the analysis
    /// proceeds with whatever data is available. Only throws if the minimum
    /// (quote or candles for indicators) is missing. Returns both the
    /// analysis and the context used (so callers can cache the context for
    /// cheap follow-ups).
    func analyzeWithContext(instrument: Instrument, provider: any MarketDataProvider) async throws -> (AIAnalysis, MarketContext) {
        guard settings.isConfigured else {
            throw AIError.noAPIKey
        }

        // Gather all data concurrently, tolerating per-source failures.
        async let quoteTask = try? await provider.quote(instrument.symbol)
        async let statsTask = try? await provider.stats(instrument.symbol)
        async let candlesTask = try? await provider.candles(instrument.symbol, range: .threeM)
        async let newsTask = try? await provider.news(instrument.symbol)

        let quote = await quoteTask
        let stats = await statsTask
        let candles = (await candlesTask) ?? []
        let news = (await newsTask) ?? []

        if quote == nil && candles.count < 10 {
            throw AIError.insufficientData(instrument.symbol)
        }

        let context = buildContext(
            instrument: instrument, quote: quote, stats: stats,
            candles: candles, news: news
        )

        let aiProvider = settings.makeProvider()
        let model = settings.selectedModel
        let apiKey = settings.currentAPIKey()

        let analysis = try await aiProvider.analyze(context: context, model: model, apiKey: apiKey)
        return (analysis, context)
    }

    /// Backward-compatible thin wrapper around `analyzeWithContext`.
    func analyze(instrument: Instrument, provider: any MarketDataProvider) async throws -> AIAnalysis {
        try await analyzeWithContext(instrument: instrument, provider: provider).0
    }

    /// Stream the analysis token-by-token. Gathers market data first (same
    /// graceful degradation as analyzeWithContext), then streams the LLM
    /// response. The caller receives text deltas and must parse the final
    /// accumulated text via AIPromptBuilder.parseAnalysis when the stream
    /// finishes. Returns (stream, context) so the VM can cache the context.
    func analyzeStreamWithContext(
        instrument: Instrument, provider: any MarketDataProvider
    ) async throws -> (AsyncThrowingStream<String, Error>, MarketContext) {
        guard settings.isConfigured else { throw AIError.noAPIKey }

        async let quoteTask = try? await provider.quote(instrument.symbol)
        async let statsTask = try? await provider.stats(instrument.symbol)
        async let candlesTask = try? await provider.candles(instrument.symbol, range: .threeM)
        async let newsTask = try? await provider.news(instrument.symbol)

        let quote = await quoteTask
        let stats = await statsTask
        let candles = (await candlesTask) ?? []
        let news = (await newsTask) ?? []

        if quote == nil && candles.count < 10 {
            throw AIError.insufficientData(instrument.symbol)
        }

        let context = buildContext(
            instrument: instrument, quote: quote, stats: stats,
            candles: candles, news: news
        )

        let aiProvider = settings.makeProvider()
        let stream = try await aiProvider.analyzeStream(
            context: context, model: settings.selectedModel, apiKey: settings.currentAPIKey()
        )
        return (stream, context)
    }

    /// Free-form follow-up question about the most recent analysis. Reuses
    /// the cached market context from the initial analysis so it's cheap
    /// and fast (no re-fetch). If no cached context exists, gathers fresh.
    /// Sends conversation history so the model has memory of prior turns.
    func followUp(
        question: String,
        instrument: Instrument,
        provider: any MarketDataProvider,
        priorAnalysis: AIAnalysis?,
        cachedContext: MarketContext? = nil,
        history: [(role: ChatRole, text: String)] = []
    ) async throws -> String {
        guard settings.isConfigured else { throw AIError.noAPIKey }

        // Reuse cached context if available; only gather fresh if missing.
        // This avoids full network latency on every follow-up and prevents
        // context drift (price moved → assistant contradicts itself).
        let context: MarketContext
        if let cached = cachedContext {
            context = cached
        } else {
            async let quoteTask = try? await provider.quote(instrument.symbol)
            async let statsTask = try? await provider.stats(instrument.symbol)
            async let candlesTask = try? await provider.candles(instrument.symbol, range: .threeM)
            async let newsTask = try? await provider.news(instrument.symbol)
            context = buildContext(
                instrument: instrument,
                quote: await quoteTask,
                stats: await statsTask,
                candles: (await candlesTask) ?? [],
                news: (await newsTask) ?? []
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

        // Build the full message array from conversation history + the new
        // turn. Cap to the last 20 turns to avoid unbounded context.
        let trimmedHistory = history.suffix(20)
        let messages = trimmedHistory.map { turn in
            ["role": turn.role == .user ? "user" : "assistant",
             "content": turn.text] as [String: Any]
        }
        return try await aiProvider.chatStream(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            history: messages,
            model: settings.selectedModel,
            apiKey: settings.currentAPIKey()
        )
    }
}
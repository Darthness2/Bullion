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
}
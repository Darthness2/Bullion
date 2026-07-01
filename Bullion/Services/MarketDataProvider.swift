import Foundation

// MARK: - MarketDataProvider

/// Provider-agnostic market data interface. The concrete provider (Polygon,
/// Finnhub, etc.) is swappable without touching the UI.
///
/// Capability flags let the UI handle missing futures data honestly —
/// showing "Delayed" or "Data unavailable" badges instead of fabricating.
protocol MarketDataProvider: Sendable {
    var displayName: String { get }
    var supportsEquities: Bool { get }
    var supportsFutures: Bool { get }
    var futuresAreRealTime: Bool { get }

    func search(_ query: String) async throws -> [Instrument]
    func quote(_ symbol: String) async throws -> Quote
    func quotes(_ symbols: [String]) async throws -> [Quote]
    func stats(_ symbol: String) async throws -> KeyStats
    func candles(_ symbol: String, range: ChartRange) async throws -> [Candle]
    func news(_ symbol: String) async throws -> [NewsItem]

    /// Headline/summary instruments for the Markets home screen.
    func headlineInstruments() async throws -> [Instrument]
    /// Curated "most active" list when the provider doesn't expose one.
    func defaultActiveSymbols() -> [String]
    /// Curated popular stocks as full Instruments (with correct exchanges).
    func popularStocks() -> [Instrument]
    /// Curated popular futures as full Instruments.
    func popularFutures() -> [Instrument]
}

// MARK: - Default implementations (convenience)

extension MarketDataProvider {
    /// Default batch implementation: fans out per-symbol `quote()` calls
    /// concurrently. Individual symbol failures (404, delisted, halted) are
    /// skipped rather than killing the whole batch — one bad symbol must
    /// not collapse Markets/Watchlist/Search to .failed for every symbol.
    func quotes(_ symbols: [String]) async throws -> [Quote] {
        await withTaskGroup(of: Quote?.self) { group in
            for symbol in symbols {
                group.addTask { try? await self.quote(symbol) }
            }
            var result: [Quote] = []
            for await q in group { if let q { result.append(q) } }
            return result
        }
    }

    var futuresAreRealTime: Bool { false }
}
import Foundation
import SwiftUI

@Observable
final class MarketsViewModel {
    enum Segment: String, CaseIterable, Identifiable, SegmentedPillOption {
        case stocks = "Stocks"
        case futures = "Futures"
        var id: String { rawValue }
        var pillTitle: String { rawValue }
    }

    var segment: Segment = .stocks {
        didSet {
            guard segment != oldValue else { return }
            Task { await loadActive() }
        }
    }
    var headlineQuotes: LoadState<[Quote]> = .idle
    var headlineInstruments: [Instrument] = []
    var headlineSparklines: [String: [Double]] = [:]
    var activeQuotes: LoadState<[Quote]> = .idle
    var activeInstruments: [Instrument] = []
    var lastUpdated: Date?
    var isRefreshing = false

    private let provider: any MarketDataProvider
    private let quoteCache: QuoteCache?
    private var refreshTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?

    init(provider: any MarketDataProvider, quoteCache: QuoteCache? = nil) {
        self.provider = provider
        self.quoteCache = quoteCache
    }

    @MainActor
    func refresh() async {
        // Cancel any in-flight load so pull-to-refresh always re-runs,
        // never silently no-ops because an auto-refresh tick landed first.
        refreshTask?.cancel()
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            self.isRefreshing = true
            await self.load()
            self.isRefreshing = false
        }
        refreshTask = task
        await task.value
    }

    @MainActor
    func load() async {
        // Headlines and active are independent — run them concurrently.
        async let h: Void = loadHeadlines()
        async let a: Void = loadActive()
        _ = await (h, a)
    }

    @MainActor
    func loadHeadlines() async {
        headlineQuotes = .loading
        do {
            let instruments = try await provider.headlineInstruments()
            headlineInstruments = instruments
            let symbols = instruments.map(\.symbol)
            // Check cache first.
            var quotes: [Quote] = []
            var toFetch: [String] = []
            if let cache = quoteCache {
                for sym in symbols {
                    if let q = await cache.get(sym) { quotes.append(q) }
                    else { toFetch.append(sym) }
                }
            } else {
                toFetch = symbols
            }
            if !toFetch.isEmpty {
                let fetched = try await provider.quotes(toFetch)
                quotes.append(contentsOf: fetched)
                if let cache = quoteCache { await cache.setAll(fetched) }
            }
            // Fetch real 1D candle closes for sparklines (concurrent, cached-friendly).
            let sparklineTask = Task { @MainActor [weak self] in
                guard let self else { return [:] as [String: [Double]] }
                var sparks: [String: [Double]] = [:]
                await withTaskGroup(of: (String, [Double]).self) { group in
                    for sym in symbols {
                        group.addTask { [weak self] in
                            guard let self else { return (sym, []) }
                            if let cached = await self.quoteCache?.getSparkline(sym) {
                                return (sym, cached)
                            }
                            if let candles = try? await self.provider.candles(sym, range: .oneD),
                               !candles.isEmpty {
                                let closes = candles.map(\.c)
                                await self.quoteCache?.setSparkline(sym, closes: closes)
                                return (sym, closes)
                            }
                            return (sym, [])
                        }
                    }
                    for await (sym, closes) in group { sparks[sym] = closes }
                }
                return sparks
            }
            // Preserve curated instrument order — otherwise cache-hits jump to
            // the front and the headline cards reshuffle on every refresh.
            let bySymbol = Dictionary(uniqueKeysWithValues: quotes.map { ($0.symbol, $0) })
            let ordered = symbols.compactMap { bySymbol[$0] }
            headlineQuotes = ordered.isEmpty ? .empty : .loaded(ordered)
            headlineSparklines = await sparklineTask.value
            lastUpdated = Date()
        } catch {
            headlineQuotes = .failed(error.localizedDescription)
        }
    }

    @MainActor
    func loadActive() async {
        activeQuotes = .loading
        do {
            // Segment-aware curated lists with correct exchanges.
            let instruments: [Instrument]
            switch segment {
            case .stocks:  instruments = provider.popularStocks()
            case .futures: instruments = provider.popularFutures()
            }
            activeInstruments = instruments
            let symbols = instruments.map(\.symbol)
            var quotes: [Quote] = []
            var toFetch: [String] = []
            if let cache = quoteCache {
                for sym in symbols {
                    if let q = await cache.get(sym) { quotes.append(q) }
                    else { toFetch.append(sym) }
                }
            } else {
                toFetch = symbols
            }
            if !toFetch.isEmpty {
                let fetched = try await provider.quotes(toFetch)
                quotes.append(contentsOf: fetched)
                if let cache = quoteCache { await cache.setAll(fetched) }
            }
            // Preserve instrument order in the displayed list.
            let bySymbol = Dictionary(uniqueKeysWithValues: quotes.map { ($0.symbol, $0) })
            let ordered = symbols.compactMap { bySymbol[$0] }
            activeQuotes = ordered.isEmpty ? .empty : .loaded(ordered)
        } catch {
            activeQuotes = .failed(error.localizedDescription)
        }
    }

    // MARK: - Auto-refresh timer

    /// Starts an auto-refresh timer. Pauses when the app backgrounds.
    func startAutoRefresh(intervalSeconds: Int) {
        stopAutoRefresh()
        guard intervalSeconds > 0 else { return }
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(intervalSeconds))
                guard !Task.isCancelled else { return }
                await self?.refresh()
            }
        }
    }

    func stopAutoRefresh() {
        timerTask?.cancel()
        timerTask = nil
    }
}
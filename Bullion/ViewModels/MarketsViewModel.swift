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

    var segment: Segment = .stocks
    var headlineQuotes: LoadState<[Quote]> = .idle
    var headlineInstruments: [Instrument] = []
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
    func load() async {
        await loadHeadlines()
        await loadActive()
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
            headlineQuotes = quotes.isEmpty ? .empty : .loaded(quotes)
            lastUpdated = Date()
        } catch {
            headlineQuotes = .failed(error.localizedDescription)
        }
    }

    @MainActor
    func loadActive() async {
        activeQuotes = .loading
        do {
            let symbols = provider.defaultActiveSymbols()
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
            activeInstruments = symbols.map { sym in
                Instrument(symbol: sym, name: displayNameFor(sym), type: .stock, exchange: "NASDAQ")
            }
            activeQuotes = quotes.isEmpty ? .empty : .loaded(quotes)
        } catch {
            activeQuotes = .failed(error.localizedDescription)
        }
    }

    @MainActor
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        await load()
        isRefreshing = false
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

    private func displayNameFor(_ symbol: String) -> String {
        switch symbol {
        case "AAPL":  return "Apple Inc."
        case "MSFT":  return "Microsoft Corporation"
        case "NVDA":  return "NVIDIA Corporation"
        case "TSLA":  return "Tesla, Inc."
        case "AMZN":  return "Amazon.com, Inc."
        case "META":  return "Meta Platforms, Inc."
        case "AMD":   return "Advanced Micro Devices"
        case "GOOGL": return "Alphabet Inc."
        default:      return symbol
        }
    }
}
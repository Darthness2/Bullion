import Foundation

@Observable
final class InstrumentDetailViewModel {
    let instrument: Instrument

    var quote: LoadState<Quote> = .idle
    var stats: LoadState<KeyStats> = .idle
    var candles: LoadState<[Candle]> = .idle
    var news: LoadState<[NewsItem]> = .idle
    var selectedRange: ChartRange = .oneM {
        didSet {
            guard selectedRange != oldValue else { return }
            candlesTask?.cancel()
            candlesTask = Task { await loadCandles() }
        }
    }
    var isWatched = false

    private let provider: any MarketDataProvider
    private let watchlist: WatchlistViewModel
    private var candlesTask: Task<Void, Never>?

    init(instrument: Instrument, provider: any MarketDataProvider, watchlist: WatchlistViewModel) {
        self.instrument = instrument
        self.provider = provider
        self.watchlist = watchlist
        self.isWatched = watchlist.contains(instrument)
    }

    @MainActor
    func load() async {
        async let q: Void = loadQuote()
        async let s: Void = loadStats()
        async let c: Void = loadCandles()
        async let n: Void = loadNews()
        _ = await (q, s, c, n)
        isWatched = watchlist.contains(instrument)
    }

    @MainActor
    func loadQuote() async {
        quote = .loading
        do {
            let q = try await provider.quote(instrument.symbol)
            quote = .loaded(q)
        } catch {
            quote = .failed(error.localizedDescription)
        }
    }

    @MainActor
    func loadStats() async {
        stats = .loading
        do {
            let s = try await provider.stats(instrument.symbol)
            stats = .loaded(s)
        } catch {
            stats = .failed(error.localizedDescription)
        }
    }

    @MainActor
    func loadCandles() async {
        let range = selectedRange
        candles = .loading
        do {
            let c = try await provider.candles(instrument.symbol, range: range)
            // A newer range was selected while this was in flight — drop the
            // stale result rather than clobbering the current range's data.
            guard !Task.isCancelled, range == selectedRange else { return }
            candles = c.isEmpty ? .empty : .loaded(c)
        } catch {
            guard !Task.isCancelled, range == selectedRange else { return }
            candles = .failed(error.localizedDescription)
        }
    }

    @MainActor
    func loadNews() async {
        news = .loading
        do {
            let n = try await provider.news(instrument.symbol)
            news = n.isEmpty ? .empty : .loaded(n)
        } catch {
            news = .failed(error.localizedDescription)
        }
    }

    @MainActor
    func toggleWatchlist() {
        if isWatched {
            watchlist.remove(instrument)
        } else {
            watchlist.add(instrument)
        }
        isWatched = watchlist.contains(instrument)
    }
}
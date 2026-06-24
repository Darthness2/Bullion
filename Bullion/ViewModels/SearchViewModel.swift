import Foundation

@Observable
final class SearchViewModel {
    var query: String = ""
    var results: LoadState<[Instrument]> = .idle
    var quotesBySymbol: [String: Quote] = [:]
    var hasSearched = false

    private let provider: any MarketDataProvider
    private let quoteCache: QuoteCache?
    private var debounceTask: Task<Void, Never>?

    init(provider: any MarketDataProvider, quoteCache: QuoteCache? = nil) {
        self.provider = provider
        self.quoteCache = quoteCache
    }

    func search() {
        debounceTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            results = .idle
            hasSearched = false
            quotesBySymbol = [:]
            return
        }
        debounceTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await self.performSearch(trimmed)
        }
    }

    @MainActor
    private func performSearch(_ q: String) async {
        results = .loading
        hasSearched = true
        do {
            let found = try await provider.search(q)
            results = found.isEmpty ? .empty : .loaded(found)
            // Fetch quotes for results so rows show live prices.
            await fetchQuotes(for: found)
        } catch {
            results = .failed(error.localizedDescription)
        }
    }

    @MainActor
    private func fetchQuotes(for instruments: [Instrument]) async {
        guard !instruments.isEmpty else { return }
        let symbols = instruments.map(\.symbol)
        do {
            // Check cache first.
            var cached: [Quote] = []
            var toFetch: [String] = []
            if let cache = quoteCache {
                for sym in symbols {
                    if let q = await cache.get(sym) { cached.append(q) }
                    else { toFetch.append(sym) }
                }
            } else {
                toFetch = symbols
            }
            if !toFetch.isEmpty {
                let fetched = try await provider.quotes(toFetch)
                cached.append(contentsOf: fetched)
                if let cache = quoteCache { await cache.setAll(fetched) }
            }
            for q in cached { quotesBySymbol[q.symbol] = q }
        } catch {
            // Non-fatal: rows still show symbol/name without quotes.
        }
    }

    func clear() {
        query = ""
        results = .idle
        hasSearched = false
        quotesBySymbol = [:]
        debounceTask?.cancel()
    }
}
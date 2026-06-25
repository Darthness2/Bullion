import Foundation

/// Thread-safe in-memory quote cache with TTL. Stubbed for Milestone 1;
/// throttling/coalescing of duplicate requests lands in Milestone 2.
actor QuoteCache {
    private struct Entry { let quote: Quote; let cachedAt: Date }
    private var cache: [String: Entry] = [:]
    private let ttl: TimeInterval
    private let maxEntries: Int

    init(ttl: TimeInterval = 15, maxEntries: Int = 500) {
        self.ttl = ttl
        self.maxEntries = maxEntries
    }

    func get(_ symbol: String) -> Quote? {
        guard let entry = cache[symbol] else { return nil }
        if Date().timeIntervalSince(entry.cachedAt) > ttl {
            cache[symbol] = nil
            return nil
        }
        return entry.quote
    }

    func set(_ quote: Quote) {
        // Cap memory: if full and this is a new symbol, evict the oldest entry.
        if cache[quote.symbol] == nil, cache.count >= maxEntries,
           let oldest = cache.min(by: { $0.value.cachedAt < $1.value.cachedAt })?.key {
            cache[oldest] = nil
        }
        cache[quote.symbol] = Entry(quote: quote, cachedAt: Date())
    }

    func setAll(_ quotes: [Quote]) {
        for q in quotes { set(q) }
    }

    func clear() {
        cache.removeAll()
    }

    func isStale(_ symbol: String) -> Bool {
        guard let entry = cache[symbol] else { return true }
        return Date().timeIntervalSince(entry.cachedAt) > ttl
    }
}
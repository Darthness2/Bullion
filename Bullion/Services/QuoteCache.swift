import Foundation

/// Thread-safe in-memory quote cache with TTL. Deduplicates concurrent
/// requests for the same symbol so N callers share one network fetch.
actor QuoteCache {
    private struct Entry { let quote: Quote; let cachedAt: Date }
    private struct SparklineEntry { let closes: [Double]; let cachedAt: Date }
    private var cache: [String: Entry] = [:]
    private var sparklines: [String: SparklineEntry] = [:]
    /// In-flight quote fetch tasks — when non-nil, concurrent callers for the
    /// same symbol await this task instead of starting a new fetch.
    private var inFlightQuotes: [String: Task<Quote?, Never>] = [:]
    private let ttl: TimeInterval
    private let sparklineTtl: TimeInterval
    private let maxEntries: Int

    init(ttl: TimeInterval = 15, sparklineTtl: TimeInterval = 120, maxEntries: Int = 500) {
        self.ttl = ttl
        self.sparklineTtl = sparklineTtl
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

    // MARK: - In-flight dedup

    /// Returns an in-flight task for `symbol` if one exists, so concurrent
    /// callers share a single network fetch. The task resolves to `Quote?`
    /// (nil means the fetch failed or returned nothing). Callers should
    /// `await` the returned task and then `set` the result if non-nil.
    func inFlightTask(for symbol: String) -> Task<Quote?, Never>? {
        inFlightQuotes[symbol]
    }

    /// Register an in-flight task for `symbol`. When the task completes,
    /// call `clearInFlight(symbol:)` to remove it.
    func setInFlight(_ symbol: String, task: Task<Quote?, Never>) {
        inFlightQuotes[symbol] = task
    }

    func clearInFlight(_ symbol: String) {
        inFlightQuotes.removeValue(forKey: symbol)
    }

    // MARK: - Sparkline cache (longer TTL — intraday closes don't change as often)

    func getSparkline(_ symbol: String) -> [Double]? {
        guard let entry = sparklines[symbol] else { return nil }
        if Date().timeIntervalSince(entry.cachedAt) > sparklineTtl {
            sparklines[symbol] = nil
            return nil
        }
        return entry.closes
    }

    func setSparkline(_ symbol: String, closes: [Double]) {
        sparklines[symbol] = SparklineEntry(closes: closes, cachedAt: Date())
    }

    func clear() {
        cache.removeAll()
        sparklines.removeAll()
        inFlightQuotes.removeAll()
    }
}
import Foundation

/// Currency conversion via Yahoo's forex symbols (e.g. `EURUSD=X`).
/// No API key required. Rates are cached with a TTL so a portfolio refresh
/// doesn't re-fetch the same pairs on every call.
///
/// The base currency is USD. `convert(_:from:to:)` looks up the rate between
/// the two codes; if either equals the target, the value is returned as-is.
final class FXService: @unchecked Sendable {
    static let shared = FXService()

    private let session: URLSession
    private let cache: NSCache<NSString, NSNumber> = NSCache()
    private var fetchedAt: [String: Date] = [:]
    private let ttl: TimeInterval = 300          // 5 minutes
    private let cacheLock = NSLock()

    init(session: URLSession = .shared) {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"]
        self.session = URLSession(configuration: config)
    }

    /// Convert `amount` from `from` to `to`. Returns the original amount
    /// (no conversion) when both currencies are equal, or when the rate is
    /// unavailable (e.g. offline, unknown code). Callers should treat a
    /// same-currency or unavailable case as "no FX needed" rather than an error.
    func convert(_ amount: Double, from: String, to: String) async -> Double {
        let fromU = from.uppercased()
        let toU = to.uppercased()
        guard !fromU.isEmpty, !toU.isEmpty, fromU != toU else { return amount }
        let rate = await rate(from: fromU, to: toU)
        return amount * rate
    }

    /// Convert many amounts sharing a source currency to one target.
    func convertMany(_ amounts: [Double], from: String, to: String) async -> [Double] {
        let fromU = from.uppercased()
        let toU = to.uppercased()
        guard !fromU.isEmpty, !toU.isEmpty, fromU != toU else { return amounts }
        let rate = await rate(from: fromU, to: toU)
        return amounts.map { $0 * rate }
    }

    /// Current rate `from -> to` (1 unit of `from` buys `rate` units of `to`).
    /// Falls back to 1.0 when the rate can't be fetched so callers never crash
    /// on a missing FX pair — the value is simply left unconverted.
    func rate(from: String, to: String) async -> Double {
        let fromU = from.uppercased()
        let toU = to.uppercased()
        guard !fromU.isEmpty, !toU.isEmpty, fromU != toU else { return 1.0 }
        let key = "\(fromU)\(toU)" as NSString
        if let cached = cachedRate(key: key) { return cached }
        let yahooSymbol = "\(fromU)\(toU)=X"
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(yahooSymbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? yahooSymbol)?interval=1d&range=1d") else {
            return 1.0
        }
        struct ChartResponse: Codable {
            struct Chart: Codable {
                struct Result: Codable {
                    struct Meta: Codable { let regularMarketPrice: Double? }
                    let meta: Meta
                }
                let result: [Result]?
                let error: ErrorInfo?
            }
            struct ErrorInfo: Codable { let description: String? }
            let chart: Chart
        }
        do {
            let (data, _) = try await session.data(from: url)
            let resp = try JSONDecoder().decode(ChartResponse.self, from: data)
            if let rate = resp.chart.result?.first?.meta.regularMarketPrice, rate > 0 {
                storeRate(key: key, rate: rate)
                return rate
            }
        } catch {
            // Offline / unknown pair — leave unconverted.
        }
        return 1.0
    }

    private func cachedRate(key: NSString) -> Double? {
        cacheLock.lock(); defer { cacheLock.unlock() }
        guard let fetched = fetchedAt[key as String],
              Date().timeIntervalSince(fetched) < ttl,
              let rate = cache.object(forKey: key) else { return nil }
        return rate.doubleValue
    }

    private func storeRate(key: NSString, rate: Double) {
        cacheLock.lock(); defer { cacheLock.unlock() }
        cache.setObject(NSNumber(value: rate), forKey: key)
        fetchedAt[key as String] = Date()
    }
}
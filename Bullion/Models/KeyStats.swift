import Foundation

/// Key statistics for an instrument. All fields optional — render only
/// what the provider returns. Futures-specific fields are included so the
/// same struct serves equities, ETFs, and futures.
struct KeyStats: Codable, Hashable, Sendable {
    // Common
    var open: Double?
    var previousClose: Double?
    var dayLow: Double?
    var dayHigh: Double?
    var week52Low: Double?
    var week52High: Double?
    var volume: Double?
    var avgVolume: Double?

    // Equities / ETFs
    var marketCap: Double?
    var peRatio: Double?
    var eps: Double?
    var dividendYield: Double?
    var beta: Double?
    var sharesOutstanding: Double?
    var nextEarningsDate: String?
    var sector: String?
    var industry: String?

    // Futures
    var openInterest: Double?
    var contractSize: Double?
    var tickSize: Double?
    var expiry: String?
    var settlement: Double?
    var continuous: Bool?

    /// Whether this stats set contains any futures-specific data.
    var hasFuturesFields: Bool {
        openInterest != nil || contractSize != nil || tickSize != nil
            || expiry != nil || settlement != nil
    }
}
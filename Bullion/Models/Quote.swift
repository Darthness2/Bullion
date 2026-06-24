import Foundation

struct Quote: Codable, Hashable, Identifiable, Sendable {
    var id: String { symbol }
    let symbol: String
    let last: Double
    let open: Double?
    let previousClose: Double?
    let dayLow: Double?
    let dayHigh: Double?
    let volume: Double?
    let timestamp: Date
    let isDelayed: Bool

    var change: Double? {
        previousClose.map { last - $0 }
    }

    var changePercent: Double? {
        previousClose.flatMap { $0 == 0 ? nil : (last - $0) / $0 * 100 }
    }

    var dayRangeText: String? {
        guard let low = dayLow, let high = dayHigh else { return nil }
        return "\(NumberFormatting.price(low)) – \(NumberFormatting.price(high))"
    }
}
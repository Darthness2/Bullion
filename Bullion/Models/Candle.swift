import Foundation

enum ChartRange: String, CaseIterable, Identifiable, Sendable, SegmentedPillOption {
    case oneD = "1D"
    case oneW = "1W"
    case oneM = "1M"
    case threeM = "3M"
    case oneY = "1Y"
    case fiveY = "5Y"
    case max  = "MAX"

    var id: String { rawValue }

    var displayName: String { rawValue }
    var pillTitle: String { rawValue }
}

struct Candle: Codable, Hashable, Sendable {
    let t: Date
    let o: Double
    let h: Double
    let l: Double
    let c: Double
    let v: Double?
}
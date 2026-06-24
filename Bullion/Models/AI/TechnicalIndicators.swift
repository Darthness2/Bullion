import Foundation

/// Pure-Swift technical indicators computed from candle arrays.
/// No third-party dependencies. Used by the AI research agent as
/// quantitative context alongside news and market movements.
enum TechnicalIndicators {

    // MARK: - Simple Moving Average

    static func sma(values: [Double], period: Int) -> Double? {
        guard values.count >= period, period > 0 else { return nil }
        let slice = values.suffix(period)
        return slice.reduce(0, +) / Double(period)
    }

    // MARK: - Exponential Moving Average

    static func ema(values: [Double], period: Int) -> Double? {
        guard values.count >= period, period > 0 else { return nil }
        let k = 2.0 / (Double(period) + 1)
        var ema = values.prefix(period).reduce(0, +) / Double(period)
        for v in values.dropFirst(period) {
            ema = v * k + ema * (1 - k)
        }
        return ema
    }

    // MARK: - RSI (Relative Strength Index, 14-period default)

    static func rsi(closes: [Double], period: Int = 14) -> Double? {
        guard closes.count > period, period > 0 else { return nil }
        var gains: [Double] = []
        var losses: [Double] = []
        for i in 1..<closes.count {
            let diff = closes[i] - closes[i - 1]
            gains.append(max(0, diff))
            losses.append(max(0, -diff))
        }
        let avgGain = gains.prefix(period).reduce(0, +) / Double(period)
        let avgLoss = losses.prefix(period).reduce(0, +) / Double(period)
        guard avgLoss != 0 else { return 100 }
        let rs = avgGain / avgLoss
        return 100 - (100 / (1 + rs))
    }

    // MARK: - MACD (12, 26, 9)

    struct MACD {
        let macd: Double
        let signal: Double
        let histogram: Double
    }

    static func macd(closes: [Double]) -> MACD? {
        guard closes.count >= 35 else { return nil }
        let ema12 = emaSeries(closes, period: 12)
        let ema26 = emaSeries(closes, period: 26)
        let count = min(ema12.count, ema26.count)
        guard count >= 9 else { return nil }
        let macdLine = (0..<count).map { ema12[ema12.count - count + $0] - ema26[ema26.count - count + $0] }
        guard let signalLine = ema(values: macdLine, period: 9) else { return nil }
        let lastMACD = macdLine.last!
        return MACD(macd: lastMACD, signal: signalLine, histogram: lastMACD - signalLine)
    }

    private static func emaSeries(_ values: [Double], period: Int) -> [Double] {
        guard values.count >= period, period > 0 else { return [] }
        let k = 2.0 / (Double(period) + 1)
        var result: [Double] = []
        var ema = values.prefix(period).reduce(0, +) / Double(period)
        result.append(ema)
        for v in values.dropFirst(period) {
            ema = v * k + ema * (1 - k)
            result.append(ema)
        }
        return result
    }

    // MARK: - Bollinger Bands (20, 2σ)

    struct Bollinger {
        let upper: Double
        let middle: Double
        let lower: Double
    }

    static func bollinger(closes: [Double], period: Int = 20, stdDev: Double = 2) -> Bollinger? {
        guard closes.count >= period, period > 0 else { return nil }
        let slice = Array(closes.suffix(period))
        let mean = slice.reduce(0, +) / Double(period)
        let variance = slice.map { pow($0 - mean, 2) }.reduce(0, +) / Double(period)
        let sd = sqrt(variance)
        return Bollinger(upper: mean + stdDev * sd, middle: mean, lower: mean - stdDev * sd)
    }

    // MARK: - Volume trend

    static func volumeTrend(candles: [Candle]) -> Trend {
        guard candles.count >= 10 else { return .flat }
        let recent = candles.suffix(5).compactMap { $0.v }
        let prior = candles.dropLast(5).suffix(5).compactMap { $0.v }
        guard !recent.isEmpty, !prior.isEmpty else { return .flat }
        let recentAvg = recent.reduce(0, +) / Double(recent.count)
        let priorAvg = prior.reduce(0, +) / Double(prior.count)
        guard priorAvg != 0 else { return .flat }
        let ratio = recentAvg / priorAvg
        if ratio > 1.2 { return .rising }
        if ratio < 0.8 { return .falling }
        return .flat
    }

    // MARK: - Price position

    static func pricePosition(last: Double, bollinger: Bollinger?) -> PricePosition {
        guard let b = bollinger else { return .neutral }
        if last >= b.upper { return .aboveUpper }
        if last <= b.lower { return .belowLower }
        if last > b.middle { return .aboveMiddle }
        return .belowMiddle
    }
}

enum Trend: String, Codable, Sendable {
    case rising, falling, flat
}

enum PricePosition: String, Codable, Sendable {
    case aboveUpper, aboveMiddle, belowMiddle, belowLower, neutral
}
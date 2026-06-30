import Foundation

/// The AI's structured research verdict on an instrument.
struct AIAnalysis: Codable, Hashable, Sendable {
    let recommendation: Recommendation
    let confidence: Confidence
    let summary: String
    let bullishFactors: [String]
    let bearishFactors: [String]
    let technicalOutlook: String
    let newsSentiment: String
    let riskLevel: RiskLevel
    let timeHorizon: TimeHorizon
    let generatedAt: Date

    enum Recommendation: String, Codable, CaseIterable, Sendable {
        case strongBuy = "Strong Buy"
        case buy = "Buy"
        case hold = "Hold"
        case sell = "Sell"
        case strongSell = "Strong Sell"

        var color: String {
            switch self {
            case .strongBuy: return "positive"
            case .buy:       return "positive"
            case .hold:      return "neutral"
            case .sell:      return "negative"
            case .strongSell: return "negative"
            }
        }

        /// Tolerant decoder: matches the exact raw values case-insensitively
        /// (so "buy", "BUY", "Strong buy" all work) and maps a few common
        /// synonyms models emit ("Accumulate" -> buy, "Underperform" -> sell,
        /// "Outperform" -> buy, "Neutral" -> hold). Unknown strings default
        /// to `.hold` rather than throwing — a single deviating label must
        /// not sink the whole analysis.
        init(from decoder: Decoder) throws {
            let raw = (try decoder.singleValueContainer().decode(String.self))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = raw.lowercased()
            switch normalized {
            case "strong buy", "strong-buy", "strongbuy": self = .strongBuy
            case "buy", "accumulate", "outperform", "overweight", "add": self = .buy
            case "hold", "neutral", "equal-weight", "market perform", "n/a": self = .hold
            case "sell", "underperform", "underweight", "reduce": self = .sell
            case "strong sell", "strong-sell", "strongsell": self = .strongSell
            default: self = .hold
            }
        }
    }

    enum Confidence: String, Codable, CaseIterable, Sendable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"

        init(from decoder: Decoder) throws {
            let raw = (try decoder.singleValueContainer().decode(String.self))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            switch raw.lowercased() {
            case "low":  self = .low
            case "medium", "moderate": self = .medium
            case "high", "very high", "very-high": self = .high
            default:     self = .medium
            }
        }
    }

    enum RiskLevel: String, Codable, CaseIterable, Sendable {
        case low = "Low"
        case moderate = "Moderate"
        case high = "High"
        case veryHigh = "Very High"

        init(from decoder: Decoder) throws {
            let raw = (try decoder.singleValueContainer().decode(String.self))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            switch raw.lowercased() {
            case "low": self = .low
            case "moderate", "medium": self = .moderate
            case "high": self = .high
            case "very high", "very-high", "veryhigh", "extreme": self = .veryHigh
            default:   self = .moderate
            }
        }
    }

    enum TimeHorizon: String, Codable, CaseIterable, Sendable {
        case shortTerm = "Short-term (days to weeks)"
        case mediumTerm = "Medium-term (1-3 months)"
        case longTerm = "Long-term (3+ months)"

        init(from decoder: Decoder) throws {
            let raw = (try decoder.singleValueContainer().decode(String.self))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = raw.lowercased()
            if lower.contains("long") || lower.contains("3+") || lower.contains("3 months") {
                self = .longTerm
            } else if lower.contains("medium") || lower.contains("1-3") || lower.contains("1-3 months") {
                self = .mediumTerm
            } else {
                self = .shortTerm
            }
        }
    }
}

/// Quantitative context assembled from market data for the AI prompt.
struct MarketContext: Codable, Sendable {
    let symbol: String
    let name: String
    let type: String
    let currentPrice: Double
    let dayChange: Double?
    let dayChangePercent: Double?
    let previousClose: Double?
    let week52Low: Double?
    let week52High: Double?
    let volume: Double?
    let avgVolume: Double?
    let marketCap: Double?
    let peRatio: Double?
    let eps: Double?
    let dividendYield: Double?
    let beta: Double?
    let sector: String?
    let industry: String?
    // Technical indicators
    let rsi14: Double?
    let sma20: Double?
    let sma50: Double?
    let ema12: Double?
    let ema26: Double?
    let macd: Double?
    let macdSignal: Double?
    let macdHistogram: Double?
    let bollingerUpper: Double?
    let bollingerMiddle: Double?
    let bollingerLower: Double?
    let volumeTrend: String
    let pricePosition: String
    // News
    let recentHeadlines: [String]
    let newsSources: [String]
    // Recent price action (last 10 closes)
    let recentCloses: [Double]
}
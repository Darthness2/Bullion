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
    }

    enum Confidence: String, Codable, CaseIterable, Sendable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
    }

    enum RiskLevel: String, Codable, CaseIterable, Sendable {
        case low = "Low"
        case moderate = "Moderate"
        case high = "High"
        case veryHigh = "Very High"
    }

    enum TimeHorizon: String, Codable, CaseIterable, Sendable {
        case shortTerm = "Short-term (days to weeks)"
        case mediumTerm = "Medium-term (1-3 months)"
        case longTerm = "Long-term (3+ months)"
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
import Testing
import Foundation
@testable import Bullion

@Suite("Technical indicators")
struct TechnicalIndicatorTests {

    private let closes: [Double] = [
        100, 102, 101, 103, 105, 104, 106, 108, 107, 109,
        111, 110, 112, 114, 113, 115, 117, 116, 118, 120,
        119, 121, 123, 122, 124, 126, 125, 127, 129, 128,
        130, 132, 131, 133, 135
    ]

    @Test("SMA computes correctly over period")
    func smaTest() {
        let s = TechnicalIndicators.sma(values: closes, period: 10)
        #expect(s != nil)
        let last10 = closes.suffix(10).reduce(0, +) / 10
        #expect(abs((s ?? 0) - last10) < 0.001)
    }

    @Test("SMA returns nil when insufficient data")
    func smaInsufficient() {
        #expect(TechnicalIndicators.sma(values: [1, 2], period: 5) == nil)
    }

    @Test("RSI is between 0 and 100")
    func rsiRange() {
        let r = TechnicalIndicators.rsi(closes: closes, period: 14)
        #expect(r != nil)
        #expect((r ?? 0) >= 0 && (r ?? 0) <= 100)
    }

    @Test("RSI returns nil when insufficient data")
    func rsiInsufficient() {
        #expect(TechnicalIndicators.rsi(closes: [1, 2, 3], period: 14) == nil)
    }

    @Test("MACD computes macd, signal, and histogram")
    func macdTest() {
        let m = TechnicalIndicators.macd(closes: closes)
        #expect(m != nil)
        if let m {
            #expect(abs(m.histogram - (m.macd - m.signal)) < 0.001)
        }
    }

    @Test("Bollinger bands bracket the mean")
    func bollingerTest() {
        let b = TechnicalIndicators.bollinger(closes: closes)
        #expect(b != nil)
        if let b {
            #expect(b.upper > b.middle)
            #expect(b.lower < b.middle)
        }
    }

    @Test("Volume trend detects rising volume")
    func volumeTrendRising() {
        // 15 candles: first 10 have low volume, last 5 have high volume.
        // suffix(5) = indices 10-14 (high), dropLast(5).suffix(5) = indices 5-9 (low)
        let candles = (0..<15).map { i in
            Candle(t: Date().addingTimeInterval(TimeInterval(i)), o: 100, h: 101, l: 99,
                   c: 100, v: i < 10 ? Double(1000) : Double(3000))
        }
        #expect(TechnicalIndicators.volumeTrend(candles: candles) == .rising)
    }

    @Test("Price position above upper band")
    func pricePosition() {
        let b = TechnicalIndicators.Bollinger(upper: 120, middle: 100, lower: 80)
        #expect(TechnicalIndicators.pricePosition(last: 125, bollinger: b) == .aboveUpper)
        #expect(TechnicalIndicators.pricePosition(last: 110, bollinger: b) == .aboveMiddle)
        #expect(TechnicalIndicators.pricePosition(last: 90, bollinger: b) == .belowMiddle)
        #expect(TechnicalIndicators.pricePosition(last: 75, bollinger: b) == .belowLower)
    }

    @Test("AIPromptBuilder parses valid JSON")
    func parseAnalysis() throws {
        let json = """
        {
          "recommendation": "Buy",
          "confidence": "Medium",
          "summary": "Strong technicals with supportive news.",
          "bullishFactors": ["RSI neutral", "MACD crossover"],
          "bearishFactors": ["High valuation"],
          "technicalOutlook": "Bullish",
          "newsSentiment": "Positive",
          "riskLevel": "Moderate",
          "timeHorizon": "Medium-term (1-3 months)"
        }
        """
        let analysis = try AIPromptBuilder.parseAnalysis(json)
        #expect(analysis.recommendation == .buy)
        #expect(analysis.confidence == .medium)
        #expect(analysis.bullishFactors.count == 2)
    }

    @Test("AIPromptBuilder strips markdown fences")
    func parseMarkdownFencedJSON() throws {
        let json = """
        ```json
        {
          "recommendation": "Hold",
          "confidence": "Low",
          "summary": "Mixed signals.",
          "bullishFactors": [],
          "bearishFactors": ["Uncertainty"],
          "technicalOutlook": "Sideways",
          "newsSentiment": "Neutral",
          "riskLevel": "High",
          "timeHorizon": "Short-term (days to weeks)"
        }
        ```
        """
        let analysis = try AIPromptBuilder.parseAnalysis(json)
        #expect(analysis.recommendation == .hold)
        #expect(analysis.bearishFactors == ["Uncertainty"])
    }
}
import Testing
import Foundation
@testable import Bullion

@Suite("PortfolioAnalyticsEngine")
struct PortfolioAnalyticsEngineTests {

    /// 60 daily candles trending gently up with some noise — enough for
    /// beta/Sharpe/drawdown to be defined.
    private let sample: [Candle] = {
        var out: [Candle] = []
        var price = 100.0
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        for i in 0..<60 {
            // Pseudo-deterministic up-drift with a dip in the middle.
            let drift = i == 30 ? -0.08 : 0.002
            price = price * (1.0 + drift + Double(i % 7) * 0.0005)
            out.append(Candle(
                t: base.addingTimeInterval(TimeInterval(i) * 86_400),
                o: price, h: price * 1.01, l: price * 0.99, c: price, v: 1000
            ))
        }
        return out
    }()

    @Test("Beta vs an identical series is ~1.0")
    func betaIdentical() {
        let b = PortfolioAnalyticsEngine.computeBeta(
            holdingsCandles: ["X": sample], weights: ["X": 1.0], benchmark: sample
        )
        #expect(b != nil)
        #expect(abs((b ?? 0) - 1.0) < 0.01)
    }

    @Test("Beta vs a flat benchmark is nil (zero variance)")
    func betaFlatBenchmark() {
        var flat: [Candle] = []
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        for i in 0..<60 {
            flat.append(Candle(t: base.addingTimeInterval(TimeInterval(i) * 86_400), o: 50, h: 50, l: 50, c: 50, v: 1))
        }
        let b = PortfolioAnalyticsEngine.computeBeta(
            holdingsCandles: ["X": sample], weights: ["X": 1.0], benchmark: flat
        )
        #expect(b == nil)
    }

    @Test("Beta returns nil with insufficient data (< 10 returns)")
    func betaInsufficient() {
        let short = Array(sample.prefix(5))
        let b = PortfolioAnalyticsEngine.computeBeta(
            holdingsCandles: ["X": short], weights: ["X": 1.0], benchmark: sample
        )
        #expect(b == nil)
    }

    @Test("Sharpe is finite and positive for an upward-drifting series")
    func sharpePositive() {
        let s = PortfolioAnalyticsEngine.computeSharpe(holdingsCandles: ["X": sample], weights: ["X": 1.0])
        #expect(s != nil)
        #expect((s ?? 0) > 0)
        #expect((s ?? 0).isFinite)
    }

    @Test("Sharpe is nil for a flat series (zero std)")
    func sharpeFlatIsNil() {
        var flat: [Candle] = []
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        for i in 0..<60 {
            flat.append(Candle(t: base.addingTimeInterval(TimeInterval(i) * 86_400), o: 100, h: 100, l: 100, c: 100, v: 1))
        }
        let s = PortfolioAnalyticsEngine.computeSharpe(holdingsCandles: ["X": flat], weights: ["X": 1.0])
        #expect(s == nil)
    }

    @Test("Max drawdown of the sample (which dips 8% at i=30) is >= 7%")
    func maxDrawdown() {
        let dd = PortfolioAnalyticsEngine.computeMaxDrawdown(holdingsCandles: ["X": sample], weights: ["X": 1.0])
        #expect(dd != nil)
        #expect((dd ?? 0) > 0.07)
        #expect((dd ?? 0) < 1.0)
    }

    @Test("Max drawdown is 0 for a monotonically rising series")
    func maxDrawdownRising() {
        var rising: [Candle] = []
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        for i in 0..<30 {
            let p = Double(i + 1)
            rising.append(Candle(t: base.addingTimeInterval(TimeInterval(i) * 86_400), o: Double(i), h: p, l: Double(i), c: p, v: 1))
        }
        let dd = PortfolioAnalyticsEngine.computeMaxDrawdown(holdingsCandles: ["X": rising], weights: ["X": 1.0])
        #expect(dd == 0.0)
    }

    @Test("compute returns a populated struct with all fields")
    func computeStruct() {
        let a = PortfolioAnalyticsEngine.compute(
            holdingsCandles: ["X": sample], weights: ["X": 1.0], benchmark: sample
        )
        #expect(a.beta != nil)
        #expect(a.sharpe != nil)
        #expect(a.maxDrawdown != nil)
        #expect(a.diversification == 1)
        #expect(a.largestHoldingWeight == 1.0)
    }

    @Test("diversification counts distinct symbols, not positions")
    func diversification() {
        let a = PortfolioAnalyticsEngine.compute(
            holdingsCandles: ["X": sample, "Y": sample, "Z": sample],
            weights: ["X": 0.5, "Y": 0.3, "Z": 0.2],
            benchmark: sample
        )
        #expect(a.diversification == 3)
        #expect(a.largestHoldingWeight == 0.5)
    }

    @Test("dailyReturns length is candles.count - 1")
    func dailyReturnsLength() {
        #expect(PortfolioAnalyticsEngine.dailyReturns(sample).count == 59)
        #expect(PortfolioAnalyticsEngine.dailyReturns([sample[0]]).isEmpty)
        #expect(PortfolioAnalyticsEngine.dailyReturns([]).isEmpty)
    }

    @Test("Weighted beta averages across holdings")
    func weightedBeta() {
        // Two holdings identical to the benchmark -> beta 1.0 each, weighted 1.0.
        let b = PortfolioAnalyticsEngine.computeBeta(
            holdingsCandles: ["A": sample, "B": sample],
            weights: ["A": 0.6, "B": 0.4],
            benchmark: sample
        )
        #expect(abs((b ?? 0) - 1.0) < 0.01)
    }
}
import Foundation

/// Portfolio-level analytics: beta vs a benchmark (SPY), Sharpe ratio,
/// max drawdown, and simple correlation. These are the metrics a serious
/// investor expects from a "portfolio" screen but that Yahoo Finance and
/// Robinhood both underserve — a real differentiator for Bullion.
///
/// All are computed client-side from Yahoo candle history (no API key).
/// Returns optionals so the UI can honestly render "—" when there isn't
/// enough data rather than fabricating a number.
struct PortfolioAnalytics: Equatable, Sendable {
    let beta: Double?           // portfolio beta vs SPY
    let sharpe: Double?         // annualized Sharpe (risk-free approximated as 0)
    let maxDrawdown: Double?    // max peak-to-trough decline, as a fraction (0.25 = -25%)
    let diversification: Int    // number of distinct holdings
    let largestHoldingWeight: Double?  // concentration: top holding as fraction of total
}

enum PortfolioAnalyticsEngine {

    /// Compute portfolio analytics from per-holding 3-month daily candles
    /// and a benchmark (SPY) series. `holdingsCandles` is keyed by symbol.
    static func compute(
        holdingsCandles: [String: [Candle]],
        weights: [String: Double],         // symbol -> portfolio weight (0..1)
        benchmark: [Candle]
    ) -> PortfolioAnalytics {
        let beta = computeBeta(holdingsCandles: holdingsCandles, weights: weights, benchmark: benchmark)
        let sharpe = computeSharpe(holdingsCandles: holdingsCandles, weights: weights)
        let maxDD = computeMaxDrawdown(holdingsCandles: holdingsCandles, weights: weights)
        let diversification = holdingsCandles.count
        let largest = weights.values.max()
        return PortfolioAnalytics(
            beta: beta, sharpe: sharpe, maxDrawdown: maxDD,
            diversification: diversification, largestHoldingWeight: largest
        )
    }

    // MARK: - Beta (portfolio beta vs benchmark)

    /// Portfolio beta = weighted average of each holding's beta vs the
    /// benchmark. Each holding's beta = covariance(holding, bench) /
    /// variance(bench), computed from daily returns.
    static func computeBeta(
        holdingsCandles: [String: [Candle]], weights: [String: Double], benchmark: [Candle]
    ) -> Double? {
        let benchReturns = dailyReturns(benchmark)
        guard benchReturns.count >= 10 else { return nil }
        let benchVar = variance(benchReturns)
        guard benchVar > 0 else { return nil }
        var weightedBeta = 0.0
        var totalWeight = 0.0
        for (symbol, candles) in holdingsCandles {
            let w = weights[symbol] ?? 0
            guard w > 0 else { continue }
            let rets = dailyReturns(candles)
            guard rets.count >= 10 else { continue }
            let cov = covariance(rets, benchReturns)
            let holdingBeta = cov / benchVar
            weightedBeta += holdingBeta * w
            totalWeight += w
        }
        guard totalWeight > 0 else { return nil }
        return weightedBeta / totalWeight
    }

    // MARK: - Sharpe (annualized, risk-free ~ 0)

    /// Annualized Sharpe ratio of the portfolio's daily returns:
    /// mean(dailyReturns) / std(dailyReturns) * sqrt(252).
    /// Uses the equal-weighted average of per-holding daily returns as a
    /// simple proxy when individual position history aligns.
    static func computeSharpe(holdingsCandles: [String: [Candle]], weights: [String: Double]) -> Double? {
        // Align per-holding daily returns by index, then build a portfolio
        // return series as the weighted sum each day.
        var perSymbol: [(symbol: String, returns: [Double], weight: Double)] = []
        for (symbol, candles) in holdingsCandles {
            let w = weights[symbol] ?? 0
            guard w > 0 else { continue }
            let r = dailyReturns(candles)
            guard r.count >= 10 else { continue }
            perSymbol.append((symbol, r, w))
        }
        guard !perSymbol.isEmpty else { return nil }
        let minLen = perSymbol.map(\.returns.count).min() ?? 0
        guard minLen >= 10 else { return nil }
        let totalW = perSymbol.map(\.weight).reduce(0, +)
        guard totalW > 0 else { return nil }
        var portfolioReturns: [Double] = []
        for i in 0..<minLen {
            let daily = perSymbol.reduce(0.0) { acc, entry in
                acc + entry.returns[i] * (entry.weight / totalW)
            }
            portfolioReturns.append(daily)
        }
        let mean = portfolioReturns.reduce(0, +) / Double(portfolioReturns.count)
        let sd = std(portfolioReturns)
        guard sd > 0 else { return nil }
        let annualization = sqrt(252.0)
        return (mean / sd) * annualization
    }

    // MARK: - Max drawdown

    /// Maximum peak-to-trough decline of the equal-weighted portfolio
    /// value series, returned as a positive fraction (0.25 = -25%).
    static func computeMaxDrawdown(holdingsCandles: [String: [Candle]], weights: [String: Double]) -> Double? {
        // Build an equal-weighted cumulative return index from each holding's
        // close series (rebased to 1.0 at its first value), averaged across
        // holdings per day.
        var series: [(symbol: String, rebased: [Double], weight: Double)] = []
        for (symbol, candles) in holdingsCandles {
            let w = weights[symbol] ?? 0
            guard w > 0, let first = candles.first else { continue }
            let rebased = candles.map { $0.c / first.c }
            series.append((symbol, rebased, w))
        }
        guard !series.isEmpty else { return nil }
        let minLen = series.map(\.rebased.count).min() ?? 0
        guard minLen >= 5 else { return nil }
        let totalW = series.map(\.weight).reduce(0, +)
        guard totalW > 0 else { return nil }
        var portfolioValue: [Double] = []
        for i in 0..<minLen {
            let v = series.reduce(0.0) { acc, entry in
                acc + entry.rebased[i] * (entry.weight / totalW)
            }
            portfolioValue.append(v)
        }
        var peak = portfolioValue[0]
        var maxDD = 0.0
        for v in portfolioValue {
            if v > peak { peak = v }
            let dd = (peak - v) / peak
            if dd > maxDD { maxDD = dd }
        }
        return maxDD
    }

    // MARK: - Stats helpers

    /// Daily simple returns from a candle series (close-to-close).
    static func dailyReturns(_ candles: [Candle]) -> [Double] {
        guard candles.count >= 2 else { return [] }
        var r: [Double] = []
        for i in 1..<candles.count {
            let prev = candles[i - 1].c
            guard prev != 0 else { continue }
            r.append((candles[i].c - prev) / prev)
        }
        return r
    }

    static func mean(_ xs: [Double]) -> Double {
        guard !xs.isEmpty else { return 0 }
        return xs.reduce(0, +) / Double(xs.count)
    }

    static func variance(_ xs: [Double]) -> Double {
        let m = mean(xs)
        return xs.map { pow($0 - m, 2) }.reduce(0, +) / Double(max(xs.count - 1, 1))
    }

    static func std(_ xs: [Double]) -> Double { sqrt(variance(xs)) }

    /// Sample covariance of two equal-length return series.
    static func covariance(_ a: [Double], _ b: [Double]) -> Double {
        let n = min(a.count, b.count)
        guard n > 1 else { return 0 }
        let ma = mean(a), mb = mean(b)
        var s = 0.0
        for i in 0..<n { s += (a[i] - ma) * (b[i] - mb) }
        return s / Double(n - 1)
    }
}
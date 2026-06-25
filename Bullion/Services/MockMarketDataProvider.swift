import Foundation

/// Mock provider returning deterministic fake data so the full UI is
/// navigable without network calls. Mimics realistic price action,
/// stats, candles, and news.
final class MockMarketDataProvider: MarketDataProvider, @unchecked Sendable {

    let displayName = "Mock Data"
    let supportsEquities = true
    let supportsFutures = true
    let futuresAreRealTime = false  // honest: mock is not real-time

    // Deterministic per-symbol price base + volatility.
    private let seedPrices: [String: Double] = [
        "SPY":  543.21, "QQQ":  478.65, "DIA":  391.40,
        "AAPL": 214.32, "MSFT": 428.90, "NVDA": 124.55, "TSLA": 248.50,
        "AMZN": 186.43, "GOOGL": 175.12, "META": 498.77, "AMD": 162.34,
        "ES":   5430.25, "NQ":  19210.50, "CL":   78.42, "GC":  2348.60,
        "BTC-USD": 67250.00
    ]

    private let instruments: [Instrument] = [
        // Indices / ETFs
        Instrument(symbol: "SPY", name: "SPDR S&P 500 ETF Trust", type: .etf, exchange: "NYSE Arca"),
        Instrument(symbol: "QQQ", name: "Invesco QQQ Trust", type: .etf, exchange: "NASDAQ"),
        Instrument(symbol: "DIA", name: "SPDR Dow Jones Industrial Average ETF", type: .etf, exchange: "NYSE"),
        // Stocks
        Instrument(symbol: "AAPL", name: "Apple Inc.", type: .stock, exchange: "NASDAQ"),
        Instrument(symbol: "MSFT", name: "Microsoft Corporation", type: .stock, exchange: "NASDAQ"),
        Instrument(symbol: "NVDA", name: "NVIDIA Corporation", type: .stock, exchange: "NASDAQ"),
        Instrument(symbol: "TSLA", name: "Tesla, Inc.", type: .stock, exchange: "NASDAQ"),
        Instrument(symbol: "AMZN", name: "Amazon.com, Inc.", type: .stock, exchange: "NASDAQ"),
        Instrument(symbol: "GOOGL", name: "Alphabet Inc. Class A", type: .stock, exchange: "NASDAQ"),
        Instrument(symbol: "META", name: "Meta Platforms, Inc.", type: .stock, exchange: "NASDAQ"),
        Instrument(symbol: "AMD", name: "Advanced Micro Devices, Inc.", type: .stock, exchange: "NASDAQ"),
        // Futures
        Instrument(symbol: "ES", name: "E-mini S&P 500 Futures", type: .future, exchange: "CME", underlying: "SPY"),
        Instrument(symbol: "NQ", name: "E-mini Nasdaq 100 Futures", type: .future, exchange: "CME", underlying: "QQQ"),
        Instrument(symbol: "CL", name: "Crude Oil WTI Futures", type: .future, exchange: "NYMEX", underlying: "WTI"),
        Instrument(symbol: "GC", name: "Gold Futures", type: .future, exchange: "COMEX", underlying: "XAU"),
        // Crypto (as an extra searchable)
        Instrument(symbol: "BTC-USD", name: "Bitcoin / U.S. Dollar", type: .index, exchange: "Coinbase"),
    ]

    private let headlines = [
        "Markets rally on cooling inflation data",
        "Fed signals patience as rate-cut bets ease",
        "Tech earnings beat expectations, lifting indices",
        "Oil slips on demand concerns; gold steadies",
        "Semiconductor shares surge on AI demand outlook",
        "Bond yields tick higher ahead of payroll report",
        "Dollar firms as traders pare June cut odds",
        "Energy sector leads broad-market gains",
    ]

    func search(_ query: String) async throws -> [Instrument] {
        let q = query.uppercased()
        guard !q.isEmpty else { return [] }
        try await Task.sleep(for: .milliseconds(180))  // simulate latency
        return instruments.filter {
            $0.symbol.uppercased().contains(q) || $0.name.uppercased().contains(q)
        }
    }

    func quote(_ symbol: String) async throws -> Quote {
        try await Task.sleep(for: .milliseconds(120))
        let base = seedPrices[symbol] ?? 100.0
        let jitter = deterministicJitter(symbol: symbol, amplitude: 0.012)
        let last = base * (1 + jitter)
        let prevClose = base * (1 - jitter * 0.4)
        let open = base * (1 - jitter * 0.1)
        return Quote(
            symbol: symbol,
            last: last,
            open: open,
            previousClose: prevClose,
            dayLow: min(last, prevClose) * 0.995,
            dayHigh: max(last, prevClose) * 1.005,
            volume: Double(deterministicInt(symbol: symbol, max: 50_000_000)),
            timestamp: Date(),
            isDelayed: false
        )
    }

    func stats(_ symbol: String) async throws -> KeyStats {
        try await Task.sleep(for: .milliseconds(200))
        guard let instrument = instruments.first(where: { $0.symbol == symbol }) else {
            return KeyStats()
        }
        let base = seedPrices[symbol] ?? 100.0
        switch instrument.type {
        case .stock, .etf:
            return KeyStats(
                open: base * 0.998,
                previousClose: base * 0.996,
                dayLow: base * 0.992,
                dayHigh: base * 1.004,
                week52Low: base * 0.72,
                week52High: base * 1.18,
                volume: Double(deterministicInt(symbol: symbol, max: 50_000_000)),
                avgVolume: Double(deterministicInt(symbol: symbol, max: 45_000_000)),
                marketCap: base * Double(deterministicInt(symbol: symbol, max: 16_000_000_000)),
                peRatio: 18 + deterministicJitter(symbol: symbol, amplitude: 10),
                eps: base * 0.06 * (1 + deterministicJitter(symbol: symbol, amplitude: 0.3)),
                dividendYield: abs(deterministicJitter(symbol: symbol, amplitude: 2)),
                beta: 1.0 + deterministicJitter(symbol: symbol, amplitude: 0.5),
                sharesOutstanding: Double(deterministicInt(symbol: symbol, max: 20_000_000_000)),
                nextEarningsDate: "2026-07-23",
                sector: sectorFor(symbol),
                industry: industryFor(symbol)
            )
        case .future:
            return KeyStats(
                open: base * 0.999,
                previousClose: base * 0.997,
                dayLow: base * 0.994,
                dayHigh: base * 1.003,
                volume: Double(deterministicInt(symbol: symbol, max: 1_200_000)),
                avgVolume: Double(deterministicInt(symbol: symbol, max: 1_000_000)),
                openInterest: Double(deterministicInt(symbol: symbol, max: 2_500_000)),
                contractSize: contractSizeFor(symbol),
                tickSize: tickSizeFor(symbol),
                expiry: "2026-09-18",
                settlement: base * 1.001,
                continuous: false
            )
        case .index:
            return KeyStats(
                open: base * 0.999,
                previousClose: base * 0.998,
                dayLow: base * 0.995,
                dayHigh: base * 1.002,
                week52Low: base * 0.60,
                week52High: base * 1.25
            )
        }
    }

    func candles(_ symbol: String, range: ChartRange) async throws -> [Candle] {
        try await Task.sleep(for: .milliseconds(250))
        let base = seedPrices[symbol] ?? 100.0
        let count = candleCount(for: range)
        let stepInterval = interval(for: range)
        let now = Date()
        var candles: [Candle] = []
        var price = base * 0.9
        let drift = (base - price) / Double(count)  // gentle uptrend
        let amplitude = 0.015
        for i in 0..<count {
            let t = now.addingTimeInterval(-Double(count - 1 - i) * stepInterval)
            let noise = deterministicJitter(symbol: "\(symbol)-\(i)", amplitude: amplitude)
            let o = price
            price = min(price + drift, base) * (1 + noise)
            price = max(price, base * 0.5)
            let h = max(o, price) * (1 + abs(noise) * 0.5)
            let l = min(o, price) * (1 - abs(noise) * 0.5)
            candles.append(Candle(t: t, o: o, h: h, l: l, c: price,
                                  v: Double(deterministicInt(symbol: "\(symbol)-\(i)", max: 1_000_000))))
        }
        return candles
    }

    func news(_ symbol: String) async throws -> [NewsItem] {
        try await Task.sleep(for: .milliseconds(200))
        var items: [NewsItem] = []
        for (i, headline) in headlines.prefix(5).enumerated() {
            let id = "\(symbol)-\(i)"
            items.append(NewsItem(
                id: id,
                headline: "\(headline) — \(symbol)",
                summary: "Summary excerpt for \(symbol). This is mock content for preview purposes.",
                source: ["Bloomberg", "Reuters", "CNBC", "WSJ", "MarketWatch"][i % 5],
                url: URL(string: "https://example.com/news/\(deterministicInt(symbol: id, max: 1_000_000))")!,
                publishedAt: Date().addingTimeInterval(-Double(i * 3600)),
                relatedSymbols: [symbol]
            ))
        }
        return items
    }

    func headlineInstruments() async throws -> [Instrument] {
        ["SPY", "QQQ", "DIA", "ES", "NQ", "CL", "GC"]
            .compactMap { sym in instruments.first(where: { $0.symbol == sym }) }
    }

    func defaultActiveSymbols() -> [String] {
        ["AAPL", "NVDA", "TSLA", "AMD", "AMZN", "META", "MSFT", "GOOGL"]
    }

    // MARK: - Deterministic pseudo-randomness

    private func deterministicJitter(symbol: String, amplitude: Double) -> Double {
        let hash = abs(symbol.hashValue)
        let normalized = Double(hash % 10000) / 10000.0  // 0..<1
        return (normalized - 0.5) * 2 * amplitude
    }

    private func deterministicInt(symbol: String, max upper: Int) -> Int {
        abs(symbol.hashValue) % upper
    }

    private func candleCount(for range: ChartRange) -> Int {
        switch range {
        case .oneD:   return 78    // 5-min bars over ~6.5h
        case .oneW:   return 35
        case .oneM:   return 22
        case .threeM: return 66
        case .oneY:   return 252
        case .fiveY:  return 260
        case .max:    return 520
        }
    }

    private func interval(for range: ChartRange) -> TimeInterval {
        switch range {
        case .oneD:   return 300        // 5 min
        case .oneW:   return 3600 * 2   // 2h
        case .oneM:   return 86_400     // 1 day
        case .threeM: return 86_400
        case .oneY:   return 86_400
        case .fiveY:  return 86_400 * 5
        case .max:    return 86_400 * 5
        }
    }

    private func sectorFor(_ symbol: String) -> String {
        switch symbol {
        case "AAPL", "NVDA", "MSFT", "AMD", "GOOGL", "META": return "Technology"
        case "TSLA": return "Consumer Discretionary"
        case "AMZN": return "Consumer Discretionary"
        default: return "Financials"
        }
    }

    private func industryFor(_ symbol: String) -> String {
        switch symbol {
        case "AAPL": return "Consumer Electronics"
        case "NVDA", "AMD": return "Semiconductors"
        case "MSFT", "GOOGL", "META": return "Software"
        case "TSLA": return "Auto Manufacturers"
        case "AMZN": return "Internet Retail"
        default: return "Diversified Financials"
        }
    }

    private func contractSizeFor(_ symbol: String) -> Double {
        switch symbol {
        case "ES": return 50
        case "NQ": return 20
        case "CL": return 1000
        case "GC": return 100
        default: return 1
        }
    }

    private func tickSizeFor(_ symbol: String) -> Double {
        switch symbol {
        case "ES": return 0.25
        case "NQ": return 0.25
        case "CL": return 0.01
        case "GC": return 0.10
        default: return 0.01
        }
    }
}
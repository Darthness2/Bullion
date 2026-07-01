import Foundation

/// Yahoo Finance MarketDataProvider — no API key, no rate limit.
/// Uses the Yahoo Finance v8 chart API for quotes and candles,
/// and the v1 search API for instrument search and news.
///
/// Yahoo provides:
/// - Real-time quotes via chart meta (price, day H/L, volume, 52w H/L)
/// - Intraday candles (1m–90m) and daily/weekly/monthly candles
/// - Search across stocks, ETFs, futures, crypto
/// - News via the search endpoint
/// - Futures (ES=F, GC=F, CL=F) and crypto (BTC-USD)
///
/// No API key required. No known rate limit (tested 10 rapid = all 200).
final class YahooFinanceProvider: MarketDataProvider, @unchecked Sendable {

    let displayName = "Yahoo Finance"
    let supportsEquities = true
    let supportsFutures = true
    let futuresAreRealTime = true

    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"]
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
    }

    // MARK: - Search

    func search(_ query: String) async throws -> [Instrument] {
        guard !query.isEmpty else { return [] }
        let url = URL(string: "https://query1.finance.yahoo.com/v1/finance/search?q=\(percentEncoded(query))&quotesCount=20&newsCount=0")!
        struct SearchResponse: Codable {
            struct Quote: Codable {
                let symbol: String
                let shortname: String?
                let longname: String?
                let quoteType: String?
                let exchange: String?
            }
            let quotes: [Quote]?
        }
        let response: SearchResponse = try await fetch(url)
        return (response.quotes ?? []).map { q in
            Instrument(
                symbol: q.symbol,
                name: q.longname ?? q.shortname ?? q.symbol,
                type: mapType(q.quoteType),
                exchange: q.exchange
            )
        }
    }

    // MARK: - Quote

    func quote(_ symbol: String) async throws -> Quote {
        // Use a 1d chart so `chartPreviousClose` is the prior *session* close
        // (yesterday), not the close from ~5 trading days ago. Day change is
        // derived from `previousClose` in `Quote`, so this is what makes the
        // "today's move" pill correct. `regularMarketPreviousClose` /
        // `regularMarketOpen` are preferred when Yahoo exposes them.
        let chart = try await fetchChart(symbol: symbol, interval: "1d", range: "1d")
        let meta = chart.meta
        let last = meta.regularMarketPrice
        guard let last, last > 0 else {
            throw APIClient.APIError.invalidResponse
        }
        let timestamp = meta.regularMarketTime.map {
            Date(timeIntervalSince1970: TimeInterval($0))
        } ?? Date()
        return Quote(
            symbol: symbol,
            last: last,
            open: meta.regularMarketOpen ?? chart.candles.first?.o,
            previousClose: meta.regularMarketPreviousClose ?? meta.chartPreviousClose,
            dayLow: meta.regularMarketDayLow,
            dayHigh: meta.regularMarketDayHigh,
            volume: meta.regularMarketVolume.map(Double.init),
            timestamp: timestamp,
            isDelayed: false
        )
    }

    // MARK: - Stats

    func stats(_ symbol: String) async throws -> KeyStats {
        let chart = try await fetchChart(symbol: symbol, interval: "1d", range: "1y")
        let meta = chart.meta
        return KeyStats(
            open: nil,
            previousClose: meta.chartPreviousClose,
            dayLow: meta.regularMarketDayLow,
            dayHigh: meta.regularMarketDayHigh,
            week52Low: meta.fiftyTwoWeekLow,
            week52High: meta.fiftyTwoWeekHigh,
            volume: meta.regularMarketVolume.map(Double.init),
            avgVolume: nil,
            marketCap: nil,
            peRatio: nil,
            eps: nil,
            dividendYield: nil,
            beta: nil,
            sharesOutstanding: nil,
            nextEarningsDate: nil,
            sector: nil,
            industry: nil,
            openInterest: nil,
            contractSize: nil,
            tickSize: nil,
            expiry: nil,
            settlement: nil
        )
    }

    // MARK: - Candles

    func candles(_ symbol: String, range: ChartRange) async throws -> [Candle] {
        let (interval, yfRange) = rangeParams(range)
        let chart = try await fetchChart(symbol: symbol, interval: interval, range: yfRange)
        return chart.candles
    }

    // MARK: - News

    func news(_ symbol: String) async throws -> [NewsItem] {
        let url = URL(string: "https://query1.finance.yahoo.com/v1/finance/search?q=\(percentEncoded(symbol))&quotesCount=0&newsCount=10")!
        struct NewsResponse: Codable {
            struct Article: Codable {
                let uuid: String?
                let title: String
                let publisher: String?
                let link: String?
                let providerPublishTime: Int?
                let relatedTickers: [String]?
            }
            let news: [Article]?
        }
        let response: NewsResponse = try await fetch(url)
        return (response.news ?? []).compactMap { a in
            guard let urlString = a.link, let url = URL(string: urlString) else { return nil }
            let date = a.providerPublishTime.map { Date(timeIntervalSince1970: TimeInterval($0)) } ?? Date()
            // Stable across launches: prefer Yahoo's uuid, fall back to the link.
            let id = a.uuid ?? urlString
            return NewsItem(
                id: id,
                headline: a.title,
                summary: nil,
                source: a.publisher ?? "Yahoo Finance",
                url: url,
                publishedAt: date,
                relatedSymbols: a.relatedTickers
            )
        }
    }

    // MARK: - Headlines / defaults

    func headlineInstruments() async throws -> [Instrument] {
        return [
            Instrument(symbol: "SPY", name: "SPDR S&P 500 ETF Trust", type: .etf, exchange: "NYSE Arca"),
            Instrument(symbol: "QQQ", name: "Invesco QQQ Trust", type: .etf, exchange: "NASDAQ"),
            Instrument(symbol: "DIA", name: "SPDR Dow Jones ETF", type: .etf, exchange: "NYSE"),
            Instrument(symbol: "ES=F", name: "E-Mini S&P 500 Futures", type: .future, exchange: "CME"),
            Instrument(symbol: "NQ=F", name: "E-Mini Nasdaq 100 Futures", type: .future, exchange: "CME"),
            Instrument(symbol: "CL=F", name: "Crude Oil WTI Futures", type: .future, exchange: "NYMEX"),
            Instrument(symbol: "GC=F", name: "Gold Futures", type: .future, exchange: "COMEX"),
        ]
    }

    /// Curated popular stocks with correct exchanges (not "Most Active" —
    /// Yahoo's free API doesn't expose true activity, so we label this
    /// honestly as a curated list).
    func defaultActiveSymbols() -> [String] {
        popularStocks().map(\.symbol)
    }

    /// Curated popular stocks as full Instruments with correct exchanges.
    func popularStocks() -> [Instrument] {
        [
            Instrument(symbol: "AAPL",  name: "Apple Inc.",              type: .stock, exchange: "NASDAQ"),
            Instrument(symbol: "NVDA",  name: "NVIDIA Corporation",      type: .stock, exchange: "NASDAQ"),
            Instrument(symbol: "TSLA",  name: "Tesla, Inc.",             type: .stock, exchange: "NASDAQ"),
            Instrument(symbol: "AMD",   name: "Advanced Micro Devices",  type: .stock, exchange: "NASDAQ"),
            Instrument(symbol: "AMZN",  name: "Amazon.com, Inc.",        type: .stock, exchange: "NASDAQ"),
            Instrument(symbol: "META",  name: "Meta Platforms, Inc.",    type: .stock, exchange: "NASDAQ"),
            Instrument(symbol: "MSFT",  name: "Microsoft Corporation",   type: .stock, exchange: "NASDAQ"),
            Instrument(symbol: "GOOGL", name: "Alphabet Inc.",           type: .stock, exchange: "NASDAQ"),
        ]
    }

    /// Curated popular futures for the Futures segment.
    func popularFutures() -> [Instrument] {
        [
            Instrument(symbol: "ES=F", name: "E-Mini S&P 500 Futures",    type: .future, exchange: "CME"),
            Instrument(symbol: "NQ=F", name: "E-Mini Nasdaq 100 Futures", type: .future, exchange: "CME"),
            Instrument(symbol: "CL=F", name: "Crude Oil WTI Futures",     type: .future, exchange: "NYMEX"),
            Instrument(symbol: "GC=F", name: "Gold Futures",              type: .future, exchange: "COMEX"),
            Instrument(symbol: "SI=F", name: "Silver Futures",             type: .future, exchange: "COMEX"),
            Instrument(symbol: "ZW=F", name: "Wheat Futures",             type: .future, exchange: "CBOT"),
            Instrument(symbol: "ZC=F", name: "Corn Futures",              type: .future, exchange: "CBOT"),
            Instrument(symbol: "HG=F", name: "Copper Futures",            type: .future, exchange: "COMEX"),
        ]
    }

    /// Curated popular futures for the Futures segment.
    var futuresSymbols: [String] {
        popularFutures().map(\.symbol)
    }

    // MARK: - Private helpers

    private func percentEncoded(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
    }

    private func mapType(_ quoteType: String?) -> InstrumentType {
        guard let quoteType else { return .stock }
        switch quoteType.uppercased() {
        case "EQUITY":      return .stock
        case "ETF":         return .etf
        case "FUTURE":      return .future
        case "INDEX":       return .index
        case "MUTUALFUND":  return .etf
        case "CRYPTOCURRENCY": return .index
        default:            return .stock
        }
    }

    private func rangeParams(_ range: ChartRange) -> (String, String) {
        switch range {
        case .oneD:   return ("5m", "1d")
        case .oneW:   return ("15m", "5d")
        case .oneM:   return ("1h", "1mo")
        case .threeM: return ("1d", "3mo")
        case .oneY:   return ("1d", "1y")
        case .fiveY:  return ("1wk", "5y")
        case .max:    return ("1mo", "max")
        }
    }

    // MARK: - Chart fetching

    private struct ChartResult {
        let meta: ChartMeta
        let candles: [Candle]
    }

    private struct ChartMeta {
        let symbol: String
        let longName: String?
        let shortName: String?
        let instrumentType: String?
        let fullExchangeName: String?
        let regularMarketPrice: Double?
        let regularMarketTime: Int?
        let regularMarketDayHigh: Double?
        let regularMarketDayLow: Double?
        let regularMarketVolume: Int?
        let regularMarketOpen: Double?
        let regularMarketPreviousClose: Double?
        let chartPreviousClose: Double?
        let fiftyTwoWeekHigh: Double?
        let fiftyTwoWeekLow: Double?
        let currency: String?
    }

    private func fetchChart(symbol: String, interval: String, range: String) async throws -> ChartResult {
        let encoded = percentEncoded(symbol)
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)?interval=\(interval)&range=\(range)")!
        struct ChartResponse: Codable {
            struct Chart: Codable {
                struct Result: Codable {
                    struct Meta: Codable {
                        let symbol: String
                        let longName: String?
                        let shortName: String?
                        let instrumentType: String?
                        let fullExchangeName: String?
                        let regularMarketPrice: Double?
                        let regularMarketTime: Int?
                        let regularMarketDayHigh: Double?
                        let regularMarketDayLow: Double?
                        let regularMarketVolume: Int?
                        let regularMarketOpen: Double?
                        let regularMarketPreviousClose: Double?
                        let chartPreviousClose: Double?
                        let fiftyTwoWeekHigh: Double?
                        let fiftyTwoWeekLow: Double?
                        let currency: String?
                    }
                    struct Quote: Codable {
                        let open: [Double?]
                        let high: [Double?]
                        let low: [Double?]
                        let close: [Double?]
                        let volume: [Double?]
                    }
                    let meta: Meta
                    let timestamp: [Int]?
                    let indicators: Indicators?
                    struct Indicators: Codable {
                        let quote: [Quote]?
                    }
                }
                let result: [Result]?
                let error: ErrorInfo?
            }
            struct ErrorInfo: Codable {
                let code: String
                let description: String
            }
            let chart: Chart
        }

        let response: ChartResponse = try await fetch(url)

        if let error = response.chart.error {
            throw APIClient.APIError.http(status: 400, body: error.description)
        }

        guard let result = response.chart.result?.first else {
            throw APIClient.APIError.invalidResponse
        }

        let meta = ChartMeta(
            symbol: result.meta.symbol,
            longName: result.meta.longName,
            shortName: result.meta.shortName,
            instrumentType: result.meta.instrumentType,
            fullExchangeName: result.meta.fullExchangeName,
            regularMarketPrice: result.meta.regularMarketPrice,
            regularMarketTime: result.meta.regularMarketTime,
            regularMarketDayHigh: result.meta.regularMarketDayHigh,
            regularMarketDayLow: result.meta.regularMarketDayLow,
            regularMarketVolume: result.meta.regularMarketVolume,
            regularMarketOpen: result.meta.regularMarketOpen,
            regularMarketPreviousClose: result.meta.regularMarketPreviousClose,
            chartPreviousClose: result.meta.chartPreviousClose,
            fiftyTwoWeekHigh: result.meta.fiftyTwoWeekHigh,
            fiftyTwoWeekLow: result.meta.fiftyTwoWeekLow,
            currency: result.meta.currency
        )

        let timestamps = result.timestamp ?? []
        let quoteData = result.indicators?.quote?.first
        let opens = quoteData?.open ?? []
        let highs = quoteData?.high ?? []
        let lows = quoteData?.low ?? []
        let closes = quoteData?.close ?? []
        let volumes = quoteData?.volume ?? []

        var candles: [Candle] = []
        for i in 0..<min(timestamps.count, opens.count, highs.count, lows.count, closes.count) {
            guard let o = opens[i], let h = highs[i], let l = lows[i], let c = closes[i] else {
                continue
            }
            let v = volumes.indices.contains(i) ? volumes[i] : nil
            candles.append(Candle(
                t: Date(timeIntervalSince1970: TimeInterval(timestamps[i])),
                o: o, h: h, l: l, c: c, v: v
            ))
        }

        return ChartResult(meta: meta, candles: candles)
    }

    // MARK: - HTTP

    private func fetch<T: Decodable>(_ url: URL) async throws -> T {
        // Yahoo's public endpoints intermittently throttle (401/429) and
        // occasionally 5xx. Retry those a couple of times with backoff before
        // surfacing the error; other statuses fail fast.
        let retriableStatuses: Set<Int> = [401, 429, 500, 502, 503, 504]
        let maxAttempts = 3
        var lastError: Error = APIClient.APIError.invalidResponse

        for attempt in 0..<maxAttempts {
            do {
                let (data, response) = try await session.data(from: url)
                guard let http = response as? HTTPURLResponse else {
                    throw APIClient.APIError.invalidResponse
                }
                guard (200..<300).contains(http.statusCode) else {
                    let body = String(data: data, encoding: .utf8) ?? "Unknown"
                    let error = APIClient.APIError.http(status: http.statusCode, body: body)
                    if retriableStatuses.contains(http.statusCode), attempt < maxAttempts - 1 {
                        lastError = error
                        try await backoff(attempt)
                        continue
                    }
                    throw error
                }
                do {
                    return try decoder.decode(T.self, from: data)
                } catch let e as DecodingError {
                    throw APIClient.APIError.decoding(e)
                }
            } catch let e as APIClient.APIError {
                throw e
            } catch {
                // Transport error (timeout, connection lost): retry, then give up.
                lastError = APIClient.APIError.network(error)
                if attempt < maxAttempts - 1 {
                    try await backoff(attempt)
                    continue
                }
                throw lastError
            }
        }
        throw lastError
    }

    /// Exponential backoff: ~0.4s, 0.8s, … with light jitter.
    private func backoff(_ attempt: Int) async throws {
        let base = 0.4 * pow(2.0, Double(attempt))
        let jitter = Double.random(in: 0...0.2)
        try await Task.sleep(nanoseconds: UInt64((base + jitter) * 1_000_000_000))
    }
}
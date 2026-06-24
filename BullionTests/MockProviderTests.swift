import Testing
import Foundation
@testable import Bullion

@Suite("MockMarketDataProvider")
struct MockProviderTests {
    let provider = MockMarketDataProvider()

    @Test("Capabilities are set")
    func capabilities() {
        #expect(provider.supportsEquities == true)
        #expect(provider.supportsFutures == true)
        #expect(provider.futuresAreRealTime == false)
    }

    @Test("Search returns matching instruments")
    func search() async throws {
        let results = try await provider.search("Apple")
        #expect(results.contains(where: { $0.symbol == "AAPL" }) == true)
    }

    @Test("Search with empty query returns empty")
    func searchEmpty() async throws {
        let results = try await provider.search("")
        #expect(results.isEmpty == true)
    }

    @Test("Quote returns a value with change")
    func quote() async throws {
        let q = try await provider.quote("AAPL")
        #expect(q.symbol == "AAPL")
        #expect(q.change != nil)
        #expect(q.changePercent != nil)
    }

    @Test("Stats for a stock include equities fields")
    func stockStats() async throws {
        let s = try await provider.stats("AAPL")
        #expect(s.marketCap != nil)
        #expect(s.peRatio != nil)
        #expect(s.sector != nil)
    }

    @Test("Stats for a future include futures fields")
    func futureStats() async throws {
        let s = try await provider.stats("ES")
        #expect(s.openInterest != nil)
        #expect(s.contractSize != nil)
        #expect(s.tickSize != nil)
        #expect(s.expiry != nil)
    }

    @Test("Candles are sorted ascending by time")
    func candlesAscending() async throws {
        let candles = try await provider.candles("SPY", range: .oneM)
        #expect(candles.count > 0)
        for i in 1..<candles.count {
            #expect(candles[i].t > candles[i - 1].t)
        }
    }

    @Test("News returns items with URLs")
    func news() async throws {
        let news = try await provider.news("AAPL")
        #expect(news.count > 0)
        #expect(news.allSatisfy { $0.url != nil } == true)
    }

    @Test("Headline instruments include ETFs and futures")
    func headlines() async throws {
        let instruments = try await provider.headlineInstruments()
        let symbols = instruments.map(\.symbol)
        #expect(symbols.contains("SPY") == true)
        #expect(symbols.contains("ES") == true)
        #expect(symbols.contains("GC") == true)
    }

    @Test("Default active symbols are non-empty")
    func defaultActive() {
        let symbols = provider.defaultActiveSymbols()
        #expect(symbols.isEmpty == false)
    }
}
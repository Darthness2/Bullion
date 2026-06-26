import Testing
import Foundation
@testable import Bullion

@Suite("Quote change math")
struct QuoteMathTests {

    private func makeQuote(last: Double, prevClose: Double?) -> Quote {
        Quote(symbol: "TEST", last: last, open: nil, previousClose: prevClose,
              dayLow: nil, dayHigh: nil, volume: nil, timestamp: Date(), isDelayed: false)
    }

    @Test("Change is last minus previousClose")
    func changeAbsolute() {
        let q = makeQuote(last: 105, prevClose: 100)
        #expect(q.change == 5)
    }

    @Test("Change is nil when previousClose is nil")
    func changeNil() {
        let q = makeQuote(last: 105, prevClose: nil)
        #expect(q.change == nil)
        #expect(q.changePercent == nil)
    }

    @Test("ChangePercent computes correctly")
    func changePercent() {
        let q = makeQuote(last: 110, prevClose: 100)
        #expect(q.changePercent == 10.0)
    }

    @Test("ChangePercent is nil when previousClose is zero (avoid divide-by-zero)")
    func changePercentZeroPrevClose() {
        let q = makeQuote(last: 105, prevClose: 0)
        #expect(q.changePercent == nil)
    }

    @Test("Negative change is negative")
    func negativeChange() {
        let q = makeQuote(last: 95, prevClose: 100)
        #expect(q.change == -5)
        #expect(q.changePercent == -5.0)
    }

    @Test("Holding unrealizedPL computes correctly")
    func holdingPL() {
        let h = Holding(symbol: "AAPL", name: "Apple", quantity: 100, avgCost: 150,
                        marketValue: 16_000, dayChange: 200, dayChangePercent: 1.25)
        #expect(h.unrealizedPL == 1_000)  // 16000 - 150*100
    }

    @Test("Holding unrealizedPLPercent computes correctly")
    func holdingPLPercent() {
        let h = Holding(symbol: "AAPL", name: "Apple", quantity: 100, avgCost: 150,
                        marketValue: 16_000, dayChange: 200, dayChangePercent: 1.25)
        #expect(h.unrealizedPLPercent == 6.666666666666667)
    }

    @Test("Holding unrealizedPL is nil when avgCost is nil")
    func holdingPLNil() {
        let h = Holding(symbol: "AAPL", name: "Apple", quantity: 100, avgCost: nil,
                        marketValue: 16_000, dayChange: 200, dayChangePercent: 1.25)
        #expect(h.unrealizedPL == nil)
        #expect(h.unrealizedPLPercent == nil)
    }

    // MARK: - Day-change enrichment (Yahoo quote → holding dayChange)

    @Test("Enrichment: day change = last - previousClose")
    func enrichmentDayChange() {
        // A holding with no day change from the backend…
        var h = Holding(symbol: "AAPL", name: "Apple", quantity: 100, avgCost: 150,
                        marketValue: 16_000, dayChange: nil, dayChangePercent: nil)
        // …enriched from a Yahoo quote where last=165, prevClose=160.
        let q = makeQuote(last: 165, prevClose: 160)
        let change = q.last - (q.previousClose ?? 0)
        h.dayChange = change
        h.dayChangePercent = q.previousClose == 0 ? nil : (change / q.previousClose! * 100)
        #expect(h.dayChange == 5)
        #expect(h.dayChangePercent == 3.125)  // 5/160*100
    }

    @Test("Enrichment: negative day change")
    func enrichmentNegativeDayChange() {
        var h = Holding(symbol: "TSLA", name: "Tesla", quantity: 60, avgCost: 220,
                        marketValue: 14_910, dayChange: nil, dayChangePercent: nil)
        let q = makeQuote(last: 248.5, prevClose: 252.0)
        let change = q.last - (q.previousClose ?? 0)
        h.dayChange = change
        h.dayChangePercent = (change / q.previousClose! * 100)
        #expect(h.dayChange == -3.5)
        #expect(h.dayChangePercent! < 0)
    }
}
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
}
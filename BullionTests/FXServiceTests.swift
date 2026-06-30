import Testing
import Foundation
@testable import Bullion

@Suite("FXService")
struct FXServiceTests {

    @Test("Same-currency conversion returns the amount unchanged")
    func sameCurrency() async {
        let fx = FXService()
        let out = await fx.convert(1234.56, from: "USD", to: "USD")
        #expect(out == 1234.56)
    }

    @Test("Case-insensitive currency codes")
    func caseInsensitive() async {
        let fx = FXService()
        let out = await fx.convert(100.0, from: "usd", to: "USD")
        #expect(out == 100.0)
    }

    @Test("Empty currency code returns the amount unchanged")
    func emptyCode() async {
        let fx = FXService()
        let out = await fx.convert(99.0, from: "", to: "USD")
        #expect(out == 99.0)
    }

    @Test("convertMany preserves length and same-currency passthrough")
    func convertManySameCurrency() async {
        let fx = FXService()
        let out = await fx.convertMany([10, 20, 30], from: "USD", to: "USD")
        #expect(out == [10, 20, 30])
    }

    @Test("rate for same currency is 1.0 without network")
    func rateSameCurrency() async {
        let fx = FXService()
        let r = await fx.rate(from: "EUR", to: "EUR")
        #expect(r == 1.0)
    }

    @Test("rate for empty code is 1.0 (safe fallback)")
    func rateEmpty() async {
        let fx = FXService()
        let r = await fx.rate(from: "", to: "USD")
        #expect(r == 1.0)
    }

    @Test("PortfolioViewModel.ConvertedAggregates holds totals")
    func convertedAggregatesStruct() {
        let a = PortfolioViewModel.ConvertedAggregates(
            totalValue: 100, totalDayChange: 5, totalUnrealizedPL: 20
        )
        #expect(a.totalValue == 100)
        #expect(a.totalDayChange == 5)
        #expect(a.totalUnrealizedPL == 20)
    }
}
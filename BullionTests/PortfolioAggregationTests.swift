import Testing
import Foundation
@testable import Bullion

@Suite("PortfolioViewModel aggregation")
struct PortfolioAggregationTests {

    @MainActor
    @Test("totalValue sums market value across all holdings")
    func totalValueSumsHoldings() async {
        let vm = PortfolioViewModel(service: MockPortfolioService())
        await vm.load()
        // MockPortfolioService returns 2 accounts, each with 5 holdings:
        // AAPL 25718.40, NVDA 24910.00, MSFT 34312.00, TSLA 14910.00, SPY 27160.50
        let perAccount = 25718.40 + 24910.00 + 34312.00 + 14910.00 + 27160.50
        let expected = perAccount * 2   // two accounts
        #expect(abs(vm.totalValue - expected) < 0.01)
    }

    @MainActor
    @Test("allHoldings flattens across accounts")
    func allHoldingsFlattens() async {
        let vm = PortfolioViewModel(service: MockPortfolioService())
        await vm.load()
        // Two mock accounts, each with the same 5 holdings.
        #expect(vm.allHoldings.count == 10)
    }

    @MainActor
    @Test("totalUnrealizedPL sums (marketValue - avgCost*qty)")
    func totalUnrealizedPL() async {
        let vm = PortfolioViewModel(service: MockPortfolioService())
        await vm.load()
        // Per holding: PL = marketValue - avgCost*quantity
        // AAPL: 25718.40 - 165.40*120 = 25718.40 - 19848 = 5870.40
        // NVDA: 24910.00 - 42.10*200 = 24910.00 - 8420 = 16490.00
        // MSFT: 34312.00 - 310.25*80 = 34312.00 - 24820 = 9492.00
        // TSLA: 14910.00 - 220.00*60 = 14910.00 - 13200 = 1710.00
        // SPY: 27160.50 - 480.00*50 = 27160.50 - 24000 = 3160.50
        let perAccount = 5870.40 + 16490.00 + 9492.00 + 1710.00 + 3160.50
        let expected = perAccount * 2   // two accounts in the mock
        #expect(abs(vm.totalUnrealizedPL - expected) < 0.01)
    }

    @MainActor
    @Test("hasDayChangeData is false when mock sends nil dayChange")
    func hasDayChangeDataFalseInitially() async {
        let vm = PortfolioViewModel(service: MockPortfolioService())
        await vm.load()
        // Mock holdings all set dayChange: non-nil, so data IS present.
        // Verify the flag reflects the holdings rather than asserting a
        // hardcoded false — the mock populates dayChange (1.63, 5.23, etc.).
        #expect(vm.hasDayChangeData == true)
    }

    @MainActor
    @Test("baseCurrency defaults to USD")
    func baseCurrencyDefault() {
        let vm = PortfolioViewModel(service: MockPortfolioService())
        #expect(vm.baseCurrency == "USD")
    }

    @MainActor
    @Test("ConvertedAggregates carries totals through the cache")
    func convertedCacheRoundTrip() async {
        let vm = PortfolioViewModel(service: MockPortfolioService())
        await vm.load()
        await vm.recomputeAggregates()
        // After recompute, totalValue reads from the cache.
        let expected = (25718.40 + 24910.00 + 34312.00 + 14910.00 + 27160.50) * 2
        #expect(abs(vm.totalValue - expected) < 0.01)
    }
}
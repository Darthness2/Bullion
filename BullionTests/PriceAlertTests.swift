import Testing
import Foundation
@testable import Bullion

@Suite("PriceAlert")
struct PriceAlertTests {

    @Test("above direction: satisfied when price >= threshold")
    func aboveSatisfied() {
        let alert = PriceAlert(symbol: "AAPL", name: "Apple", direction: .above, threshold: 200)
        #expect(alert.satisfies(200))
        #expect(alert.satisfies(201))
        #expect(!alert.satisfies(199.99))
    }

    @Test("below direction: satisfied when price <= threshold")
    func belowSatisfied() {
        let alert = PriceAlert(symbol: "TSLA", name: "Tesla", direction: .below, threshold: 250)
        #expect(alert.satisfies(250))
        #expect(alert.satisfies(249))
        #expect(!alert.satisfies(250.01))
    }

    @Test("direction round-trips through directionRaw")
    func directionRoundTrip() {
        let alert = PriceAlert(symbol: "X", name: "X", direction: .above, threshold: 100)
        #expect(alert.direction == .above)
        alert.direction = .below
        #expect(alert.directionRaw == "below")
        #expect(alert.direction == .below)
    }

    @Test("new alert is not triggered")
    func newAlertNotTriggered() {
        let alert = PriceAlert(symbol: "X", name: "X", direction: .above, threshold: 100)
        #expect(alert.triggered == false)
    }

    @Test("AlertDirection display names")
    func directionDisplayNames() {
        #expect(AlertDirection.above.displayName == "rises above")
        #expect(AlertDirection.below.displayName == "falls below")
    }

    @Test("AlertDirection allCases has both")
    func allCases() {
        #expect(AlertDirection.allCases.count == 2)
        #expect(AlertDirection.allCases.contains(.above))
        #expect(AlertDirection.allCases.contains(.below))
    }
}
import Foundation

// Normalized by the service layer from Plaid responses.

struct BrokerageAccount: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let brokerage: String
    let totalValue: Double
    let currency: String
    let lastSynced: Date
    var connectionStatus: ConnectionStatus = .active
}

enum ConnectionStatus: String, Codable, Sendable {
    case active
    case needsReconnect
    case disabled
}

struct Holding: Identifiable, Codable, Hashable, Sendable {
    var id: String { symbol }
    let symbol: String
    let name: String
    let quantity: Double
    let avgCost: Double?
    let marketValue: Double
    /// Mutable so PortfolioViewModel can enrich day change from live Yahoo
    /// quotes when the backend sends null (it always does today).
    var dayChange: Double?
    var dayChangePercent: Double?

    var unrealizedPL: Double? {
        avgCost.map { marketValue - $0 * quantity }
    }

    var unrealizedPLPercent: Double? {
        guard let avgCost, avgCost != 0, let pl = unrealizedPL else { return nil }
        return pl / (avgCost * quantity) * 100
    }

    var allocation: Double?  // fraction of portfolio (0–1), filled by service
}

struct Transaction: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let symbol: String
    let type: String         // buy, sell, dividend, etc.
    let quantity: Double?
    let price: Double?
    let amount: Double?
    /// Optional: a missing/unparseable upstream date must render as "—",
    /// never silently become "now" (which would corrupt history & sorting).
    let date: Date?
    let description: String
}
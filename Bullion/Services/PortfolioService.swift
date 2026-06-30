import Foundation

/// Abstraction over portfolio data. The live implementation
/// (`DirectSnapTradeService`) talks to SnapTrade directly from the device —
/// no backend. `MockPortfolioService` backs previews and tests.
protocol PortfolioService: Sendable {
    /// Whether the user has linked any brokerage account.
    var isLinked: Bool { get async }
    /// List connected brokerage accounts with balances.
    func accounts() async throws -> [BrokerageAccount]
    /// Holdings + balances for a single account.
    func holdings(accountId: String) async throws -> [Holding]
    /// Recent transactions for an account.
    func transactions(accountId: String) async throws -> [Transaction]
    /// Generate a SnapTrade Connection Portal URL (opened via ASWebAuthenticationSession).
    func connectionPortalURL() async throws -> URL
    /// Open the Connection Portal in ASWebAuthenticationSession.
    func openConnectionPortal(url: URL) async throws
    /// Delete a brokerage connection (read-only app: no trading).
    func disconnect(accountId: String) async throws
    /// Trigger a re-sync.
    func refresh(accountId: String) async throws
}

// MARK: - Errors

enum PortfolioError: LocalizedError {
    case invalidPortalURL
    case invalidResponse
    case httpError(Int, String)
    case decodingError(Error)
    case authenticationCancelled
    case networkUnreachable
    /// Missing/invalid local configuration (e.g. SnapTrade keys not entered).
    /// The associated message is shown to the user verbatim.
    case notConfigured(String)

    var errorDescription: String? {
        switch self {
        case .invalidPortalURL:
            return "Invalid Connection Portal URL."
        case .invalidResponse:
            return "Invalid response from SnapTrade."
        case .httpError(let code, let detail):
            if code == 401 || code == 403 {
                return "SnapTrade rejected these credentials. Double-check your client ID and consumer key in Settings → Brokerage."
            }
            if code == 0 {
                return detail.isEmpty ? "The request could not be completed." : detail
            }
            return detail.isEmpty ? "SnapTrade error (HTTP \(code))." : "SnapTrade error (HTTP \(code)): \(detail)"
        case .decodingError(let error):
            return "Could not parse the SnapTrade response: \(error.localizedDescription)"
        case .authenticationCancelled:
            return "Authentication was cancelled."
        case .networkUnreachable:
            return "Can't reach SnapTrade. Check your internet connection and try again."
        case .notConfigured(let message):
            return message
        }
    }
}

// MARK: - Mock implementation (Milestone 1)

final class MockPortfolioService: PortfolioService, @unchecked Sendable {
    private var linked = false

    var isLinked: Bool { get async { linked } }

    func accounts() async throws -> [BrokerageAccount] {
        try await Task.sleep(for: .milliseconds(300))
        linked = true
        return [
            BrokerageAccount(id: "acc-1", name: "Margin Account", brokerage: "Alpaca",
                             totalValue: 152_340.55, currency: "USD",
                             lastSynced: Date().addingTimeInterval(-300)),
            BrokerageAccount(id: "acc-2", name: "Roth IRA", brokerage: "Fidelity",
                             totalValue: 48_210.10, currency: "USD",
                             lastSynced: Date().addingTimeInterval(-3600)),
        ]
    }

    func holdings(accountId: String) async throws -> [Holding] {
        try await Task.sleep(for: .milliseconds(300))
        // Deterministic mock holdings.
        return [
            Holding(symbol: "AAPL", name: "Apple Inc.", quantity: 120, avgCost: 165.40,
                    marketValue: 25_718.40, dayChange: 412.80, dayChangePercent: 1.63, allocation: 0.169),
            Holding(symbol: "NVDA", name: "NVIDIA Corporation", quantity: 200, avgCost: 42.10,
                    marketValue: 24_910.00, dayChange: 1_240.00, dayChangePercent: 5.23, allocation: 0.164),
            Holding(symbol: "MSFT", name: "Microsoft Corporation", quantity: 80, avgCost: 310.25,
                    marketValue: 34_312.00, dayChange: 680.00, dayChangePercent: 2.02, allocation: 0.225),
            Holding(symbol: "TSLA", name: "Tesla, Inc.", quantity: 60, avgCost: 220.00,
                    marketValue: 14_910.00, dayChange: -210.00, dayChangePercent: -1.39, allocation: 0.098),
            Holding(symbol: "SPY", name: "SPDR S&P 500 ETF", quantity: 50, avgCost: 480.00,
                    marketValue: 27_160.50, dayChange: 310.50, dayChangePercent: 1.16, allocation: 0.179),
        ]
    }

    func transactions(accountId: String) async throws -> [Transaction] {
        try await Task.sleep(for: .milliseconds(250))
        return [
            Transaction(id: "t1", symbol: "NVDA", type: "buy", quantity: 20, price: 118.30,
                        amount: -2_366.00, date: Date().addingTimeInterval(-86_400 * 3),
                        description: "Bought 20 NVDA @ 118.30"),
            Transaction(id: "t2", symbol: "AAPL", type: "dividend", quantity: nil, price: nil,
                        amount: 24.15, date: Date().addingTimeInterval(-86_400 * 7),
                        description: "Dividend payment AAPL"),
            Transaction(id: "t3", symbol: "TSLA", type: "sell", quantity: 10, price: 252.00,
                        amount: 2_520.00, date: Date().addingTimeInterval(-86_400 * 10),
                        description: "Sold 10 TSLA @ 252.00"),
        ]
    }

    func connectionPortalURL() async throws -> URL {
        try await Task.sleep(for: .milliseconds(400))
        return URL(string: "https://snaptrade.com/connection-portal?mock=true")!
    }

    func openConnectionPortal(url: URL) async throws {
        try await Task.sleep(for: .milliseconds(500))
    }

    func disconnect(accountId: String) async throws {
        try await Task.sleep(for: .milliseconds(200))
        linked = false
    }

    func refresh(accountId: String) async throws {
        try await Task.sleep(for: .milliseconds(300))
    }
}

import Foundation

@Observable
final class PortfolioViewModel {
    var accounts: LoadState<[BrokerageAccount]> = .idle
    var holdingsByAccount: [String: [Holding]] = [:]
    var transactionsByAccount: [String: [Transaction]] = [:]
    var isLinked = false
    var isConnecting = false
    var isRefreshing = false
    var connectError: String?

    private let service: any PortfolioService

    init(service: any PortfolioService) {
        self.service = service
    }

    @MainActor
    func load() async {
        accounts = .loading
        do {
            let linked = await service.isLinked
            self.isLinked = linked
            let accs = try await service.accounts()
            self.isLinked = !accs.isEmpty
            accounts = accs.isEmpty ? .empty : .loaded(accs)
            for acc in accs {
                async let holdings = service.holdings(accountId: acc.id)
                async let txns = service.transactions(accountId: acc.id)
                let (h, t) = await (try holdings, try txns)
                holdingsByAccount[acc.id] = h
                transactionsByAccount[acc.id] = t
            }
        } catch {
            accounts = .failed(error.localizedDescription)
        }
    }

    @MainActor
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        await load()
        isRefreshing = false
    }

    @MainActor
    func connect() async {
        guard !isConnecting else { return }
        isConnecting = true
        connectError = nil
        do {
            // Step 1: Get the Connection Portal URL from the backend.
            let portalURL = try await service.connectionPortalURL()
            // Step 2: Open it in ASWebAuthenticationSession (not WKWebView).
            // The backend registers/returns the user, generates the portal link,
            // and the user authenticates with their brokerage in the system browser.
            try await service.openConnectionPortal(url: portalURL)
            // Step 3: Refresh accounts — the new connection should now appear.
            await load()
        } catch let PortfolioError.authenticationCancelled {
            // User cancelled — not an error, just bail.
            connectError = nil
        } catch {
            connectError = error.localizedDescription
        }
        isConnecting = false
    }

    @MainActor
    func disconnect(accountId: String) async {
        do {
            try await service.disconnect(accountId: accountId)
            await load()
        } catch {
            accounts = .failed(error.localizedDescription)
        }
    }

    @MainActor
    func refreshConnection(accountId: String) async {
        do {
            try await service.refresh(accountId: accountId)
            await load()
        } catch {
            accounts = .failed(error.localizedDescription)
        }
    }

    // MARK: - Aggregates

    var totalValue: Double {
        var total: Double = 0
        for (_, holdings) in holdingsByAccount {
            for h in holdings {
                total += h.marketValue
            }
        }
        return total
    }

    var totalDayChange: Double {
        holdingsByAccount.values.flatMap { $0 }.compactMap { $0.dayChange }.reduce(0, +)
    }

    var totalDayChangePercent: Double {
        let totalValue = allHoldings.map(\.marketValue).reduce(0, +)
        guard totalValue > 0 else { return 0 }
        return totalDayChange / totalValue * 100
    }

    var totalUnrealizedPL: Double {
        holdingsByAccount.values.flatMap { $0 }.compactMap { $0.unrealizedPL }.reduce(0, +)
    }

    /// All holdings across accounts, for allocation donut.
    var allHoldings: [Holding] {
        holdingsByAccount.values.flatMap { $0 }
    }
}
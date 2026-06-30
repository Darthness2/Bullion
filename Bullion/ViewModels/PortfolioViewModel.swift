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
    var partialSync = false
    /// Base currency for portfolio totals. Defaults to USD; each account's
    /// holdings are converted to this currency before aggregation so a USD
    /// account + a EUR account sum correctly instead of naive-addition.
    var baseCurrency: String = "USD"
    /// Most recent FX rates snapshot used for the totals, so the hero can
    /// disclose "converted to USD" when multiple currencies are present.
    var hasMultiCurrency: Bool = false

    private let service: any PortfolioService
    private var refreshTask: Task<Void, Never>?
    /// Cached converted aggregates keyed by baseCurrency; invalidated on load.
    private var convertedCache: [String: ConvertedAggregates] = [:]

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
            // The direct SnapTrade /accounts call returns accounts in one shot,
            // so there's no per-connection partial-sync state to surface.
            self.partialSync = false
            // Whether any account is denominated in a currency other than the
            // base — used to disclose "converted to USD" on the portfolio hero.
            self.hasMultiCurrency = accs.contains { $0.currency.uppercased() != baseCurrency.uppercased() }
            accounts = accs.isEmpty ? .empty : .loaded(accs)

            // Reset so data for accounts removed/disconnected since last load
            // doesn't linger in the totals.
            var holdings: [String: [Holding]] = [:]
            var transactions: [String: [Transaction]] = [:]
            for acc in accs {
                // Per-account failure isolation: one failing account must not
                // wipe out the others' already-fetched data.
                async let holdingsTask = service.holdings(accountId: acc.id)
                async let txnsTask = service.transactions(accountId: acc.id)
                holdings[acc.id] = (try? await holdingsTask) ?? []
                transactions[acc.id] = (try? await txnsTask) ?? []
            }
            holdingsByAccount = holdings
            transactionsByAccount = transactions
            convertedCache = [:]   // invalidate; recompute on next aggregate read
            await recomputeAggregates()
        } catch {
            holdingsByAccount = [:]
            transactionsByAccount = [:]
            accounts = .failed(error.localizedDescription)
        }
    }

    /// Targeted sync of a single account's holdings + transactions — used by
    /// AccountDetailView so opening one account doesn't re-sync the whole
    /// portfolio and blank out others mid-display.
    @MainActor
    func syncAccount(_ accountId: String) async {
        async let holdingsTask = service.holdings(accountId: accountId)
        async let txnsTask = service.transactions(accountId: accountId)
        let h = (try? await holdingsTask) ?? holdingsByAccount[accountId] ?? []
        let t = (try? await txnsTask) ?? transactionsByAccount[accountId] ?? []
        holdingsByAccount[accountId] = h
        transactionsByAccount[accountId] = t
    }

    @MainActor
    func refresh() async {
        // Cancel any in-flight load so pull-to-refresh always re-runs.
        refreshTask?.cancel()
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            self.isRefreshing = true
            await self.load()
            self.isRefreshing = false
        }
        refreshTask = task
        await task.value
    }

    @MainActor
    func connect() async {
        guard !isConnecting else { return }
        isConnecting = true
        connectError = nil
        defer { isConnecting = false }
        do {
            let portalURL = try await service.connectionPortalURL()
            try await service.openConnectionPortal(url: portalURL)
            await load()
            Haptics.success()
        } catch let PortfolioError.authenticationCancelled {
            connectError = nil
        } catch {
            connectError = error.localizedDescription
        }
    }

    @MainActor
    func disconnect(accountId: String) async {
        do {
            try await service.disconnect(accountId: accountId)
            holdingsByAccount[accountId] = nil
            transactionsByAccount[accountId] = nil
            await load()
        } catch {
            accounts = .failed(error.localizedDescription)
        }
    }

    @MainActor
    func refreshConnection(accountId: String) async {
        do {
            try await service.refresh(accountId: accountId)
            await syncAccount(accountId)
            await load()
        } catch {
            accounts = .failed(error.localizedDescription)
        }
    }

    // MARK: - Aggregates

    /// Raw (native-currency) totals — sum without FX conversion. Used for
    /// single-currency portfolios and as a fallback when FX is unavailable.
    var totalValue: Double {
        if let c = convertedCache[baseCurrency] { return c.totalValue }
        return holdingsByAccount.values.flatMap { $0 }.map(\.marketValue).reduce(0, +)
    }

    var totalDayChange: Double {
        if let c = convertedCache[baseCurrency] { return c.totalDayChange }
        return holdingsByAccount.values.flatMap { $0 }.compactMap { $0.dayChange }.reduce(0, +)
    }

    /// Whether any holding reported a day change. When false, the day-change
    /// figures are "unavailable" (render "—"), not a genuine flat 0.
    var hasDayChangeData: Bool {
        allHoldings.contains { $0.dayChange != nil }
    }

    var totalDayChangePercent: Double {
        let totalValue = allHoldings.map(\.marketValue).reduce(0, +)
        guard totalValue > 0 else { return 0 }
        return totalDayChange / totalValue * 100
    }

    var totalUnrealizedPL: Double {
        if let c = convertedCache[baseCurrency] { return c.totalUnrealizedPL }
        return holdingsByAccount.values.flatMap { $0 }.compactMap { $0.unrealizedPL }.reduce(0, +)
    }

    /// All holdings across accounts.
    var allHoldings: [Holding] {
        holdingsByAccount.values.flatMap { $0 }
    }

    /// Snapshot of portfolio totals converted to a single base currency so
    /// multi-currency accounts sum correctly instead of naive-addition.
    struct ConvertedAggregates {
        let totalValue: Double
        let totalDayChange: Double
        let totalUnrealizedPL: Double
    }

    /// Recompute portfolio totals, converting each account's holdings to the
    /// base currency via live FX rates. Accounts whose currency equals the
    /// base are passed through unchanged. Call after `load()` / `enrichDayChange`
    /// and whenever the holdings map changes. Idempotent; safe to call repeatedly.
    @MainActor
    func recomputeAggregates() async {
        guard !holdingsByAccount.isEmpty, case let .loaded(accs) = accounts else { return }
        var totals = (value: 0.0, dayChange: 0.0, pl: 0.0)
        for acc in accs {
            guard let holdings = holdingsByAccount[acc.id] else { continue }
            let currency = acc.currency
            // Convert each holding's value/dayChange/unrealizedPL to base.
            for h in holdings {
                let value = await FXService.shared.convert(h.marketValue, from: currency, to: baseCurrency)
                totals.value += value
                if let dc = h.dayChange {
                    totals.dayChange += await FXService.shared.convert(dc, from: currency, to: baseCurrency)
                }
                if let pl = h.unrealizedPL {
                    totals.pl += await FXService.shared.convert(pl, from: currency, to: baseCurrency)
                }
            }
        }
        convertedCache[baseCurrency] = ConvertedAggregates(
            totalValue: totals.value, totalDayChange: totals.dayChange, totalUnrealizedPL: totals.pl
        )
    }

    // MARK: - Day-change enrichment (Phase 3)
    // The backend sends dayChange: null for every holding. Enrich with live
    // Yahoo quotes client-side so day change, top movers, and the day-change
    // pill become truthful. Only fills holdings where dayChange is nil.

    @MainActor
    func enrichDayChange(provider: any MarketDataProvider) async {
        let holdingsToEnrich = allHoldings.filter { $0.dayChange == nil }
        guard !holdingsToEnrich.isEmpty else { return }
        let symbols = Array(Set(holdingsToEnrich.map(\.symbol)))
        guard !symbols.isEmpty else { return }
        let quotes: [Quote] = (try? await provider.quotes(symbols)) ?? []
        let quoteBySymbol = Dictionary(uniqueKeysWithValues: quotes.map { ($0.symbol, $0) })
        guard !quoteBySymbol.isEmpty else { return }

        var updated: [String: [Holding]] = [:]
        for (accountId, holdings) in holdingsByAccount {
            updated[accountId] = holdings.map { h in
                guard h.dayChange == nil, let q = quoteBySymbol[h.symbol],
                      let prev = q.previousClose else { return h }
                var enriched = h
                let change = q.last - prev
                enriched.dayChange = change
                enriched.dayChangePercent = prev == 0 ? nil : (change / prev * 100)
                return enriched
            }
        }
        holdingsByAccount = updated
        convertedCache = [:]
        await recomputeAggregates()
    }
}
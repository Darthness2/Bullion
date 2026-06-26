import SwiftUI

/// Welcome header shown at the top of the Portfolio tab. Greets the user,
/// shows market indices at a glance, and surfaces portfolio stats (top
/// movers, recent activity) or watchlist movers for returning users.
/// All data is truthful — sections hide themselves when their data is
/// unavailable rather than show fabricated content.
struct WelcomeHeaderView: View {
    @Bindable var vm: PortfolioViewModel
    @Environment(\.appEnv) private var env
    @Environment(WatchlistViewModel.self) private var watchlistVM
    @State private var indexQuotes: [Quote] = []
    @State private var hasLoadedIndexes = false

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default:      return "Welcome back"
        }
    }

    private var dateText: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.spacingL) {
            greetingBlock
            marketStrip
            if vm.isLinked {
                portfolioStats
            } else if !watchlistVM.items.isEmpty {
                watchlistMovers
            }
        }
        .task {
            if !hasLoadedIndexes {
                await loadIndexes()
            }
        }
    }

    // MARK: - Greeting

    private var greetingBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(greeting)
                .font(Typography.title2)
                .foregroundColor(Theme.Colors.textPrimary)
            Text(dateText)
                .font(Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Market at a glance

    @ViewBuilder private var marketStrip: some View {
        if !indexQuotes.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Metrics.spacingS) {
                Text("Markets")
                    .font(Typography.eyebrow)
                    .foregroundColor(Theme.Colors.textSecondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Metrics.spacingS) {
                        ForEach(indexQuotes) { q in
                            indexCard(q)
                        }
                    }
                }
            }
        }
    }

    private func indexCard(_ q: Quote) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(q.symbol)
                .font(Typography.symbolCompact)
                .foregroundColor(Theme.Colors.textPrimary)
            PriceText(value: q.last, font: Typography.priceSmall)
                .foregroundColor(Theme.Colors.textPrimary)
            if let pct = q.changePercent {
                HStack(spacing: 2) {
                    Image(systemName: pct >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        .font(.system(size: 6))
                    Text(NumberFormatting.signedPercent(pct))
                }
                .font(Typography.caption2)
                .monospacedDigit()
                .foregroundColor(pct >= 0 ? Theme.Colors.positive : Theme.Colors.negative)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusSmall, style: .continuous)
                .stroke(Theme.Gradients.cardBorderGradient, lineWidth: Theme.Metrics.hairline)
        )
        .frame(width: 96)
    }

    @MainActor
    private func loadIndexes() async {
        let symbols = ["SPY", "QQQ", "DIA", "ES=F"]
        indexQuotes = (try? await env.marketProvider.quotes(symbols)) ?? []
        hasLoadedIndexes = true
    }

    // MARK: - Portfolio stats (linked users)

    @ViewBuilder private var portfolioStats: some View {
        let topMovers = vm.allHoldings
            .filter { $0.dayChangePercent != nil }
            .sorted { abs($0.dayChangePercent ?? 0) > abs($1.dayChangePercent ?? 0) }
            .prefix(3)

        if !topMovers.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Metrics.spacingS) {
                Text("Today's movers")
                    .font(Typography.eyebrow)
                    .foregroundColor(Theme.Colors.textSecondary)
                ThemedCard {
                    VStack(spacing: 0) {
                        ForEach(Array(topMovers.enumerated()), id: \.element.id) { idx, h in
                            moverRow(h)
                            if h.id != topMovers.last?.id {
                                Divider().background(Theme.Colors.separator.opacity(0.5))
                            }
                        }
                    }
                }
            }
        }

        // Recent activity (latest 3 transactions across all accounts)
        let recentTxns = vm.transactionsByAccount.values.flatMap { $0 }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
            .prefix(3)
        if !recentTxns.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Metrics.spacingS) {
                Text("Recent activity")
                    .font(Typography.eyebrow)
                    .foregroundColor(Theme.Colors.textSecondary)
                ThemedCard {
                    VStack(spacing: 0) {
                        ForEach(Array(recentTxns.enumerated()), id: \.element.id) { idx, t in
                            txnRow(t)
                            if t.id != recentTxns.last?.id {
                                Divider().background(Theme.Colors.separator.opacity(0.5))
                            }
                        }
                    }
                }
            }
        }
    }

    private func moverRow(_ h: Holding) -> some View {
        HStack {
            Text(h.symbol)
                .font(Typography.headline)
                .foregroundColor(Theme.Colors.textPrimary)
            Spacer()
            if let pct = h.dayChangePercent {
                HStack(spacing: 2) {
                    Image(systemName: pct >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        .font(.system(size: 6))
                    Text(NumberFormatting.signedPercent(pct))
                }
                .font(Typography.caption)
                .monospacedDigit()
                .foregroundColor(pct >= 0 ? Theme.Colors.positive : Theme.Colors.negative)
            }
        }
        .padding(.vertical, 8)
    }

    private func txnRow(_ t: Transaction) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(t.description)
                    .font(Typography.callout)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                Text(t.date?.shortDateText ?? "—")
                    .font(Typography.caption2)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            Spacer()
            if let amount = t.amount {
                Text((amount >= 0 ? "+" : "") + NumberFormatting.price(amount))
                    .font(Typography.callout)
                    .monospacedDigit()
                    .foregroundColor(amount >= 0 ? Theme.Colors.positive : Theme.Colors.negative)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Watchlist movers (returning users with a watchlist, not linked)

    @ViewBuilder private var watchlistMovers: some View {
        let movers = watchlistVM.items.compactMap { instrument -> (Instrument, Quote)? in
            guard let q = watchlistVM.quotes[instrument.symbol] else { return nil }
            return (instrument, q)
        }
        .sorted { abs($0.1.changePercent ?? 0) > abs($1.1.changePercent ?? 0) }
        .prefix(3)

        if !movers.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Metrics.spacingS) {
                Text("Your watchlist movers")
                    .font(Typography.eyebrow)
                    .foregroundColor(Theme.Colors.textSecondary)
                ThemedCard {
                    VStack(spacing: 0) {
                        ForEach(Array(movers.enumerated()), id: \.element.0.id) { idx, pair in
                            HStack {
                                Text(pair.0.symbol)
                                    .font(Typography.headline)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                Spacer()
                                if let pct = pair.1.changePercent {
                                    HStack(spacing: 2) {
                                        Image(systemName: pct >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                                            .font(.system(size: 6))
                                        Text(NumberFormatting.signedPercent(pct))
                                    }
                                    .font(Typography.caption)
                                    .monospacedDigit()
                                    .foregroundColor(pct >= 0 ? Theme.Colors.positive : Theme.Colors.negative)
                                }
                            }
                            .padding(.vertical, 8)
                            if pair.0.id != movers.last?.0.id {
                                Divider().background(Theme.Colors.separator.opacity(0.5))
                            }
                        }
                    }
                }
            }
        }
    }
}
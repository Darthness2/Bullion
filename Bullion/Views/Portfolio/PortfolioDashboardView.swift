import SwiftUI

/// Robinhood-style portfolio dashboard. Big hero value, day-change pill,
/// honest stats, then a clean flat holdings list (with today's change) —
/// each row drills into HoldingDetailView. Accounts are surfaced as a
/// section when there are multiple. No fabricated data: equity history and
/// buying power are omitted until the backend provides them.
struct PortfolioDashboardView: View {
    @Bindable var vm: PortfolioViewModel
    @Environment(\.appEnv) private var env
    @Namespace private var heroNamespace
    @State private var sortOption: SortOption = .valueDesc
    @State private var previousTotal: Double?

    enum SortOption: String, CaseIterable, Identifiable {
        case valueDesc = "Value ↓"
        case valueAsc = "Value ↑"
        case dayChangeDesc = "Day Change ↓"
        case dayChangeAsc = "Day Change ↑"
        case plDesc = "Total P/L ↓"
        case alpha = "A–Z"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Portfolio")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Image("BrandIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
                .navigationDestination(for: BrokerageAccount.self) { account in
                    AccountDetailView(account: account, vm: vm)
                }
                .navigationDestination(for: Holding.self) { holding in
                    HoldingDetailView(holding: holding, account: primaryAccount(for: holding))
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(spacing: Theme.Metrics.spacingL) {
                switch vm.accounts {
                case .idle, .loading:
                    GlowLoadingView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                case .empty:
                    EmptyStateView(
                        icon: "briefcase",
                        message: "No linked accounts. Connect a brokerage to see your holdings.",
                        actionTitle: "Connect",
                        action: { vm.isLinked = false }
                    )
                    .padding(.top, 60)
                    .transition(.opacity)
                case .failed(let msg):
                    ErrorView(message: msg) {
                        Task { await vm.load() }
                    }
                    .padding(.top, 60)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                case .loaded(let accounts):
                    if vm.partialSync {
                        partialSyncBanner
                            .appearAnimation(.rise)
                    }
                    WelcomeHeaderView(vm: vm)
                        .appearAnimation(.blur)
                    heroSection
                        .appearAnimation(.blur, index: 1)
                    statsBar
                        .appearAnimation(.rise, index: 2)
                    analyticsCard
                        .appearAnimation(.rise, index: 2)
                    holdingsList
                        .appearAnimation(.rise, index: 3)
                    if accounts.count > 1 {
                        accountsSection(accounts: accounts)
                            .appearAnimation(.rise, index: 4)
                    }
                }
            }
            .padding(.horizontal, Theme.Metrics.spacingL)
            .padding(.bottom, Theme.Metrics.bottomSafeClearance)
        }
        .background(
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                RadialGradient(
                    colors: [Theme.Colors.accent.opacity(0.04), .clear],
                    center: .top, startRadius: 10, endRadius: 320
                )
                .ignoresSafeArea()
            }
        )
        .refreshable { await vm.refresh() }
        .task(id: vm.accounts) {
            // Enrich day change from live Yahoo quotes once holdings load.
            if case .loaded = vm.accounts, vm.allHoldings.contains(where: { $0.dayChange == nil }) {
                await vm.enrichDayChange(provider: env.marketProvider)
            }
            // Compute portfolio analytics (beta, Sharpe, max drawdown) once
            // holdings are available. Cheap relative to the LLM features and
            // surfaces the metrics a serious investor expects.
            if case .loaded = vm.accounts, vm.analytics == nil {
                await vm.recomputeAnalytics(provider: env.marketProvider)
            }
        }
    }

    // MARK: - Partial sync banner (honest about failed connections)

    private var partialSyncBanner: some View {
        HStack(spacing: Theme.Metrics.spacingS) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Theme.Colors.negative)
            Text("Some accounts couldn't sync. Tap to retry.")
                .font(Typography.caption)
                .foregroundColor(Theme.Colors.textPrimary)
            Spacer()
        }
        .padding(Theme.Metrics.spacingS)
        .background(Theme.Colors.negative.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusSmall, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { Task { await vm.load() } }
    }

    // MARK: - Hero value

    private var heroSection: some View {
        VStack(spacing: Theme.Metrics.spacingS) {
            Text("PORTFOLIO VALUE")
                .font(Typography.eyebrow)
                .tracking(1.2)
                .foregroundColor(Theme.Colors.textSecondary)
            // Emerald radial glow behind the hero number — the signature
            // premium depth cue. Placed behind the PriceText, large blur.
            PriceText(value: vm.totalValue, font: Typography.hero)
                .monospacedDigit()
                .foregroundColor(Theme.Colors.textPrimary)
                .scaleEffect(pulse ? 1.02 : 1.0)
                .animation(Theme.Animation.snappy, value: pulse)
                .background(
                    Theme.Gradients.heroGlowGradient
                        .frame(width: 280, height: 140)
                        .blur(radius: 24)
                        .allowsHitTesting(false)
                )
            if vm.hasMultiCurrency {
                Text("Converted to \(vm.baseCurrency) · live FX")
                    .font(Typography.caption2)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .accessibilityLabel("Converted to \(vm.baseCurrency) using live foreign exchange rates")
            }
            dayChangePill
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Metrics.spacingS)
        .onChange(of: vm.totalValue) { _, new in
            guard let prev = previousTotal, prev != new, prev > 0 else {
                previousTotal = new
                return
            }
            pulse = true
            Haptics.success()
            Task { try? await Task.sleep(for: .milliseconds(220)); pulse = false }
            previousTotal = new
        }
        .onAppear { previousTotal = vm.totalValue }
    }

    @State private var pulse = false

    @ViewBuilder
    private var dayChangePill: some View {
        if vm.hasDayChangeData {
            let change = vm.totalDayChange
            let isUp = change >= 0
            let tint = isUp ? Theme.Colors.positive : Theme.Colors.negative
            HStack(spacing: 4) {
                Image(systemName: isUp ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.system(size: 8))
                    .symbolEffect(.bounce, value: isUp)
                Text((isUp ? "+" : "") + NumberFormatting.price(change))
                    .monospacedDigit()
                Text("(\(NumberFormatting.signedPercent(vm.totalDayChangePercent)))")
                    .monospacedDigit()
            }
            .font(Typography.subheadline)
            .foregroundColor(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.22), lineWidth: Theme.Metrics.hairline))
        } else {
            Text("Day change unavailable")
                .font(Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
        }
    }

    // MARK: - Stats bar (honest — only real metrics)

    private var statsBar: some View {
        HStack(spacing: 12) {
            statTile(label: "Total Value", value: vm.totalValue, icon: "dollarsign.circle")
            statTile(label: "Unrealized P/L", value: vm.totalUnrealizedPL, icon: "chart.bar.fill", isPL: true)
        }
    }

    // MARK: - Analytics card (beta, Sharpe, max drawdown, concentration)

    @ViewBuilder
    private var analyticsCard: some View {
        if let a = vm.analytics {
            ThemedCard {
                VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.accent)
                        Text("Portfolio Analytics")
                            .font(Typography.caption2)
                            .foregroundColor(Theme.Colors.textSecondary)
                        Spacer()
                    }
                    HStack(spacing: Theme.Metrics.spacingL) {
                        analyticsTile(label: "Beta vs SPY", value: a.beta.map { String(format: "%.2f", $0) })
                        analyticsTile(label: "Sharpe", value: a.sharpe.map { String(format: "%.2f", $0) })
                        analyticsTile(label: "Max Drawdown", value: a.maxDrawdown.map { String(format: "-%.1f%%", $0 * 100) })
                    }
                    HStack(spacing: Theme.Metrics.spacingL) {
                        analyticsTile(label: "Holdings", value: "\(a.diversification)")
                        analyticsTile(label: "Top Holding", value: a.largestHoldingWeight.map { String(format: "%.0f%%", $0 * 100) })
                        Spacer()
                    }
                }
            }
        }
    }

    private func analyticsTile(label: String, value: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Typography.caption2)
                .foregroundColor(Theme.Colors.textSecondary)
            Text(value ?? "—")
                .font(Typography.subheadline)
                .monospacedDigit()
                .foregroundColor(Theme.Colors.textPrimary)
        }
    }

    private func statTile(label: String, value: Double, icon: String, isPL: Bool = false) -> some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.accent)
                    Text(label)
                        .font(Typography.caption2)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                Text(NumberFormatting.price(value))
                    .font(Typography.headline)
                    .monospacedDigit()
                    .foregroundColor(isPL ? (value >= 0 ? Theme.Colors.positive : Theme.Colors.negative) : Theme.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .pressScale()
    }

    // MARK: - Holdings list

    private var sortedHoldings: [Holding] {
        let all = vm.allHoldings
        switch sortOption {
        case .valueDesc:    return all.sorted { $0.marketValue > $1.marketValue }
        case .valueAsc:     return all.sorted { $0.marketValue < $1.marketValue }
        case .dayChangeDesc: return all.sorted { ($0.dayChangePercent ?? -999) > ($1.dayChangePercent ?? -999) }
        case .dayChangeAsc:  return all.sorted { ($0.dayChangePercent ?? 999) < ($1.dayChangePercent ?? 999) }
        case .plDesc:       return all.sorted { ($0.unrealizedPLPercent ?? -999) > ($1.unrealizedPLPercent ?? -999) }
        case .alpha:        return all.sorted { $0.symbol < $1.symbol }
        }
    }

    private var holdingsList: some View {
        let holdings = sortedHoldings
        return VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
            HStack {
                SectionHeader(title: "Holdings")
                Spacer()
                Menu {
                    Picker("Sort", selection: $sortOption) {
                        ForEach(SortOption.allCases) { opt in Text(opt.rawValue).tag(opt) }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 11, weight: .semibold))
                        Text("\(holdings.count)")
                            .font(Typography.caption)
                    }
                    .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            ThemedCard {
                VStack(spacing: 0) {
                    ForEach(Array(holdings.enumerated()), id: \.element.id) { idx, holding in
                        NavigationLink(value: holding) {
                            holdingRow(holding)
                        }
                        .buttonStyle(.plain)
                        .matchedTransitionSource(id: holding.symbol, in: heroNamespace)
                        .staggeredAppear(index: idx)
                        if holding.id != holdings.last?.id {
                            Divider().background(Theme.Colors.separator.opacity(0.5))
                        }
                    }
                }
            }
        }
    }

    private func holdingRow(_ h: Holding) -> some View {
        HStack(spacing: Theme.Metrics.spacing) {
            VStack(alignment: .leading, spacing: 2) {
                Text(h.symbol)
                    .font(Typography.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(NumberFormatting.decimal(h.quantity, digits: 4) + " shares")
                    .font(Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                // Today's change (most actionable) — honest "—" when unavailable.
                if let dayPct = h.dayChangePercent {
                    HStack(spacing: 2) {
                        Image(systemName: dayPct >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                            .font(.system(size: 6))
                        Text(NumberFormatting.signedPercent(dayPct))
                    }
                    .font(Typography.caption)
                    .monospacedDigit()
                    .foregroundColor(dayPct >= 0 ? Theme.Colors.positive : Theme.Colors.negative)
                    .contentTransition(.numericText())
                } else {
                    Text("—")
                        .font(Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                PriceText(value: h.marketValue, font: Typography.priceSmall)
                    .foregroundColor(Theme.Colors.textPrimary)
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: - Accounts section

    private func accountsSection(accounts: [BrokerageAccount]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
            SectionHeader(title: "Accounts")
            VStack(spacing: Theme.Metrics.spacingS) {
                ForEach(Array(accounts.enumerated()), id: \.element.id) { idx, account in
                    NavigationLink(value: account) {
                        accountRow(account)
                    }
                    .buttonStyle(.plain)
                    .matchedTransitionSource(id: account.id, in: heroNamespace)
                    .staggeredAppear(index: idx)
                }
            }
        }
    }

    private func accountRow(_ account: BrokerageAccount) -> some View {
        ThemedCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name)
                        .font(Typography.subheadline)
                        .foregroundColor(Theme.Colors.textPrimary)
                    HStack(spacing: 4) {
                        Text(account.brokerage)
                            .font(Typography.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                        if account.connectionStatus == .needsReconnect {
                            Text("· Reconnect needed")
                                .font(Typography.caption2)
                                .foregroundColor(Theme.Colors.negative)
                        }
                    }
                }
                Spacer()
                PriceText(value: account.totalValue, font: Typography.priceSmall)
                    .foregroundColor(Theme.Colors.textPrimary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
        .pressScale()
    }

    // MARK: - Helpers

    private func primaryAccount(for holding: Holding) -> BrokerageAccount {
        for (accountId, holdings) in vm.holdingsByAccount {
            if holdings.contains(where: { $0.symbol == holding.symbol }) {
                if let acc = (vm.accounts.value ?? []).first(where: { $0.id == accountId }) {
                    return acc
                }
            }
        }
        return BrokerageAccount(id: "", name: "Account", brokerage: "",
                                totalValue: 0, currency: "USD", lastSynced: Date())
    }
}
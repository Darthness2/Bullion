import SwiftUI

/// Robinhood-style portfolio dashboard. Big hero value, day-change pill,
/// equity sparkline, buying-power bar, then a clean flat holdings list —
/// each row drills into HoldingDetailView. Accounts are surfaced as a
/// section header rather than the primary unit.
struct PortfolioDashboardView: View {
    @Bindable var vm: PortfolioViewModel
    @Namespace private var heroNamespace

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
                    heroSection
                        .appearAnimation(.blur)
                    equityChart
                        .appearAnimation(.blur, index: 1)
                    statsBar
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
            .padding(.bottom, 100)
        }
        .background(
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                RadialGradient(
                    colors: [Theme.Colors.accent.opacity(0.06), .clear],
                    center: .top, startRadius: 10, endRadius: 320
                )
                .ignoresSafeArea()
            }
        )
        .refreshable { await vm.refresh() }
    }

    // MARK: - Hero value (Robinhood-style big number)

    private var heroSection: some View {
        VStack(spacing: Theme.Metrics.spacingS) {
            Text("Portfolio Value")
                .font(Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
                .textCase(.uppercase)
                .tracking(1.2)
            PriceText(value: vm.totalValue, font: Font.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.textPrimary)
            dayChangePill
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Metrics.spacingS)
    }

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
            .overlay(
                Capsule().stroke(tint.opacity(0.22), lineWidth: Theme.Metrics.hairline)
            )
        } else {
            // No day-change data from the brokerage — show a neutral state
            // rather than a misleading green "+$0.00 (+0.00%)".
            Text("Day change unavailable")
                .font(Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Theme.Colors.textSecondary.opacity(0.08))
                .clipShape(Capsule())
        }
    }

    // MARK: - Equity curve (sparkline of portfolio value)

    @ViewBuilder
    private var equityChart: some View {
        let values = equitySeries
        ThemedCard {
            VStack(alignment: .leading, spacing: Theme.Metrics.spacingS) {
                HStack {
                    Text("Equity")
                        .font(Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    Spacer()
                    Text("1M")
                        .font(Typography.caption2)
                        .foregroundColor(Theme.Colors.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.Colors.accent.opacity(0.10))
                        .clipShape(Capsule())
                }
                EquitySparkline(values: values, color: Theme.Colors.accent)
                    .frame(height: 80)
            }
        }
    }

    // MARK: - Stats bar (buying power, P/L)

    private var statsBar: some View {
        HStack(spacing: 12) {
            statTile(label: "Buying Power", value: vm.totalValue * 0.25, icon: "dollarsign.circle")
            statTile(label: "Unrealized P/L", value: vm.totalUnrealizedPL, icon: "chart.bar.fill", isPL: true)
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

    // MARK: - Holdings list (flat, Robinhood-style)

    private var holdingsList: some View {
        let holdings = vm.allHoldings.sorted { $0.marketValue > $1.marketValue }
        return VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
            HStack {
                SectionHeader(title: "Holdings")
                Spacer()
                Text("\(holdings.count) positions")
                    .font(Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
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
            // Symbol avatar — blue-tinted circle with first letter
            ZStack {
                Circle()
                    .fill(Theme.Colors.accent.opacity(0.12))
                Text(String(h.symbol.prefix(1)))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.accent)
            }
            .frame(width: 36, height: 36)

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
                PriceText(value: h.marketValue, font: Typography.priceSmall)
                    .foregroundColor(Theme.Colors.textPrimary)
                if let pl = h.unrealizedPL {
                    HStack(spacing: 2) {
                        Image(systemName: pl >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                            .font(.system(size: 6))
                        Text((pl >= 0 ? "+" : "") + NumberFormatting.price(pl))
                    }
                    .font(Typography.caption)
                    .monospacedDigit()
                    .foregroundColor(pl >= 0 ? Theme.Colors.positive : Theme.Colors.negative)
                    .contentTransition(.numericText())
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Accounts section (secondary, shown only if multiple)

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
                    Text(account.brokerage)
                        .font(Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                Spacer()
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

    /// Synthesized equity curve from current holdings' market values (mock
    /// 30-point series for the 1M sparkline — replaced by real history when
    /// a backend timeseries endpoint exists).
    private var equitySeries: [Double] {
        let total = max(vm.totalValue, 1)
        return (0..<30).map { i in
            let wobble = sin(Double(i) * 0.4) * 0.03 + cos(Double(i) * 0.15) * 0.02
            return total * (1 - Double(i) * 0.006 + wobble)
        }
    }
}

// MARK: - Equity sparkline

private struct EquitySparkline: View {
    let values: [Double]
    let color: Color
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            if values.count > 1 {
                ZStack {
                    // Fill area
                    Path { path in
                        let minV = values.min() ?? 0
                        let maxV = values.max() ?? 1
                        let range = max(maxV - minV, 0.0001)
                        let stepX = geo.size.width / CGFloat(values.count - 1)
                        path.move(to: CGPoint(x: 0, y: geo.size.height))
                        for (i, v) in values.enumerated() {
                            let x = CGFloat(i) * stepX
                            let y = geo.size.height * (1 - CGFloat((v - minV) / range))
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                        path.closeSubpath()
                    }
                    .fill(Theme.Gradients.accentLineFillGradient)

                    // Line
                    Path { path in
                        let minV = values.min() ?? 0
                        let maxV = values.max() ?? 1
                        let range = max(maxV - minV, 0.0001)
                        let stepX = geo.size.width / CGFloat(values.count - 1)
                        for (i, v) in values.enumerated() {
                            let x = CGFloat(i) * stepX
                            let y = geo.size.height * (1 - CGFloat((v - minV) / range))
                            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                            else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .trim(from: 0, to: animate ? 1 : 0)
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }
            } else {
                Color.clear
            }
        }
        .onAppear {
            withAnimation(Theme.Animation.slow.delay(0.2)) {
                animate = true
            }
        }
    }
}
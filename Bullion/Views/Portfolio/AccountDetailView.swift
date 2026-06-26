import SwiftUI

/// One account: holdings list, recent transactions, reconnect/disconnect.
struct AccountDetailView: View {
    let account: BrokerageAccount
    @Bindable var vm: PortfolioViewModel
    @Environment(\.appEnv) private var env
    @Namespace private var heroNamespace

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Metrics.spacingL) {
                headerCard
                holdingsCard
                transactionsCard
                actionsCard
            }
            .padding(.horizontal, Theme.Metrics.spacingL)
            .padding(.bottom, 40)
        }
        .background(
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                RadialGradient(
                    colors: [Theme.Colors.textPrimary.opacity(0.03), .clear],
                    center: .top, startRadius: 10, endRadius: 300
                )
                .ignoresSafeArea()
            }
        )
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Holding.self) { holding in
            HoldingDetailView(holding: holding, account: account)
        }
        .refreshable { await vm.syncAccount(account.id) }
        .task { await vm.syncAccount(account.id) }
    }

    private var headerCard: some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: Theme.Metrics.spacingS) {
                HStack {
                    Text(account.brokerage)
                        .font(Typography.subheadline)
                        .foregroundColor(Theme.Colors.textSecondary)
                    Spacer()
                    Text(account.connectionStatus.rawValue.capitalized)
                        .font(Typography.caption2)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .textCase(.uppercase)
                }
                PriceText(value: account.totalValue, font: Typography.priceLarge)
                Text("Synced \(account.lastSynced.relativeText)")
                    .font(Typography.caption2)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
        .appearAnimation(.blur)
    }

    private var holdingsCard: some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
                SectionHeader(title: "Holdings")
                if let holdings = vm.holdingsByAccount[account.id], !holdings.isEmpty {
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
                } else {
                    EmptyStateView(icon: "tray", message: "No holdings in this account.")
                }
            }
        }
        .appearAnimation(.blur, index: 1)
    }

    private func holdingRow(_ h: Holding) -> some View {
        HStack(spacing: Theme.Metrics.spacing) {
            VStack(alignment: .leading, spacing: 2) {
                Text(h.symbol)
                    .font(Typography.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("\(NumberFormatting.decimal(h.quantity, digits: 4)) shares")
                    .font(Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                PriceText(value: h.marketValue, font: Typography.priceSmall)
                if let pl = h.unrealizedPL {
                    Text((pl >= 0 ? "+" : "") + NumberFormatting.price(pl))
                        .font(Typography.caption)
                        .monospacedDigit()
                        .foregroundColor(pl >= 0 ? Theme.Colors.positive : Theme.Colors.negative)
                        .contentTransition(.numericText())
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var transactionsCard: some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
                HStack {
                    SectionHeader(title: "Recent Transactions")
                    Spacer()
                    if let txns = vm.transactionsByAccount[account.id], !txns.isEmpty {
                        NavigationLink {
                            TransactionsView(accountId: account.id, vm: vm)
                        } label: {
                            Text("See all")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.Colors.textSecondary)
                                .textCase(.uppercase)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if let txns = vm.transactionsByAccount[account.id], !txns.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(txns.prefix(3).enumerated()), id: \.element.id) { idx, txn in
                            transactionRow(txn)
                                .staggeredAppear(index: idx)
                            if txn.id != txns.prefix(3).last?.id {
                                Divider().background(Theme.Colors.separator.opacity(0.5))
                            }
                        }
                    }
                } else {
                    EmptyStateView(icon: "list.bullet.rectangle", message: "No recent transactions.")
                }
            }
        }
        .appearAnimation(.blur, index: 2)
    }

    private func transactionRow(_ t: Transaction) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(t.description)
                    .font(Typography.callout)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(t.date?.shortDateText ?? "—")
                    .font(Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            Spacer()
            if let amount = t.amount {
                Text((amount >= 0 ? "+" : "") + NumberFormatting.price(amount))
                    .font(Typography.callout)
                    .monospacedDigit()
                    .foregroundColor(amount >= 0 ? Theme.Colors.positive : Theme.Colors.negative)
                    .contentTransition(.numericText())
            }
        }
        .padding(.vertical, 4)
    }

    private var actionsCard: some View {
        ThemedCard {
            VStack(spacing: Theme.Metrics.spacingS) {
                PrimaryButton(title: "Re-sync", style: .outline, icon: "arrow.clockwise") {
                    Task { await vm.refreshConnection(accountId: account.id) }
                }
                Button("Disconnect", role: .destructive) {
                    Task { await vm.disconnect(accountId: account.id) }
                }
                .font(Typography.caption)
                .symbolEffect(.bounce, value: account.id)
            }
        }
        .appearAnimation(.blur, index: 3)
    }
}
import SwiftUI

/// Per-holding detail: cost basis, quantity, market value, unrealized P&L
/// ($ and %), day change, and allocation within the account.
struct HoldingDetailView: View {
    let holding: Holding
    let account: BrokerageAccount
    @Environment(\.appEnv) private var env

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Metrics.spacingL) {
                headerCard
                pnlCard
                detailCard
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
        .navigationTitle(holding.symbol)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: Theme.Metrics.spacingS) {
                Text(holding.name)
                    .font(Typography.subheadline)
                    .foregroundColor(Theme.Colors.textSecondary)
                PriceText(value: holding.marketValue, font: Typography.priceLarge)
                Text("\(account.name) · \(account.brokerage)")
                    .font(Typography.caption2)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
        .appearAnimation(.blur)
    }

    private var pnlCard: some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
                SectionHeader(title: "Profit / Loss")
                VStack(spacing: 0) {
                    StatCell(label: "Unrealized P/L",
                             value: holding.unrealizedPL.map { (0 >= $0 ? "" : "+") + NumberFormatting.price($0) })
                        .staggeredAppear(index: 0)
                    if let pct = holding.unrealizedPLPercent {
                        StatCell(label: "Unrealized P/L %",
                                 value: "\(pct >= 0 ? "+" : "")\(String(format: "%.2f", pct))%")
                            .staggeredAppear(index: 1)
                    }
                    StatCell(label: "Day Change",
                             value: holding.dayChange.map { ($0 >= 0 ? "+" : "") + NumberFormatting.price($0) })
                        .staggeredAppear(index: 2)
                    if let dayPct = holding.dayChangePercent {
                        StatCell(label: "Day Change %",
                                 value: "\(dayPct >= 0 ? "+" : "")\(String(format: "%.2f", dayPct))%")
                            .staggeredAppear(index: 3)
                    }
                }
            }
        }
        .appearAnimation(.blur, index: 1)
    }

    private var detailCard: some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
                SectionHeader(title: "Cost Basis")
                VStack(spacing: 0) {
                    StatCell(label: "Quantity",
                             value: NumberFormatting.decimal(holding.quantity, digits: 4))
                        .staggeredAppear(index: 0)
                    StatCell(label: "Avg Cost",
                             value: holding.avgCost.map { NumberFormatting.price($0) })
                        .staggeredAppear(index: 1)
                    StatCell(label: "Cost Basis",
                             value: holding.avgCost.map { NumberFormatting.price($0 * holding.quantity) })
                        .staggeredAppear(index: 2)
                    StatCell(label: "Market Value",
                             value: NumberFormatting.price(holding.marketValue))
                        .staggeredAppear(index: 3)
                    StatCell(label: "Account",
                             value: "\(account.name) (\(account.brokerage))")
                        .staggeredAppear(index: 4)
                }
            }
        }
        .appearAnimation(.blur, index: 2)
    }
}
import SwiftUI

/// Full transaction history for a single account, grouped by date.
struct TransactionsView: View {
    let accountId: String
    @Bindable var vm: PortfolioViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Metrics.spacingL) {
                if let txns = vm.transactionsByAccount[accountId], !txns.isEmpty {
                    ForEach(Array(grouped(txns).enumerated()), id: \.element.key) { idx, group in
                        VStack(alignment: .leading, spacing: Theme.Metrics.spacingS) {
                            SectionHeader(title: group.key)
                            ThemedCard {
                                VStack(spacing: 0) {
                                    ForEach(Array(group.transactions.enumerated()), id: \.element.id) { i, txn in
                                        row(txn)
                                            .staggeredAppear(index: i)
                                        if txn.id != group.transactions.last?.id {
                                            Divider().background(Theme.Colors.separator.opacity(0.5))
                                        }
                                    }
                                }
                            }
                        }
                        .staggeredAppear(index: idx)
                    }
                } else {
                    EmptyStateView(icon: "list.bullet.rectangle",
                                   message: "No transactions for this account.")
                        .padding(.top, 60)
                }
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
        .navigationTitle("Transactions")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ t: Transaction) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(t.description)
                    .font(Typography.callout)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("\(t.date?.shortDateText ?? "—") · \(t.type.capitalized)")
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
            } else {
                Text("—")
                    .font(Typography.callout)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Grouping

    private struct TxnGroup {
        let key: String
        let transactions: [Transaction]
    }

    private func grouped(_ txns: [Transaction]) -> [TxnGroup] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let undatedKey = "Date unavailable"
        let groups = Dictionary(grouping: txns) { txn in
            txn.date.map { formatter.string(from: $0) } ?? undatedKey
        }
        return groups.keys.sorted { a, b in
            // Undated transactions sort to the bottom.
            let da = groups[a]?.compactMap(\.date).max()
            let db = groups[b]?.compactMap(\.date).max()
            switch (da, db) {
            case let (a?, b?): return a > b
            case (nil, _):     return false
            case (_, nil):     return true
            }
        }.map { TxnGroup(key: $0, transactions: groups[$0] ?? []) }
    }
}
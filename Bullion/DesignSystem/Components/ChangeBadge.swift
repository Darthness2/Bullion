import SwiftUI

/// Displays a price change with absolute and percentage values,
/// colored green/red with a flat pill background. Minimal, no glow.
struct ChangeBadge: View {
    let change: Double?
    let changePercent: Double?
    var compact: Bool = false

    private var isPositive: Bool { (change ?? 0) >= 0 }

    var body: some View {
        if let change, let changePercent {
            HStack(spacing: 3) {
                Image(systemName: isPositive ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.system(size: compact ? 7 : 9))
                    .symbolEffect(.bounce, value: isPositive)
                    .contentTransition(.symbolEffect(.replace))
                Text("\(signedString(change))")
                Text("(\(signedString(changePercent))%)")
            }
            .font(compact ? Typography.caption2 : Typography.caption)
            .foregroundColor(isPositive ? Theme.Colors.positive : Theme.Colors.negative)
            .padding(.horizontal, compact ? 7 : 10)
            .padding(.vertical, compact ? 3 : 5)
            .background(
                ZStack {
                    (isPositive ? Theme.Colors.positive : Theme.Colors.negative).opacity(0.12)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke((isPositive ? Theme.Colors.positive : Theme.Colors.negative).opacity(0.22),
                                lineWidth: Theme.Metrics.hairline)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            )
            .animation(Theme.Animation.interactive, value: isPositive)
        } else {
            Text("—")
                .font(Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
        }
    }

    private func signedString(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        return sign + String(format: "%.2f", value)
    }
}
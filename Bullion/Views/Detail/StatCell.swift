import SwiftUI

/// A single key-value stat row within the stats grid.
struct StatCell: View {
    let label: String
    let value: String?

    var body: some View {
        HStack {
            Text(label)
                .font(Typography.callout)
                .foregroundColor(Theme.Colors.textSecondary)
            Spacer()
            if let value {
                Text(value)
                    .font(Typography.callout)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(Theme.Animation.interactive, value: value)
            } else {
                Text("—")
                    .font(Typography.callout)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
        .padding(.vertical, 7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value ?? "not available")")
    }
}
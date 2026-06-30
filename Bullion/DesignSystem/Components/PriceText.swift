import SwiftUI

/// A price text view with `.monospacedDigit()` so refreshes don't jitter,
/// and `.contentTransition(.numericText())` so the digits roll on update.
struct PriceText: View {
    let value: Double?
    var currency: Bool = true
    var font: Font = Typography.price
    var color: Color? = nil
    var digits: Int? = nil
    var glow: Bool = false  // retained for API stability; no-op in monochrome theme

    var body: some View {
        if let value {
            Text(formatted(value))
                .font(font)
                .monospacedDigit()
                .foregroundColor(color ?? Theme.Colors.textPrimary)
                // countsDown: true so DECREASING values roll downward — a price
                // drop should visually descend, not ascend. (Previously
                // countsDown: false made every change animate up, misleading.)
                .contentTransition(.numericText(countsDown: true))
                .animation(Theme.Animation.interactive, value: value)
        } else {
            Text("—")
                .font(font)
                .foregroundColor(Theme.Colors.textSecondary)
        }
    }

    private func formatted(_ v: Double) -> String {
        if currency {
            return NumberFormatting.currency(v, digits: digits)
        } else {
            return NumberFormatting.decimal(v, digits: digits)
        }
    }
}
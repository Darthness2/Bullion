import SwiftUI

/// Reusable row showing an instrument with symbol, name, type badge,
/// price, and day-change badge. Futuristic style with glow on price.
struct InstrumentRow: View {
    let instrument: Instrument
    let quote: Quote?
    var showsBadge: Bool = true

    var body: some View {
        HStack(spacing: Theme.Metrics.spacing) {
            // Left: symbol + name
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(instrument.symbol)
                        .font(Typography.symbol)
                        .foregroundColor(Theme.Colors.textPrimary)
                    if showsBadge {
                        InstrumentTypeBadge(type: instrument.type)
                    }
                }
                Text(instrument.name)
                    .font(Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Right: price + percent change (plain colored text, no pill)
            VStack(alignment: .trailing, spacing: 3) {
                PriceText(value: quote?.last, font: Typography.price)
                    .priceFlash(quote?.last)
                if let pct = quote?.changePercent {
                    HStack(spacing: 2) {
                        Image(systemName: pct >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                            .font(.system(size: 6))
                        Text(NumberFormatting.signedPercent(pct))
                    }
                    .font(Typography.caption)
                    .monospacedDigit()
                    .foregroundColor(pct >= 0 ? Theme.Colors.positive : Theme.Colors.negative)
                    .contentTransition(.numericText())
                } else {
                    Text("—")
                        .font(Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts: [String] = [instrument.symbol, instrument.name]
        if let quote {
            parts.append("Price \(NumberFormatting.price(quote.last))")
            if let pct = quote.changePercent {
                parts.append("\(pct >= 0 ? "up" : "down") \(NumberFormatting.percent(abs(pct))) percent")
            }
        }
        return parts.joined(separator: ", ")
    }
}
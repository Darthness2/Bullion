import SwiftUI

/// Small pill labeling an instrument type (Stock / ETF / Future / Index).
/// Monochrome — type differentiation via grayscale shades, no color, no glow.
struct InstrumentTypeBadge: View {
    let type: InstrumentType

    var body: some View {
        Text(type.displayName)
            .font(.system(size: 10, weight: .bold))
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.10))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.18), lineWidth: Theme.Metrics.hairline))
            .transition(.opacity.combined(with: .scale))
            .animation(Theme.Animation.interactive, value: type)
    }

    private var color: Color {
        switch type {
        case .stock:  return Theme.Colors.accent
        case .etf:    return Theme.Colors.inkSubtle
        case .future: return Theme.Colors.textSecondary
        case .index: return Theme.Colors.textSecondary.opacity(0.7)
        }
    }
}

extension InstrumentType {
    var displayName: String {
        switch self {
        case .stock:  return "Stock"
        case .etf:    return "ETF"
        case .future: return "Future"
        case .index:  return "Index"
        }
    }
}
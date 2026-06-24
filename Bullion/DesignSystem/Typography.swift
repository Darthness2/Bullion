import SwiftUI

// MARK: - Typography

/// Centralized font styles. SF Pro (system) throughout.
/// Use `.monospacedDigit()` on price views so refreshes don't jitter.
enum Typography {
    // Brand / display
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .default)
    static let title      = Font.system(size: 28, weight: .bold, design: .default)
    static let title2     = Font.system(size: 22, weight: .semibold, design: .default)

    // Prices — large, rounded, semibold; pair with .monospacedDigit()
    static let priceLarge = Font.system(size: 32, weight: .semibold, design: .rounded)
    static let price      = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let priceSmall = Font.system(size: 14, weight: .semibold, design: .rounded)

    // Section headers
    static let headline   = Font.system(size: 17, weight: .semibold, design: .default)
    static let subheadline = Font.system(size: 15, weight: .medium, design: .default)

    // Body
    static let body       = Font.system(size: 16, weight: .regular, design: .default)
    static let callout    = Font.system(size: 14, weight: .regular, design: .default)

    // Stats labels / captions
    static let caption    = Font.system(size: 12, weight: .medium, design: .default)
    static let caption2   = Font.system(size: 11, weight: .regular, design: .default)

    // Tab bar / micro
    static let micro      = Font.system(size: 10, weight: .semibold, design: .default)

    // Symbols — row/card symbol text (rounded, bold). Replaces hardcoded sizes.
    static let symbol        = Font.system(size: 16, weight: .bold, design: .rounded)
    static let symbolCompact = Font.system(size: 14, weight: .bold, design: .rounded)

    // Chart axis / crosshair annotations — small, medium. Replaces hardcoded sizes.
    static let chartAxis   = Font.system(size: 10, weight: .medium, design: .default)
    static let chartCross  = Font.system(size: 13, weight: .semibold, design: .rounded)
    static let chartMicro  = Font.system(size: 10, weight: .regular, design: .default)
}
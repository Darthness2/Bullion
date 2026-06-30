import SwiftUI

// MARK: - Typography

/// Centralized font styles. SF Pro (system) throughout.
/// Financial numbers use `design: .rounded` + `.monospacedDigit()` so refreshes
/// don't jitter and digits align vertically across rows (the "tabular nums"
/// feel of a trading terminal). Section labels use an uppercase eyebrow style
/// so they don't get lost in the hierarchy.
enum Typography {
    // Hero / balance — the most important numbers (portfolio total).
    // `relativeTo` makes these respect the user's Dynamic Type setting while
    // keeping a fixed offset from the base style.
    static let hero    = Font.system(size: 44, weight: .bold, design: .rounded)
    static let balance = Font.system(size: 28, weight: .semibold, design: .rounded)
    /// Eyebrow label — uppercase, semibold, tracked. For section labels above
    /// hero values ("PORTFOLIO VALUE", "AI RESEARCH"). Apply `.tracking(1.2)`
    /// at the call site (tracking can't live in a Font).
    static let eyebrow = Font.system(size: 12, weight: .semibold, design: .default)

    // Brand / display
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .default)
    static let title      = Font.system(size: 28, weight: .bold, design: .default)
    static let title2     = Font.system(size: 22, weight: .semibold, design: .default)

    // Prices — fixed sizes for layout stability (financial numbers shouldn't
    // reflow with Dynamic Type; secondary text scales instead). Rounded design
    // + call-site `.monospacedDigit()` for tabular alignment across rows.
    static let priceLarge = Font.system(size: 32, weight: .semibold, design: .rounded)
    static let price      = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let priceSmall = Font.system(size: 14, weight: .semibold, design: .rounded)

    // Section headers / body / captions — relative to text styles so they
    // scale with the user's Dynamic Type setting (accessibility).
    static let headline    = Font.system(.headline, design: .default).weight(.semibold)
    static let subheadline = Font.system(.subheadline, design: .default).weight(.medium)
    static let body        = Font.system(.body, design: .default)
    static let callout     = Font.system(.callout, design: .default)
    static let caption     = Font.system(.caption, design: .default).weight(.medium)
    static let caption2    = Font.system(.footnote, design: .default)

    // Tab bar / micro
    static let micro      = Font.system(size: 11, weight: .semibold, design: .default)

    // Symbols — row/card symbol text (rounded, bold). Replaces hardcoded sizes.
    static let symbol        = Font.system(size: 16, weight: .bold, design: .rounded)
    static let symbolCompact = Font.system(size: 14, weight: .bold, design: .rounded)

    // Chart axis / crosshair annotations — small, medium. Replaces hardcoded sizes.
    static let chartAxis   = Font.system(size: 10, weight: .medium, design: .default)
    static let chartCross  = Font.system(size: 13, weight: .semibold, design: .rounded)
    static let chartMicro  = Font.system(size: 10, weight: .regular, design: .default)
}
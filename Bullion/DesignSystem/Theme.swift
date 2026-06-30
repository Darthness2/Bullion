import SwiftUI

// MARK: - Theme

/// Warm editorial theme built on a five-color palette:
///   2D3142 — charcoal (dark backgrounds, primary ink in light)
///   BFC0C0 — warm gray (light background, secondary text in dark)
///   FFFFFF — white (cards, surfaces)
///   EF8354 — coral (signature accent: buttons, tabs, charts, active states)
///   4F5D75 — slate (secondary text, structure)
/// Green/red remain reserved for price movement and P/L only.
/// Supports Light (warm gray + white cards) and Dark (deep charcoal).
enum Theme {
    enum Colors {
        // Backgrounds — pure black in dark, soft gray in light
        static let background       = adaptive(light: cBackgroundLight,        dark: cBackgroundDark)
        static let surface          = adaptive(light: cSurfaceLight,           dark: cSurfaceDark)
        static let surfaceElevated  = adaptive(light: cSurfaceElevatedLight,   dark: cSurfaceElevatedDark)

        // Structural — primary ink (text, fills, icons). White in dark, black in light.
        static let ink              = adaptive(light: cInkLight,              dark: cInkDark)
        static let inkSubtle        = adaptive(light: cInkSubtleLight,         dark: cInkSubtleDark)

        // Text
        static let textPrimary      = adaptive(light: cTextPrimaryLight,      dark: cTextPrimaryDark)
        static let textSecondary    = adaptive(light: cTextSecondaryLight,    dark: cTextSecondaryDark)
        static let textOnPrimary    = adaptive(light: cTextOnPrimaryLight,     dark: cTextOnPrimaryDark)

        // Accent — signature blue from the app icon. Used for brand moments:
        // primary buttons, active tab indicator, selected segments, chart line,
        // active states. NOT used for price movement (that's positive/negative).
        static let accent           = adaptive(light: cAccentLight,           dark: cAccentDark)
        static let accentBright     = adaptive(light: cAccentBrightLight,     dark: cAccentBrightDark)
        static let accentSoft        = adaptive(light: cAccentSoftLight,        dark: cAccentSoftDark)
        static let accentOnPrimary  = adaptive(light: cAccentOnPrimaryLight,   dark: cAccentOnPrimaryDark)

        // Semantic — price movement and P/L only
        static let positive         = adaptive(light: cPositiveLight,          dark: cPositiveDark)
        static let negative         = adaptive(light: cNegativeLight,          dark: cNegativeDark)
        static let positiveGlow     = adaptive(light: cPositiveLight.opacity(0.3), dark: cPositiveDark.opacity(0.4))
        static let negativeGlow     = adaptive(light: cNegativeLight.opacity(0.3), dark: cNegativeDark.opacity(0.4))

        // Subtle white/black overlay for the faint sheen on elevated cards
        static let sheen            = adaptive(light: Color.black.opacity(0.02), dark: Color.white.opacity(0.03))

        // Misc
        static let separator        = adaptive(light: cSeparatorLight,         dark: cSeparatorDark)
        static let shadow           = adaptive(light: cShadowLight,            dark: cShadowDark)
    }

    enum Metrics {
        static let cornerRadiusSmall: CGFloat = 10
        static let cornerRadius: CGFloat = 14
        static let cornerRadiusLarge: CGFloat = 18
        static let cardPadding: CGFloat = 18
        static let spacingXS: CGFloat = 4
        static let spacingS: CGFloat = 8
        static let spacing: CGFloat = 14
        static let spacingL: CGFloat = 22
        static let spacingXL: CGFloat = 32
        static let shadowRadius: CGFloat = 16
        static let shadowOpacity: Double = 0.10
        static let hairline: CGFloat = 0.5
        static let bottomSafeClearance: CGFloat = 40
        static let tabBarClearance: CGFloat = 88
        static let spacingM: CGFloat = 12
    }

    // MARK: - Animation

    /// Centralized motion curves. Physics-based springs (iOS 18 `.smooth`/`.bouncy`).
    /// Pull every animated property from here so the whole app moves with one voice.
    enum Animation {
        /// Tight, controlled — tab switches, segment picks, control state. No bounce.
        static let interactive = SwiftUI.Animation.smooth(duration: 0.32, extraBounce: 0.18)
        /// Lively tap response — buttons, cards, badges. Pleasant bounce.
        static let snappy = SwiftUI.Animation.bouncy(duration: 0.34, extraBounce: 0.20)
        /// Soft, patient — appear/stagger choreography, ambient motion.
        static let gentle = SwiftUI.Animation.smooth(duration: 0.5, extraBounce: 0.10)
        /// Expressive — hero zoom completion, celebratory pops.
        static let lively = SwiftUI.Animation.bouncy(duration: 0.45, extraBounce: 0.28)
        /// Slow, cinematic — chart draws, donut sweeps.
        static let slow = SwiftUI.Animation.smooth(duration: 0.7, extraBounce: 0.05)
    }

    // MARK: - Gradients

    enum Gradients {
        // Accent blue gradient for primary fills (buttons, bars, hero values)
        static let accentGradient = LinearGradient(
            colors: [Theme.Colors.accentBright, Theme.Colors.accent],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        // Accent-tinted soft fill for pills / selected backgrounds
        static let accentSoftGradient = LinearGradient(
            colors: [Theme.Colors.accent.opacity(0.16), Theme.Colors.accent.opacity(0.08)],
            startPoint: .top, endPoint: .bottom
        )
        // Monochrome ink gradient — retained for non-accent primary fills
        static let inkGradient = LinearGradient(
            colors: [Theme.Colors.ink, Theme.Colors.ink.opacity(0.85)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        // Subtle vertical background wash
        static let backgroundGradient = LinearGradient(
            colors: [Theme.Colors.background, Theme.Colors.surface.opacity(0.4)],
            startPoint: .top, endPoint: .bottom
        )
        // Hairline card border — thin white/black edge
        static let cardBorderGradient = LinearGradient(
            colors: [Theme.Colors.textPrimary.opacity(0.18), Theme.Colors.textPrimary.opacity(0.04)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        // Accent chart line fill
        static let accentLineFillGradient = LinearGradient(
            colors: [Theme.Colors.accent.opacity(0.20), Theme.Colors.accent.opacity(0)],
            startPoint: .top, endPoint: .bottom
        )
        // Sparkline / chart line fade (monochrome fallback)
        static let lineFillGradient = LinearGradient(
            colors: [Theme.Colors.textPrimary.opacity(0.18), Theme.Colors.textPrimary.opacity(0)],
            startPoint: .top, endPoint: .bottom
        )
        static let positiveGradient = LinearGradient(
            colors: [Theme.Colors.positive.opacity(0.18), Theme.Colors.positive.opacity(0.04)],
            startPoint: .top, endPoint: .bottom
        )
        static let negativeGradient = LinearGradient(
            colors: [Theme.Colors.negative.opacity(0.18), Theme.Colors.negative.opacity(0.04)],
            startPoint: .top, endPoint: .bottom
        )
    }

    // MARK: - Allocation palette (coral / slate / charcoal from the brand palette)

    /// Shades cycled across holding slices — adaptive per mode, drawn from the
    /// five-color brand palette (coral, slate, charcoal) rather than blue.
    static let monochromeScale: [Color] = [
        adaptive(light: Color(hex: 0xEF8354), dark: Color(hex: 0xEF8354)),
        adaptive(light: Color(hex: 0x4F5D75), dark: Color(hex: 0x6B7A92)),
        adaptive(light: Color(hex: 0x2D3142), dark: Color(hex: 0xBFC0C0)),
        adaptive(light: Color(hex: 0xC46A3E), dark: Color(hex: 0xF2A37A)),
        adaptive(light: Color(hex: 0x3B475C), dark: Color(hex: 0x8E9AB0)),
        adaptive(light: Color(hex: 0x5C6478), dark: Color(hex: 0xA8B0C0)),
        adaptive(light: Color(hex: 0x8088A0), dark: Color(hex: 0x6E7686)),
        adaptive(light: Color(hex: 0xBFC0C0), dark: Color(hex: 0x4F5D75)),
    ]
}

// MARK: - Adaptive color helper

private func adaptive(light: Color, dark: Color) -> Color {
    Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
    })
}

// MARK: - Hex initializer

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

// MARK: - Palette — Coral / Slate / Charcoal (5-color brand palette)

// Light — warm gray background, white cards, charcoal ink, slate secondary.
//   2D3142 charcoal, BFC0C0 warm gray, FFFFFF white, EF8354 coral, 4F5D75 slate
private let cBackgroundLight       = Color(hex: 0xBFC0C0)   // warm gray
private let cSurfaceLight          = Color(hex: 0xFFFFFF)   // white cards
private let cSurfaceElevatedLight  = Color(hex: 0xF4F4F4)   // faintly warm off-white
private let cInkLight              = Color(hex: 0x2D3142)   // charcoal
private let cInkSubtleLight        = Color(hex: 0x4F5D75)   // slate
private let cTextPrimaryLight      = Color(hex: 0x2D3142)   // charcoal
private let cTextSecondaryLight    = Color(hex: 0x4F5D75)   // slate
private let cTextOnPrimaryLight    = Color.white            // white on coral
private let cPositiveLight         = Color(hex: 0x2E8B57)   // sea green (AA on warm gray)
private let cNegativeLight          = Color(hex: 0xC0392B)   // red
private let cSeparatorLight        = Color(hex: 0xA9A9AC)   // warm gray hairline
private let cShadowLight           = Color(hex: 0x2D3142)   // charcoal shadow

// Dark — deep charcoal background, lifted charcoal surface, warm gray text.
// OLED-friendly while staying on-palette (no pure black, which felt cold
// next to coral). Elevated surface lifted for visible hierarchy.
private let cBackgroundDark        = Color(hex: 0x2D3142)   // charcoal
private let cSurfaceDark           = Color(hex: 0x363B52)   // lifted charcoal
private let cSurfaceElevatedDark   = Color(hex: 0x414763)   // further lifted
private let cInkDark              = Color(hex: 0xF5F5F7)   // near-white
private let cInkSubtleDark         = Color(hex: 0xBFC0C0)   // warm gray
private let cTextPrimaryDark       = Color(hex: 0xF5F5F7)   // near-white
private let cTextSecondaryDark     = Color(hex: 0xBFC0C0)   // warm gray
private let cTextOnPrimaryDark     = Color.white            // white on coral
private let cPositiveDark          = Color(hex: 0x34C77B)   // bright green
private let cNegativeDark          = Color(hex: 0xFF6B5A)   // bright red
private let cSeparatorDark         = Color(hex: 0x525A78)   // slate-tinted hairline
private let cShadowDark            = Color.black

// Accent — coral (#EF8354) from the brand palette. The signature color for
// primary buttons, active tab indicators, selected segments, the chart line,
// and active states. NOT used for price movement (that's positive/negative).
private let cAccentLight           = Color(hex: 0xEF8354)   // coral
private let cAccentBrightLight     = Color(hex: 0xF26B3A)   // brighter coral for gradient tops
private let cAccentSoftLight       = Color(hex: 0xF7D9C9)   // pale coral tint
private let cAccentOnPrimaryLight  = Color.white            // white on coral

private let cAccentDark            = Color(hex: 0xEF8354)   // coral (same in dark for brand consistency)
private let cAccentBrightDark      = Color(hex: 0xF29368)   // lighter coral for dark-mode gradient
private let cAccentSoftDark        = Color(hex: 0x4A2A1E)   // deep coral-tinted charcoal
private let cAccentOnPrimaryDark   = Color.white            // white on coral
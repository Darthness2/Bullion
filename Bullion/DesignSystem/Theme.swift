import SwiftUI

// MARK: - Theme

/// Minimalist monochrome theme with a signature blue accent drawn from the
/// app icon. Pure black/white/grayscale as the base; blue is the brand accent
/// (buttons, tab indicators, charts, active states). Green/red remain
/// reserved for price movement and P/L.
/// Supports Light (soft gray) and Dark (pure black, OLED-friendly).
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

    // MARK: - Allocation palette (blue-tinted grayscale)

    /// Blue-tinted shades cycled across holding slices — adaptive per mode.
    static let monochromeScale: [Color] = [
        adaptive(light: Color(hex: 0x002080), dark: Color(hex: 0x3B6FE0)),
        adaptive(light: Color(hex: 0x0030A0), dark: Color(hex: 0x5586E8)),
        adaptive(light: Color(hex: 0x0040B0), dark: Color(hex: 0x6B9BF0)),
        adaptive(light: Color(hex: 0x0050C0), dark: Color(hex: 0x80AFF5)),
        adaptive(light: Color(hex: 0x1C1C1E), dark: Color(hex: 0xC3D7F4)),
        adaptive(light: Color(hex: 0x3A3A3C), dark: Color(hex: 0xA8C2EA)),
        adaptive(light: Color(hex: 0x636366), dark: Color(hex: 0x8E8E93)),
        adaptive(light: Color(hex: 0xAEAEB2), dark: Color(hex: 0x48484A)),
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

// MARK: - Palette — Monochrome Black / White / Gray

// Light — soft gray background, black ink
private let cBackgroundLight       = Color(hex: 0xF5F5F7)
private let cSurfaceLight          = Color(hex: 0xFFFFFF)
private let cSurfaceElevatedLight  = Color(hex: 0xFAFAFA)
private let cInkLight              = Color(hex: 0x1C1C1E)
private let cInkSubtleLight        = Color(hex: 0x3A3A3C)
private let cTextPrimaryLight      = Color(hex: 0x1C1C1E)
private let cTextSecondaryLight    = Color(hex: 0x6E6E73)
private let cTextOnPrimaryLight    = Color.white
private let cPositiveLight         = Color(hex: 0x1E8E5A)
private let cNegativeLight          = Color(hex: 0xC0392B)
private let cSeparatorLight        = Color(hex: 0xD8D8DC)
private let cShadowLight           = Color(hex: 0x1C1C1E)

// Dark — pure black, OLED-friendly, white ink
private let cBackgroundDark        = Color(hex: 0x000000)
private let cSurfaceDark           = Color(hex: 0x0E0E0F)
private let cSurfaceElevatedDark   = Color(hex: 0x161617)
private let cInkDark              = Color(hex: 0xF5F5F7)
private let cInkSubtleDark         = Color(hex: 0xC7C7CC)
private let cTextPrimaryDark       = Color(hex: 0xF5F5F7)
private let cTextSecondaryDark     = Color(hex: 0x8A8A8E)
private let cTextOnPrimaryDark     = Color.black
private let cPositiveDark          = Color(hex: 0x34C77B)
private let cNegativeDark          = Color(hex: 0xFF5A4A)
private let cSeparatorDark         = Color(hex: 0x2A2A2D)
private let cShadowDark            = Color.black

// Accent — signature blue from the app icon (#012682 family)
// Deep royal blue in light; brighter for contrast in dark.
private let cAccentLight           = Color(hex: 0x012682)
private let cAccentBrightLight     = Color(hex: 0x0040B0)
private let cAccentSoftLight       = Color(hex: 0xC3D7F4)
private let cAccentOnPrimaryLight  = Color.white

private let cAccentDark            = Color(hex: 0x3B6FE0)
private let cAccentBrightDark      = Color(hex: 0x5586E8)
private let cAccentSoftDark        = Color(hex: 0x1A2F60)
private let cAccentOnPrimaryDark   = Color.white
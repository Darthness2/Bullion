import SwiftUI

// MARK: - Theme

/// Premium fintech "ink + emerald" theme. Deep emerald accent on near-black
/// ink — the look of a modernized trading terminal. Money/trust association
/// without being clinical.
///
///   Ink        #0B0F14 (light text) / #0B0F14 (dark bg)  — the base
///   Off-white  #F6F7F8 (light bg)   / #E6EDF3 (dark text) — the inverse
///   Emerald    #0E7C5A (light)      / #22C98B (dark)      — signature accent
///   Slate      #5B6770 (light)      / #8B97A3 (dark)      — secondary text
///   Electric   #3B82F6                                    — secondary chart/infow
///
/// Positive/negative (#17C390 / #FF6B5A) stay *visually distinct* from the
/// brand emerald so P/L never blurs into brand chrome.
/// Supports Light (off-white + white cards) and Dark (near-black, OLED-friendly).
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

    // MARK: - Allocation palette (emerald → slate → ink)

    /// Shades cycled across holding slices — adaptive per mode, drawn from the
    /// ink+emerald palette. The donut reads as a gradient from emerald
    /// (largest holding) through slate to ink, reinforcing brand identity.
    static let monochromeScale: [Color] = [
        adaptive(light: Color(hex: 0x0E7C5A), dark: Color(hex: 0x22C98B)),
        adaptive(light: Color(hex: 0x147D6B), dark: Color(hex: 0x3BD49A)),
        adaptive(light: Color(hex: 0x4F5D75), dark: Color(hex: 0x8B97A3)),
        adaptive(light: Color(hex: 0x3B82F6), dark: Color(hex: 0x60A5FA)),
        adaptive(light: Color(hex: 0x2D6E55), dark: Color(hex: 0x1FA874)),
        adaptive(light: Color(hex: 0x5B6770), dark: Color(hex: 0x6E7B88)),
        adaptive(light: Color(hex: 0x8B97A3), dark: Color(hex: 0x4A5563)),
        adaptive(light: Color(hex: 0xB6C2CC), dark: Color(hex: 0x2E3640)),
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

// MARK: - Palette — Ink + Emerald

// Light — off-white background, white cards, ink text, emerald accent.
//   #F6F7F8 off-white bg, #FFFFFF white cards, #0B0F14 ink, #0E7C5A emerald,
//   #5B6770 slate secondary. Warm but cool-leaning — a serious finance feel.
private let cBackgroundLight       = Color(hex: 0xF6F7F8)   // off-white
private let cSurfaceLight          = Color(hex: 0xFFFFFF)   // white cards
private let cSurfaceElevatedLight  = Color(hex: 0xFCFDFE)   // faint cool off-white
private let cInkLight              = Color(hex: 0x0B0F14)   // ink
private let cInkSubtleLight        = Color(hex: 0x2D3640)   // lifted ink
private let cTextPrimaryLight      = Color(hex: 0x0B0F14)   // ink
private let cTextSecondaryLight    = Color(hex: 0x5B6770)   // slate
private let cTextOnPrimaryLight    = Color.white            // white on emerald
// P/L stays visually distinct from the brand emerald — brighter, more saturated,
// so "did I make money?" never blurs into "is this a brand button?".
private let cPositiveLight         = Color(hex: 0x17A36A)   // bright finance green
private let cNegativeLight         = Color(hex: 0xE5484D)   // bright finance red
private let cSeparatorLight        = Color(hex: 0xDDE2E8)   // cool gray hairline
private let cShadowLight           = Color(hex: 0x0B0F14)   // ink shadow

// Dark — near-black ink background with a faint blue undertone (more "terminal"
// than pure #000), lifted ink surface, near-white text, bright emerald accent.
// OLED-friendly. Elevated surface lifted for visible hierarchy.
private let cBackgroundDark        = Color(hex: 0x0B0F14)   // near-black ink
private let cSurfaceDark           = Color(hex: 0x11171F)   // lifted ink
private let cSurfaceElevatedDark   = Color(hex: 0x161B22)   // further lifted
private let cInkDark              = Color(hex: 0xE6EDF3)   // near-white
private let cInkSubtleDark         = Color(hex: 0xB6C2CC)   // cool gray
private let cTextPrimaryDark       = Color(hex: 0xE6EDF3)   // near-white
private let cTextSecondaryDark     = Color(hex: 0x8B97A3)   // slate
private let cTextOnPrimaryDark     = Color(hex: 0x04130D)   // deep emerald-black on bright emerald
private let cPositiveDark          = Color(hex: 0x22C98B)   // bright emerald-green
private let cNegativeDark          = Color(hex: 0xFF6B5A)   // bright red
private let cSeparatorDark         = Color(hex: 0x1F2A37)   // ink-tinted hairline
private let cShadowDark            = Color.black

// Accent — deep emerald in light (#0E7C5A), bright emerald in dark (#22C98B).
// The signature color for primary buttons, active tab indicators, selected
// segments, the chart line, and active states. Distinct from P/L green.
private let cAccentLight           = Color(hex: 0x0E7C5A)   // deep emerald
private let cAccentBrightLight     = Color(hex: 0x13946E)   // brighter emerald for gradient tops
private let cAccentSoftLight       = Color(hex: 0xD6F0E5)   // pale emerald tint
private let cAccentOnPrimaryLight  = Color.white            // white on emerald

private let cAccentDark            = Color(hex: 0x22C98B)   // bright emerald (pops on near-black)
private let cAccentBrightDark      = Color(hex: 0x3BD49A)   // lighter emerald for dark gradient
private let cAccentSoftDark        = Color(hex: 0x0E2A22)   // deep emerald-tinted ink
private let cAccentOnPrimaryDark   = Color(hex: 0x04130D)   // deep emerald-black on bright emerald
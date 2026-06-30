import SwiftUI

/// Minimalist card with a two-tier elevation system.
///   - Flat (default): surface + hairline border, no shadow. For list rows
///     and dense content where hierarchy comes from layout, not depth.
///   - Elevated (`elevated: true`): surface + soft emerald-tinted shadow +
///     emerald gradient border. For hero/CTA containers that should lift
///     off the background — the signature "premium" depth cue.
/// No glassmorphism. The base container for all content.
struct ThemedCard<Content: View>: View {
    var padding: CGFloat = Theme.Metrics.cardPadding
    var cornerRadius: CGFloat = Theme.Metrics.cornerRadius
    var elevated: Bool = false
    var glow: Bool = false   // retained for API stability; subtle white sheen only
    var scrollTransition: Bool = false  // opt-in parallax/tilt inside scroll views
    @ViewBuilder var content: Content

    var body: some View {
        Group {
            if scrollTransition {
                baseView
                    .scrollTransition { v, phase in
                        v.scaleEffect(phase.isIdentity ? 1 : 0.96)
                         .opacity(phase.isIdentity ? 1 : 0.85)
                    }
            } else {
                baseView
            }
        }
    }

    private var baseView: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(elevated ? Theme.Colors.surfaceElevated : Theme.Colors.surface)
            )
            .overlay(
                // Border — hairline for flat tier, emerald gradient for elevated.
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(elevated ? Theme.Gradients.elevatedBorderGradient : Theme.Gradients.cardBorderGradient,
                            lineWidth: Theme.Metrics.hairline)
            )
            // Shadow only on the elevated tier — flat cards stay flat so the
            // hierarchy reads cleanly without everything floating.
            .shadow(color: elevated ? Theme.Colors.accentShadow : .clear,
                    radius: elevated ? Theme.Metrics.shadowRadius : 0, x: 0, y: 6)
            .overlay(
                // Optional faint sheen for highlighted cards
                Group {
                    if glow {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Theme.Colors.sheen, lineWidth: Theme.Metrics.hairline)
                            .allowsHitTesting(false)
                    }
                }
            )
    }
}
import SwiftUI

/// Minimalist card — single surface fill, hairline border, soft shadow.
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
                // Hairline border
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.Gradients.cardBorderGradient, lineWidth: Theme.Metrics.hairline)
            )
            .shadow(color: Theme.Colors.shadow.opacity(Theme.Metrics.shadowOpacity),
                    radius: Theme.Metrics.shadowRadius, x: 0, y: 6)
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
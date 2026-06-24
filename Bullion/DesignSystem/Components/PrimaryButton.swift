import SwiftUI

/// Primary CTA button — monochrome fills with refined press animation + haptics.
struct PrimaryButton: View {
    enum Style {
        case primary   // solid ink (white-in-dark / black-in-light)
        case gold      // alias of .primary — kept for API stability (key CTAs)
        case outline   // hairline border
        case danger    // red for destructive
    }

    let title: String
    let style: Style
    var icon: String? = nil
    var isLoading: Bool = false
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Metrics.spacingS) {
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                        .scaleEffect(0.9)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(Typography.headline)
                    .tracking(0.3)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundColor(foregroundColor)
            .background(backgroundView)
            .overlay(borderView)
            .shadow(color: glowColor.opacity(isPressed ? 0.05 : 0.18),
                    radius: isPressed ? 2 : 10, x: 0, y: 0)
            .scaleEffect(isPressed ? 0.975 : 1.0)
            .animation(Theme.Animation.snappy, value: isPressed)
            .symbolEffect(.bounce, value: isLoading)
            .contentTransition(.symbolEffect(.replace))
        }
        .disabled(isLoading)
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed { Haptics.light() }
                    isPressed = true
                }
                .onEnded { _ in isPressed = false }
        )
    }

    private var foregroundColor: Color {
        switch style {
        case .primary, .gold:  return Theme.Colors.textOnPrimary
        case .outline:          return Theme.Colors.textPrimary
        case .danger:           return .white
        }
    }

    @ViewBuilder private var backgroundView: some View {
        switch style {
        case .primary, .gold:
            Theme.Gradients.accentGradient
        case .danger:
            LinearGradient(colors: [Theme.Colors.negative, Theme.Colors.negative.opacity(0.85)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case .outline:
            Color.clear
        }
    }

    @ViewBuilder private var borderView: some View {
        if style == .outline {
            RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                .stroke(Theme.Colors.accent.opacity(0.6), lineWidth: Theme.Metrics.hairline)
        }
    }

    private var glowColor: Color {
        switch style {
        case .primary, .gold, .outline: return Theme.Colors.accent
        case .danger:                    return Theme.Colors.negative
        }
    }
}
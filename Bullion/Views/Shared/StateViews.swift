import SwiftUI

/// Minimal empty state — monochrome icon, subtle message, optional action.
struct EmptyStateView: View {
    var icon: String = "tray"
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Theme.Metrics.spacing) {
            Image(systemName: icon)
                .font(.system(size: 42, weight: .light))
                .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
                .symbolEffect(.pulse, options: .repeating)
            Text(message)
                .font(Typography.subheadline)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                PrimaryButton(title: actionTitle, style: .outline, icon: nil, action: action)
                    .frame(maxWidth: 220)
                    .padding(.top, Theme.Metrics.spacingS)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Metrics.spacingXL)
        .transition(.scale(scale: 0.96).combined(with: .opacity))
    }
}

/// Error state with a retry action. Red is the only color permitted here.
struct ErrorView: View {
    let message: String
    let retry: (() -> Void)?

    var body: some View {
        VStack(spacing: Theme.Metrics.spacing) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 38, weight: .light))
                .foregroundColor(Theme.Colors.negative)
                .glow(Theme.Colors.negative, radius: 14, opacity: 0.25)
                .symbolEffect(.bounce, value: message)
            Text(message)
                .font(Typography.subheadline)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            if let retry {
                PrimaryButton(title: "Retry", style: .outline, icon: "arrow.clockwise", action: retry)
                    .frame(maxWidth: 200)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Metrics.spacingXL)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }
}

/// Minimal loading indicator — two counter-rotating monochrome rings.
/// Uses `TimelineView` for a GPU-cheap, perfectly smooth infinite spin.
struct GlowLoadingView: View {
    var body: some View {
        VStack(spacing: Theme.Metrics.spacing) {
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(Theme.Gradients.accentGradient,
                                style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 36, height: 36)
                        .rotationEffect(.degrees(t * 90))
                    Circle()
                        .trim(from: 0, to: 0.45)
                        .stroke(Theme.Colors.accent.opacity(0.35),
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        .frame(width: 24, height: 24)
                        .rotationEffect(.degrees(-t * 140))
                }
            }
            Text("Loading…")
                .font(Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Metrics.spacingXL)
    }
}
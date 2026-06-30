import SwiftUI

/// Section title with a solid emerald accent bar and optional trailing action.
struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            // Emerald accent bar — decorative, hidden from VoiceOver.
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Theme.Gradients.accentGradient)
                .frame(width: 3, height: 16)
                .transition(.scale.combined(with: .opacity))
                .accessibilityHidden(true)

            Text(title)
                .font(Typography.headline)
                .foregroundColor(Theme.Colors.textPrimary)
                .tracking(0.3)

            Spacer()

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .textCase(.uppercase)
                    .symbolEffect(.bounce, value: actionTitle)
            }
        }
    }
}
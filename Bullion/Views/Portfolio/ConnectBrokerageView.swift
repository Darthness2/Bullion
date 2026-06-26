import SwiftUI

/// Dedicated brokerage-connect onboarding screen. Guided trust steps then
/// the connect CTA. No developer-facing health check — failures surface a
/// user-friendly error with retry.
struct ConnectBrokerageView: View {
    @Bindable var vm: PortfolioViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Metrics.spacingL) {
                ThemedCard {
                    VStack(spacing: Theme.Metrics.spacing) {
                        Image("BrandIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: Theme.Colors.accent.opacity(0.25), radius: 14, x: 0, y: 6)
                        Text("Connect your brokerage")
                            .font(Typography.title2)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text("See your live holdings, balances, and performance across all your accounts.")
                            .font(Typography.body)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
                .appearAnimation(.scale)

                // Guided trust steps — what happens when you tap Connect.
                VStack(spacing: Theme.Metrics.spacingS) {
                    trustStep(icon: "lock.shield.fill",
                              title: "Secure OAuth via SnapTrade",
                              sub: "Bullion never sees your credentials.")
                    trustStep(icon: "eye.fill",
                              title: "Read-only access",
                              sub: "We fetch holdings and transactions. No trading.")
                    trustStep(icon: "arrow.clockwise",
                              title: "Syncs automatically",
                              sub: "Pull to refresh anytime.")
                }
                .appearAnimation(.rise, index: 1)

                PrimaryButton(
                    title: vm.isConnecting ? "Connecting…" : "Connect Account",
                    style: .primary,
                    icon: "lock.shield",
                    isLoading: vm.isConnecting
                ) {
                    Task { await vm.connect() }
                }
                .disabled(vm.isConnecting)
                .appearAnimation(.rise, index: 2)

                if let err = vm.connectError {
                    HStack(spacing: Theme.Metrics.spacingS) {
                        Text(err)
                            .font(Typography.caption)
                            .foregroundColor(Theme.Colors.negative)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            Task { await vm.connect() }
                        } label: {
                            Label("Retry", systemImage: "arrow.clockwise")
                                .font(Typography.caption)
                                .foregroundColor(Theme.Colors.textPrimary)
                        }
                        .buttonStyle(.plain)
                        .symbolEffect(.bounce, value: vm.connectError != nil)
                    }
                    .padding(Theme.Metrics.spacingS)
                    .background(Theme.Colors.negative.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusSmall, style: .continuous))
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }

                Text("Bullion never stores your brokerage credentials. SnapTrade handles the connection securely.")
                    .font(Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, Theme.Metrics.spacingS)
            }
            .padding(Theme.Metrics.spacingL)
            .padding(.bottom, Theme.Metrics.bottomSafeClearance)
        }
        .background(
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                RadialGradient(
                    colors: [Theme.Colors.accent.opacity(0.04), .clear],
                    center: .top, startRadius: 10, endRadius: 350
                )
                .ignoresSafeArea()
            }
        )
    }

    private func trustStep(icon: String, title: String, sub: String) -> some View {
        HStack(spacing: Theme.Metrics.spacing) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Theme.Colors.accent)
                .frame(width: 36, height: 36)
                .background(Theme.Colors.accent.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.subheadline)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(sub)
                    .font(Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Metrics.spacingS)
        .padding(.vertical, 10)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                .stroke(Theme.Gradients.cardBorderGradient, lineWidth: Theme.Metrics.hairline)
        )
    }
}
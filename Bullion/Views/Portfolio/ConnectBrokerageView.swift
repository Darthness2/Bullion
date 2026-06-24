import SwiftUI

/// Dedicated brokerage-connect onboarding screen. Shown when the user has
/// not yet linked a brokerage. Multi-step: explainer → connect → progress →
/// (success auto-routes to the dashboard) / error with retry + health check.
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
                        Text("Securely link your brokerage accounts via SnapTrade to see live holdings, balances, and performance. Read-only — no trading.")
                            .font(Typography.body)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .multilineTextAlignment(.center)

                        BackendHealthView()
                            .padding(.top, Theme.Metrics.spacingS)

                        PrimaryButton(
                            title: vm.isConnecting ? "Connecting…" : "Connect Account",
                            style: .primary,
                            icon: "lock.shield",
                            isLoading: vm.isConnecting
                        ) {
                            Task { await vm.connect() }
                        }
                        .padding(.top, Theme.Metrics.spacingS)
                        .disabled(vm.isConnecting)

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
                            .padding(.top, Theme.Metrics.spacingS)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .appearAnimation(.scale)

                Text("Bullion never stores your brokerage credentials. SnapTrade handles the connection securely.")
                    .font(Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(Theme.Metrics.spacingL)
        }
        .background(
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                RadialGradient(
                    colors: [Theme.Colors.textPrimary.opacity(0.04), .clear],
                    center: .top, startRadius: 10, endRadius: 350
                )
                .ignoresSafeArea()
            }
        )
    }
}
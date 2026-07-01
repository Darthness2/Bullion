import SwiftUI

/// Dedicated brokerage-connect onboarding screen. Uses Plaid Link for
/// secure OAuth-based broker connection. The thin backend handles only
/// the token exchange; all data calls go directly from the device to Plaid.
struct ConnectBrokerageView: View {
    @Bindable var vm: PortfolioViewModel
    @Environment(AppNav.self) private var appNav
    @State private var showingSettings = false

    private var hasBackend: Bool {
        !PlaidKeyStore.backendURL.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var buttonTitle: String {
        if vm.isConnecting { return "Connecting…" }
        return hasBackend ? "Connect Account" : "Set Up Backend"
    }

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
                        Text("Link Fidelity, Schwab, Robinhood, E*TRADE, Vanguard, and more via Plaid's secure OAuth.")
                            .font(Typography.body)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
                .appearAnimation(.scale)

                VStack(spacing: Theme.Metrics.spacingS) {
                    trustStep(icon: "lock.shield.fill",
                              title: "Secure OAuth via Plaid",
                              sub: "Bullion never sees your credentials.")
                    trustStep(icon: "eye.fill",
                              title: "Read-only access",
                              sub: "We fetch holdings and transactions. No trading.")
                    trustStep(icon: "arrow.clockwise",
                              title: "Syncs automatically",
                              sub: "Pull to refresh anytime.")
                }
                .appearAnimation(.rise, index: 1)

                VStack(spacing: Theme.Metrics.spacingS) {
                    BackendHealthView()
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !hasBackend {
                        PrimaryButton(
                            title: "Set Up Backend URL",
                            style: .outline,
                            icon: "server.rack"
                        ) {
                            appNav.selectedTab = .settings
                        }
                    }
                }
                .appearAnimation(.rise, index: 2)

                PrimaryButton(
                    title: buttonTitle,
                    style: .primary,
                    icon: hasBackend ? "link" : "server.rack",
                    isLoading: vm.isConnecting
                ) {
                    if hasBackend {
                        Task { await vm.connect() }
                    } else {
                        showingSettings = true
                    }
                }
                .disabled(vm.isConnecting)
                .appearAnimation(.rise, index: 3)

                if !hasBackend {
                    Text("First time? Enter the URL of your Plaid backend server in Settings → Brokerage.")
                        .font(Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }

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

                Text("Bullion never stores your brokerage credentials. Plaid handles the connection securely — your credentials are entered directly with Plaid and your broker.")
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
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                PlaidSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingSettings = false }
                        }
                    }
            }
        }
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
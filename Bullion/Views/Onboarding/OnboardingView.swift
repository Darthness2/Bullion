import SwiftUI

/// First-launch onboarding. A paged TabView with 4 intro screens; the last
/// offers an optional "Connect brokerage" step. "Get started" sets the
/// `hasOnboarded` UserDefaults flag and swaps to RootView.
struct OnboardingView: View {
    @Environment(AppNav.self) private var appNav
    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "chart.line.uptrend",
            title: "Welcome to Bullion",
            body: "A minimalist companion for tracking stocks, ETFs, and futures. Browse markets, build a watchlist, and stay informed — no noise."
        ),
        OnboardingPage(
            icon: "hand.raised",
            title: "Privacy first",
            body: "Your watchlist and preferences live on your device. When you link a brokerage, SnapTrade handles the secure connection — Bullion never sees your credentials."
        ),
        OnboardingPage(
            icon: "star",
            title: "Track what matters",
            body: "Tap the star on any instrument to add it to your Watchlist. Get quotes, charts, key stats, and optional AI research for anything you follow."
        ),
        OnboardingPage(
            icon: "briefcase",
            title: "Connect your portfolio",
            body: "Link a brokerage to see live holdings, balances, and performance across all your accounts. Optional — you can do this later from the Portfolio tab."
        ),
    ]

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            RadialGradient(
                colors: [Theme.Colors.textPrimary.opacity(0.05), .clear],
                center: .top, startRadius: 10, endRadius: 400
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { i in
                        pageView(pages[i], isLast: i == pages.count - 1)
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .indexViewStyle(.page(backgroundDisplayMode: .interactive))

                VStack(spacing: Theme.Metrics.spacing) {
                    pageDots
                    primaryButton
                }
                .padding(.horizontal, Theme.Metrics.spacingL)
                .padding(.bottom, Theme.Metrics.spacingXL)
            }
        }
        .animation(Theme.Animation.interactive, value: page)
    }

    private func pageView(_ page: OnboardingPage, isLast: Bool) -> some View {
        VStack(spacing: Theme.Metrics.spacingL) {
            Spacer()
            if page.icon == "chart.line.uptrend" {
                // First page — show the app icon
                Image("BrandIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: Theme.Colors.accent.opacity(0.3), radius: 20, x: 0, y: 8)
                    .symbolEffect(.bounce, value: self.page)
            } else {
                Image(systemName: page.icon)
                    .font(.system(size: 64, weight: .light))
                    .foregroundColor(Theme.Colors.accent)
                    .symbolEffect(.bounce, value: self.page)
            }
            Text(page.title)
                .font(Typography.title)
                .foregroundColor(Theme.Colors.textPrimary)
            Text(page.body)
                .font(Typography.body)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Metrics.spacingL)
            Spacer()
            if isLast {
                Button {
                    Haptics.selection()
                    appNav.selectedTab = .portfolio
                    finishOnboarding()
                } label: {
                    Text("Connect brokerage")
                        .font(Typography.headline)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                                .stroke(Theme.Colors.textPrimary.opacity(0.55), lineWidth: Theme.Metrics.hairline)
                        )
                }
                .buttonStyle(.plain)
                .pressScale()
                .padding(.horizontal, Theme.Metrics.spacingL)
            }
            Spacer()
                .frame(height: 40)
        }
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(pages.indices, id: \.self) { i in
                Circle()
                    .fill(i == page ? Theme.Colors.accent : Theme.Colors.textPrimary.opacity(0.2))
                    .frame(width: 7, height: 7)
                    .animation(Theme.Animation.interactive, value: page)
            }
        }
    }

    private var primaryButton: some View {
        PrimaryButton(
            title: page == pages.count - 1 ? "Get started" : "Continue",
            style: .primary,
            icon: page == pages.count - 1 ? "checkmark" : "arrow.right"
        ) {
            if page < pages.count - 1 {
                withAnimation(Theme.Animation.interactive) { self.page += 1 }
            } else {
                Haptics.success()
                appNav.selectedTab = .markets
                finishOnboarding()
            }
        }
    }

    private func finishOnboarding() {
        withAnimation(Theme.Animation.interactive) {
            UserDefaults.standard.set(true, forKey: "hasOnboarded")
        }
    }
}

private struct OnboardingPage {
    let icon: String
    let title: String
    let body: String
}
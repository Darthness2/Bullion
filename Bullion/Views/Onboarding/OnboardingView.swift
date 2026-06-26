import SwiftUI

/// First-launch onboarding. 3 pages: Welcome → Privacy & Control → Connect
/// (optional). "Get started" sets the `hasOnboarded` flag and swaps to
/// RootView. "Connect a brokerage first" is a secondary text link.
struct OnboardingView: View {
    @Environment(AppNav.self) private var appNav
    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "chart.line.uptrend",
            title: "Welcome to Bullion",
            body: "A minimalist companion for tracking stocks, ETFs, and futures. Browse markets, build a watchlist, and stay informed — no noise. Market data may be delayed by 15 minutes."
        ),
        OnboardingPage(
            icon: "hand.raised",
            title: "Privacy & control",
            body: "Your watchlist and preferences live on your device. When you link a brokerage, SnapTrade handles the secure connection — Bullion never sees your credentials."
        ),
        OnboardingPage(
            icon: "briefcase",
            title: "Connect your portfolio",
            body: "Link a brokerage to see live holdings, balances, and performance. Optional — you can do this anytime from the Portfolio tab."
        ),
    ]

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            RadialGradient(
                colors: [Theme.Colors.accent.opacity(0.06), .clear],
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
                    if page == pages.count - 1 {
                        Button {
                            Haptics.selection()
                            appNav.selectedTab = .portfolio
                            finishOnboarding()
                        } label: {
                            Text("Connect a brokerage first →")
                                .font(Typography.subheadline)
                                .foregroundColor(Theme.Colors.accent)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, Theme.Metrics.spacingL)
                .padding(.bottom, Theme.Metrics.spacingXL)
                .animation(Theme.Animation.interactive, value: page)
            }
        }
        .animation(Theme.Animation.interactive, value: page)
    }

    private func pageView(_ p: OnboardingPage, isLast: Bool) -> some View {
        VStack(spacing: Theme.Metrics.spacingL) {
            Spacer()
            if p.icon == "chart.line.uptrend" {
                Image("BrandIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: Theme.Colors.accent.opacity(0.3), radius: 20, x: 0, y: 8)
                    .symbolEffect(.bounce, value: page == 0)
            } else {
                Image(systemName: p.icon)
                    .font(.system(size: 64, weight: .light))
                    .foregroundColor(Theme.Colors.accent)
                    .symbolEffect(.bounce, value: page)
            }
            Text(p.title)
                .font(Typography.title)
                .foregroundColor(Theme.Colors.textPrimary)
            Text(p.body)
                .font(Typography.body)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Metrics.spacingL)
            Spacer()
        }
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(pages.indices, id: \.self) { i in
                Capsule()
                    .fill(i == page ? Theme.Colors.accent : Theme.Colors.textPrimary.opacity(0.2))
                    .frame(width: i == page ? 20 : 7, height: 7)
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
                appNav.selectedTab = .portfolio
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
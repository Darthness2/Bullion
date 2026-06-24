import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.appEnv) private var env
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNav.self) private var appNav
    @State private var watchlistVM: WatchlistViewModel?
    @Namespace private var tabNamespace

    private let tabs: [(title: String, icon: String)] = [
        ("Markets", "chart.line.uptrend"),
        ("Search", "magnifyingglass"),
        ("Portfolio", "briefcase.fill"),
        ("Settings", "gearshape"),
        ("Watchlist", "star"),
    ]

    var body: some View {
        if let watchlistVM {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                TabView(selection: Binding(
                    get: { appNav.selectedTab.rawValue },
                    set: { appNav.selectedTab = AppNav.Tab(rawValue: $0) ?? .markets }
                )) {
                    MarketsView().tag(AppNav.Tab.markets.rawValue)
                    SearchView().tag(AppNav.Tab.search.rawValue)
                    PortfolioView().tag(AppNav.Tab.portfolio.rawValue)
                    SettingsView().tag(AppNav.Tab.settings.rawValue)
                    WatchlistView().tag(AppNav.Tab.watchlist.rawValue)
                }
                .environment(watchlistVM)
                .overlay(alignment: .bottom) { customTabBar }
            }
        } else {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                GlowLoadingView()
            }
            .onAppear {
                watchlistVM = WatchlistViewModel(
                    provider: env.marketProvider,
                    modelContext: modelContext
                )
            }
        }
    }

    // MARK: - Custom tab bar with sliding indicator

    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { i in
                tabButton(index: i, title: tabs[i].title, icon: tabs[i].icon)
            }
        }
        .padding(.horizontal, Theme.Metrics.spacingS)
        .padding(.top, Theme.Metrics.spacingS)
        .padding(.bottom, Theme.Metrics.spacingS)
        .background(
            Theme.Colors.surface
                .overlay(Rectangle().fill(Theme.Colors.separator).frame(height: Theme.Metrics.hairline),
                         alignment: .top)
                .shadow(color: Theme.Colors.shadow.opacity(0.20),
                        radius: 16, x: 0, y: -6)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabButton(index: Int, title: String, icon: String) -> some View {
        let isSelected = appNav.selectedTab.rawValue == index
        return Button {
            Haptics.selection()
            withAnimation(Theme.Animation.interactive) {
                appNav.selectedTab = AppNav.Tab(rawValue: index) ?? .markets
            }
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(Theme.Gradients.accentGradient)
                            .matchedGeometryEffect(id: "tabIndicator", in: tabNamespace)
                            .frame(width: 24, height: 3)
                            .padding(.bottom, 6)
                    }
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? Theme.Colors.accent : Theme.Colors.textSecondary)
                        .symbolEffect(.bounce, value: isSelected)
                        .padding(.bottom, isSelected ? 9 : 6)
                }
                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Theme.Colors.accent : Theme.Colors.textSecondary)
                    .tracking(0.3)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(Theme.Animation.interactive, value: appNav.selectedTab)
    }
}
import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.appEnv) private var env
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNav.self) private var appNav
    @State private var watchlistVM: WatchlistViewModel?

    var body: some View {
        if let watchlistVM {
            TabView(selection: Binding(
                get: { appNav.selectedTab.rawValue },
                set: { appNav.selectedTab = AppNav.Tab(rawValue: $0) ?? .portfolio }
            )) {
                MarketsView()
                    .tabItem { Label("Markets", systemImage: "chart.line.uptrend") }
                    .tag(AppNav.Tab.markets.rawValue)

                WatchlistView()
                    .tabItem { Label("Watchlist", systemImage: "star") }
                    .tag(AppNav.Tab.watchlist.rawValue)

                SearchView()
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
                    .tag(AppNav.Tab.search.rawValue)

                PortfolioView()
                    .tabItem { Label("Portfolio", systemImage: "briefcase.fill") }
                    .tag(AppNav.Tab.portfolio.rawValue)

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                    .tag(AppNav.Tab.settings.rawValue)
            }
            .tint(Theme.Colors.accent)
            .environment(watchlistVM)
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
}
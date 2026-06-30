import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.appEnv) private var env
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppNav.self) private var appNav
    @Environment(ConnectivityMonitor.self) private var connectivity
    @State private var watchlistVM: WatchlistViewModel?

    var body: some View {
        if let watchlistVM {
            VStack(spacing: 0) {
                OfflineBanner()
                    .animation(Theme.Animation.interactive, value: connectivity.isOnline)
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
                // On iPad, use the sidebar tab style so the five tabs become a
                // persistent sidebar (regular size class) instead of a cramped
                // bottom bar — the phone-width layout was leaving vast empty
                // space on iPad landscape. Falls back to the bottom bar on
                // compact widths (iPhone) automatically.
                .tabViewStyle(.sidebarAdaptable)
                .tint(Theme.Colors.accent)
                .environment(watchlistVM)
            }
            .onChange(of: scenePhase) { _, phase in
                // Check price alerts whenever the app returns to the
                // foreground — the cheapest backend-less way to deliver
                // "your stock crossed X" notifications. Local notifications
                // only; no push tokens.
                if phase == .active {
                    Task { @MainActor in
                        await AlertService.shared.checkAlerts(
                            provider: env.marketProvider, modelContext: modelContext
                        )
                    }
                }
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
}
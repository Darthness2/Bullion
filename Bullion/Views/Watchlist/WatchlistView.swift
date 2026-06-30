import SwiftUI

struct WatchlistView: View {
    @Environment(\.appEnv) private var env
    @Environment(WatchlistViewModel.self) private var watchlistVM
    @Environment(AppNav.self) private var appNav
    @State private var path = NavigationPath()
    @Namespace private var heroNamespace

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Watchlist")
                .navigationDestination(for: Instrument.self) { instrument in
                    InstrumentDetailView(instrument: instrument)
                        .navigationTransition(.zoom(sourceID: instrument.id, in: heroNamespace))
                }
        }
    }

    @ViewBuilder private var content: some View {
        if watchlistVM.items.isEmpty {
            EmptyStateView(
                icon: "star",
                message: "Your watchlist is empty. Search for instruments and tap the star to add them.",
                actionTitle: "Search instruments",
                action: { withAnimation(Theme.Animation.interactive) { appNav.selectedTab = .search } }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Colors.background)
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        } else {
            list
                .transition(.opacity)
        }
    }

    private var list: some View {
        List {
            ForEach(Array(watchlistVM.items.enumerated()), id: \.element.id) { idx, instrument in
                NavigationLink(value: instrument) {
                    InstrumentRow(
                        instrument: instrument,
                        quote: watchlistVM.quotes[instrument.symbol]
                    )
                }
                .buttonStyle(.plain)
                .matchedTransitionSource(id: instrument.id, in: heroNamespace)
                .listRowBackground(Color.clear)
                .listRowSeparatorTint(Theme.Colors.separator)
                .staggeredAppear(index: idx)
            }
            .onMove { source, dest in watchlistVM.move(from: source, to: dest) }
            .onDelete { indexSet in watchlistVM.remove(atOffsets: indexSet) }
        }
        .listStyle(.plain)
        .background(Theme.Colors.background)
        .scrollContentBackground(.hidden)
        .refreshable { await watchlistVM.refreshQuotes() }
        .tint(Theme.Colors.accent)   // emerald pull-to-refresh control
        .toolbar {
            EditButton()
        }
        .task { await watchlistVM.refreshQuotes() }
    }
}
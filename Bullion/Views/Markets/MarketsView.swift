import SwiftUI

struct MarketsView: View {
    @Environment(\.appEnv) private var env
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppNav.self) private var appNav
    @State private var vm: MarketsViewModel?
    @State private var path = NavigationPath()
    @Namespace private var heroNamespace
    @Namespace private var pickerNamespace

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Bullion")
                .navigationBarTitleDisplayMode(.large)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar { refreshMenu }
                .navigationDestination(for: Instrument.self) { instrument in
                    InstrumentDetailView(instrument: instrument)
                        .navigationTransition(.zoom(sourceID: instrument.id, in: heroNamespace))
                }
        }
    }

    @ViewBuilder private var content: some View {
        if let vm {
            ScrollView {
                VStack(spacing: Theme.Metrics.spacingL) {
                    segmentPicker
                    summaryStrip(vm: vm)
                    sectionedList(vm: vm)
                }
                .padding(.horizontal, Theme.Metrics.spacingL)
                .padding(.bottom, Theme.Metrics.spacingXL)
            }
            .background(
                ZStack {
                    Theme.Colors.background.ignoresSafeArea()
                    // Subtle monochrome wash at top
                    RadialGradient(
                        colors: [Theme.Colors.textPrimary.opacity(0.04), .clear],
                        center: .top, startRadius: 10, endRadius: 320
                    )
                    .ignoresSafeArea()
                }
            )
            .refreshable { await vm.refresh() }
            .task {
                let interval = SettingsViewModel.RefreshInterval(
                    rawValue: UserDefaults.standard.integer(forKey: "refreshInterval")
                ) ?? .fifteenSec
                vm.startAutoRefresh(intervalSeconds: interval.rawValue)
                await vm.load()
            }
            .onDisappear { vm.stopAutoRefresh() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    let interval = SettingsViewModel.RefreshInterval(
                        rawValue: UserDefaults.standard.integer(forKey: "refreshInterval")
                    ) ?? .fifteenSec
                    vm.startAutoRefresh(intervalSeconds: interval.rawValue)
                } else {
                    vm.stopAutoRefresh()
                }
            }
        } else {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                GlowLoadingView()
            }
            .onAppear {
                vm = MarketsViewModel(provider: env.marketProvider, quoteCache: env.quoteCache)
            }
        }
    }

    private var segmentPicker: some View {
        SegmentedPill(
            options: MarketsViewModel.Segment.allCases,
            selection: Binding(
                get: { vm?.segment ?? .stocks },
                set: { vm?.segment = $0 }
            ),
            namespace: pickerNamespace
        )
        .padding(.top, Theme.Metrics.spacingS)
    }

    @ViewBuilder
    private func summaryStrip(vm: MarketsViewModel) -> some View {
        switch vm.headlineQuotes {
        case .idle, .loading:
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Metrics.spacingS) {
                    ForEach(0..<5, id: \.self) { _ in
                        SkeletonSummaryCard()
                    }
                }
            }
        case .empty:
            EmptyStateView(message: "No headline data available.") {
                Task { await vm.loadHeadlines() }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .failed(let msg):
            ErrorView(message: msg) { Task { await vm.loadHeadlines() } }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .loaded(let quotes):
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Metrics.spacingS) {
                    ForEach(Array(quotes.enumerated()), id: \.element.symbol) { idx, q in
                        if let instrument = vm.headlineInstruments.first(where: { $0.symbol == q.symbol }) {
                            NavigationLink(value: instrument) {
                                SummaryCard(
                                    instrument: instrument,
                                    quote: q,
                                    sparkline: vm.headlineSparklines[q.symbol] ?? []
                                )
                            }
                            .buttonStyle(.plain)
                            .matchedTransitionSource(id: instrument.id, in: heroNamespace)
                            .scrollTransition { v, phase in
                                v.scaleEffect(phase.isIdentity ? 1 : 0.94)
                                 .opacity(phase.isIdentity ? 1 : 0.8)
                            }
                            .appearAnimation(idx)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sectionedList(vm: MarketsViewModel) -> some View {
        switch vm.segment {
        case .stocks, .futures:
            VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
                SectionHeader(title: vm.segment == .stocks ? "Popular Stocks" : "Popular Futures")
                activeList(vm: vm)
            }
        }
    }

    // MARK: - Refresh menu (moved here from Settings — only affects Markets)

    @ToolbarContentBuilder
    private var refreshMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker(selection: Binding(
                    get: {
                        SettingsViewModel.RefreshInterval(
                            rawValue: UserDefaults.standard.integer(forKey: "refreshInterval")
                        ) ?? .fifteenSec
                    },
                    set: { interval in
                        Haptics.selection()
                        UserDefaults.standard.set(interval.rawValue, forKey: "refreshInterval")
                        vm?.startAutoRefresh(intervalSeconds: interval.rawValue)
                    }
                )) {
                    ForEach(SettingsViewModel.RefreshInterval.allCases) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                } label: {
                    Label("Auto-refresh", systemImage: "clock.arrow.circlepath")
                }
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(Theme.Colors.textPrimary)
                    .symbolEffect(.bounce, value: UserDefaults.standard.integer(forKey: "refreshInterval"))
            }
            .accessibilityLabel("Auto-refresh interval")
        }
    }

    @ViewBuilder
    private func activeList(vm: MarketsViewModel) -> some View {
        switch vm.activeQuotes {
        case .idle, .loading:
            ThemedCard {
                VStack(spacing: 0) {
                    ForEach(0..<6, id: \.self) { _ in
                        SkeletonRow()
                    }
                }
            }
        case .empty:
            EmptyStateView(
                message: "No active instruments right now.",
                actionTitle: "Search instruments",
                action: { withAnimation(Theme.Animation.interactive) { appNav.selectedTab = .search } }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .failed(let msg):
            ErrorView(message: msg) { Task { await vm.loadActive() } }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .loaded(let quotes):
            ThemedCard {
                VStack(spacing: 0) {
                    ForEach(Array(quotes.enumerated()), id: \.element.symbol) { idx, q in
                        if idx > 0 {
                            Divider()
                                .background(Theme.Colors.separator.opacity(0.5))
                                .padding(.horizontal, 0)
                        }
                        let instrument = vm.activeInstruments.first(where: { $0.symbol == q.symbol })
                            ?? Instrument(symbol: q.symbol, name: q.symbol, type: .stock, exchange: nil)
                        NavigationLink(value: instrument) {
                            InstrumentRow(instrument: instrument, quote: q)
                        }
                        .buttonStyle(.plain)
                        .matchedTransitionSource(id: instrument.id, in: heroNamespace)
                        .staggeredAppear(index: idx)
                    }
                }
            }
            .appearAnimation(.scale)
        }
    }
}
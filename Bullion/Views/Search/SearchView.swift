import SwiftUI

struct SearchView: View {
    @Environment(\.appEnv) private var env
    @State private var vm: SearchViewModel?
    @State private var path = NavigationPath()
    @Namespace private var heroNamespace
    @FocusState private var isFocused: Bool
    @State private var popular: [Instrument] = []

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Search")
                .navigationDestination(for: Instrument.self) { instrument in
                    InstrumentDetailView(instrument: instrument)
                        .navigationTransition(.zoom(sourceID: instrument.id, in: heroNamespace))
                }
        }
    }

    @ViewBuilder private var content: some View {
        if let vm {
            VStack(spacing: 0) {
                searchBar(vm: vm)
                resultsList(vm: vm)
            }
            .background(
                ZStack {
                    Theme.Colors.background.ignoresSafeArea()
                    RadialGradient(
                        colors: [Theme.Colors.accent.opacity(0.04), .clear],
                        center: .top, startRadius: 10, endRadius: 320
                    )
                    .ignoresSafeArea()
                }
            )
            .onAppear {
                if vm.results.value == nil { vm.search() }
                Task { popular = (try? await env.marketProvider.popularStocks()) ?? [] }
            }
        } else {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                GlowLoadingView()
            }
            .onAppear {
                vm = SearchViewModel(provider: env.marketProvider, quoteCache: env.quoteCache)
            }
        }
    }

    private func searchBar(vm: SearchViewModel) -> some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.Colors.textSecondary)
            TextField("Search stocks, ETFs, futures", text: Binding(
                get: { vm.query },
                set: { vm.query = $0; vm.search() }
            ))
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .focused($isFocused)
            if !vm.query.isEmpty {
                Button { vm.clear() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .accessibilityLabel("Clear search")
                .symbolEffect(.bounce, value: vm.query.isEmpty)
                .transition(.blurReplace)
            }
        }
        .padding(12)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                .stroke(isFocused ? Theme.Colors.accent : Theme.Colors.separator,
                        lineWidth: isFocused ? 1 : Theme.Metrics.hairline)
        )
        .scaleEffect(isFocused ? 1.01 : 1.0)
        .animation(Theme.Animation.interactive, value: isFocused)
        .padding(.horizontal, Theme.Metrics.spacingL)
        .padding(.vertical, Theme.Metrics.spacingS)
    }

    @ViewBuilder
    private func resultsList(vm: SearchViewModel) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                if !vm.hasSearched {
                    popularSection
                        .padding(.top, Theme.Metrics.spacingL)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    switch vm.results {
                    case .idle:
                        EmptyView()
                    case .loading:
                        VStack(spacing: Theme.Metrics.spacing) {
                            ForEach(0..<5, id: \.self) { _ in
                                SkeletonRow()
                                    .padding(.horizontal, Theme.Metrics.spacingL)
                            }
                        }
                        .transition(.opacity)
                    case .empty:
                        VStack(spacing: Theme.Metrics.spacing) {
                            EmptyStateView(
                                icon: "doc.text.magnifyingglass",
                                message: "No results for \"\(vm.query)\"."
                            )
                            if !popular.isEmpty {
                                VStack(alignment: .leading, spacing: Theme.Metrics.spacingS) {
                                    Text("Try one of these")
                                        .font(Typography.caption)
                                        .foregroundColor(Theme.Colors.textSecondary)
                                    popularChips
                                }
                                .padding(.horizontal, Theme.Metrics.spacingL)
                            }
                        }
                        .padding(.top, 60)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    case .failed(let msg):
                        ErrorView(message: msg, retry: { vm.search() })
                            .padding(.top, 60)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    case .loaded(let results):
                        LazyVStack(spacing: 0) {
                            ForEach(Array(results.enumerated()), id: \.element.id) { idx, instrument in
                                NavigationLink(value: instrument) {
                                    InstrumentRow(
                                        instrument: instrument,
                                        quote: vm.quotesBySymbol[instrument.symbol]
                                    )
                                    .padding(.horizontal, Theme.Metrics.spacingL)
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                                .matchedTransitionSource(id: instrument.id, in: heroNamespace)
                                .staggeredAppear(index: idx)
                                Divider()
                                    .padding(.leading, Theme.Metrics.spacingL)
                            }
                        }
                        .transition(.opacity)
                    }
                }
            }
            .padding(.bottom, Theme.Metrics.bottomSafeClearance)
        }
    }

    // MARK: - Popular suggestions

    @ViewBuilder private var popularSection: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.spacingS) {
            Text("Popular")
                .font(Typography.eyebrow)
                .foregroundColor(Theme.Colors.textSecondary)
                .padding(.horizontal, Theme.Metrics.spacingL)
            popularChips
        }
    }

    private var popularChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Metrics.spacingS) {
                ForEach(popular) { instrument in
                    NavigationLink(value: instrument) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(instrument.symbol)
                                .font(Typography.symbolCompact)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Text(instrument.name)
                                .font(Typography.caption2)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Theme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusSmall, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusSmall, style: .continuous)
                                .stroke(Theme.Gradients.cardBorderGradient, lineWidth: Theme.Metrics.hairline)
                        )
                    }
                    .buttonStyle(.plain)
                    .matchedTransitionSource(id: instrument.id, in: heroNamespace)
                }
            }
            .padding(.horizontal, Theme.Metrics.spacingL)
        }
    }
}
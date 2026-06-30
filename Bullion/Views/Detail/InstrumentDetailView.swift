import SwiftUI

struct InstrumentDetailView: View {
    let instrument: Instrument
    @Environment(\.appEnv) private var env
    @Environment(\.modelContext) private var modelContext
    @Environment(WatchlistViewModel.self) private var watchlistVM
    @State private var vm: InstrumentDetailViewModel?
    @State private var showSMA20 = false
    @State private var showBollinger = false
    @State private var showingAlertSheet = false
    @Namespace private var rangeNamespace
    @Namespace private var heroNamespace

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Metrics.spacingL) {
                headerSection
                chartSection
                statsSection
                newsSection
                aiResearchRow
            }
            .padding(.horizontal, Theme.Metrics.spacingL)
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
        .navigationTitle(instrument.symbol)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .navigationDestination(for: NewsItem.self) { item in
            NewsDetailView(item: item)
        }
        .refreshable {
            if let vm { await vm.load() }
        }
        .task(id: instrument.id) {
            if vm == nil {
                vm = InstrumentDetailViewModel(
                    instrument: instrument,
                    provider: env.marketProvider,
                    watchlist: watchlistVM
                )
            }
            await vm?.load()
        }
    }

    // MARK: - Header (price hero — also the hero-zoom target)

    @ViewBuilder private var headerSection: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.spacingS) {
            HStack(spacing: 8) {
                Text(instrument.name)
                    .font(Typography.subheadline)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .lineLimit(1)
                Spacer()
                InstrumentTypeBadge(type: instrument.type)
            }
            if let q = vm?.quote.value {
                PriceText(value: q.last, font: Typography.priceLarge)
                    .priceFlash(q.last)
                ChangeBadge(change: q.change, changePercent: q.changePercent)
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(Typography.caption2)
                    Text(q.timestamp.asOfTimeText)
                        .font(Typography.caption2)
                    if q.isDelayed {
                        Text("· Delayed")
                            .font(Typography.caption2)
                            .foregroundColor(Theme.Colors.negative)
                    }
                }
                .foregroundColor(Theme.Colors.textSecondary)
            } else if vm?.quote.isLoading == true {
                GlowLoadingView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Metrics.spacing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Metrics.spacingL)
        .background(
            RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusLarge, style: .continuous)
                .fill(Theme.Colors.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusLarge, style: .continuous)
                .stroke(Theme.Gradients.cardBorderGradient, lineWidth: Theme.Metrics.hairline)
        )
        .matchedTransitionSource(id: instrument.id, in: heroNamespace)
        .appearAnimation(.blur)
    }

    // MARK: - Chart (the hero — no card chrome, range pills overlaid)

    @ViewBuilder private var chartSection: some View {
        VStack(spacing: Theme.Metrics.spacingS) {
            if vm?.candles.isLoading == true {
                // Skeleton placeholder while candles load — keeps the page
                // structure visible instead of an empty gap.
                RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                    .fill(Theme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                            .stroke(Theme.Gradients.cardBorderGradient, lineWidth: Theme.Metrics.hairline)
                    )
                    .frame(height: 240)
                    .redacted(reason: .placeholder)
                    .shimmer()
                    .appearAnimation(.blur, index: 1)
            } else {
                PriceChartView(
                    candles: vm?.candles.value ?? [],
                    previousClose: vm?.quote.value?.previousClose,
                    showSMA20: showSMA20,
                    showBollinger: showBollinger
                )
                .frame(height: 240)
                .appearAnimation(.blur, index: 1)
            }

            indicatorToggles
            rangePicker
        }
    }

    /// Toggleable technical-indicator overlays. Indicators need >= 20
    /// candles, so they're only meaningful on 1M+ ranges; on 1D/1W the
    /// toggles are disabled with an honest hint.
    private var indicatorToggles: some View {
        let enoughData = (vm?.candles.value ?? []).count >= 20
        return HStack(spacing: Theme.Metrics.spacingS) {
            indicatorChip("SMA 20", isOn: $showSMA20, enabled: enoughData)
            indicatorChip("Bollinger", isOn: $showBollinger, enabled: enoughData)
            Spacer()
        }
    }

    private func indicatorChip(_ label: String, isOn: Binding<Bool>, enabled: Bool) -> some View {
        Button {
            Haptics.selection()
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 11))
                Text(label)
                    .font(Typography.caption2)
            }
            .foregroundColor(isOn.wrappedValue ? Theme.Colors.accent : Theme.Colors.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isOn.wrappedValue ? Theme.Colors.accent.opacity(0.12) : Theme.Colors.surface)
            )
            .overlay(
                Capsule().stroke(
                    isOn.wrappedValue ? Theme.Colors.accent.opacity(0.3) : Theme.Colors.separator,
                    lineWidth: Theme.Metrics.hairline
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel("\(label) overlay\(enabled ? "" : ", needs more data")")
    }

    private var rangePicker: some View {
        SegmentedPill(
            options: ChartRange.allCases,
            selection: Binding(
                get: { vm?.selectedRange ?? .oneD },
                set: { vm?.selectedRange = $0 }
            ),
            namespace: rangeNamespace
        )
    }

    // MARK: - Stats (2-column grid)

    @ViewBuilder private var statsSection: some View {
        if let stats = vm?.stats.value {
            ThemedCard {
                VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
                    SectionHeader(title: "Key Stats")
                    statsGrid(stats)
                }
            }
            .appearAnimation(.rise, index: 2)
        }
    }

    private func statsGrid(_ stats: KeyStats) -> some View {
        let common: [(String, String?)] = [
            ("Open", stats.open.map { NumberFormatting.price($0) }),
            ("Prev Close", stats.previousClose.map { NumberFormatting.price($0) }),
            ("Day Range", dayRangeText(stats)),
            ("52W Range", week52Text(stats)),
            ("Volume", stats.volume.map { NumberFormatting.compact($0) }),
            ("Avg Volume", stats.avgVolume.map { NumberFormatting.compact($0) }),
        ]
        let equities: [(String, String?)] = [
            ("Market Cap", stats.marketCap.map { NumberFormatting.compact($0) }),
            ("P/E (TTM)", stats.peRatio.map { String(format: "%.1f", $0) }),
            ("EPS (TTM)", stats.eps.map { String(format: "%.2f", $0) }),
            ("Div Yield", stats.dividendYield.map { NumberFormatting.percent($0) }),
            ("Beta", stats.beta.map { String(format: "%.2f", $0) }),
            ("Shares Out", stats.sharesOutstanding.map { NumberFormatting.compact($0) }),
            ("Next Earnings", stats.nextEarningsDate),
            ("Sector", stats.sector),
        ]
        let futures: [(String, String?)] = [
            ("Open Interest", stats.openInterest.map { NumberFormatting.compact($0) }),
            ("Contract Size", stats.contractSize.map { NumberFormatting.decimal($0, digits: 0) }),
            ("Tick Size", stats.tickSize.map { NumberFormatting.price($0) }),
            ("Expiry", stats.expiry),
            ("Settlement", stats.settlement.map { NumberFormatting.price($0) }),
            ("Continuous", stats.continuous.map { $0 ? "Yes" : "No" }),
        ]

        let columns = [GridItem(.flexible(), alignment: .leading),
                       GridItem(.flexible(), alignment: .leading)]
        return LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(common.enumerated()), id: \.0) { idx, item in
                StatCell(label: item.0, value: item.1)
                    .staggeredAppear(index: idx)
            }
            let extra = (instrument.type == .future || stats.hasFuturesFields) ? futures : equities
            ForEach(Array(extra.enumerated()), id: \.0) { idx, item in
                StatCell(label: item.0, value: item.1)
                    .staggeredAppear(index: common.count + idx)
            }
        }
    }

    private func dayRangeText(_ s: KeyStats) -> String? {
        guard let l = s.dayLow, let h = s.dayHigh else { return nil }
        return "\(NumberFormatting.price(l)) – \(NumberFormatting.price(h))"
    }

    private func week52Text(_ s: KeyStats) -> String? {
        guard let l = s.week52Low, let h = s.week52High else { return nil }
        return "\(NumberFormatting.price(l)) – \(NumberFormatting.price(h))"
    }

    // MARK: - News (inline top 3 + "See all")

    @ViewBuilder private var newsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
            HStack {
                SectionHeader(title: "News")
                Spacer()
                if let news = vm?.news.value, !news.isEmpty {
                    NavigationLink {
                        NewsListView(symbol: instrument.symbol)
                    } label: {
                        Text("See all")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.Colors.accent)
                            .textCase(.uppercase)
                    }
                    .buttonStyle(.plain)
                }
            }
            if let news = vm?.news.value, !news.isEmpty {
                ThemedCard {
                    VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
                        ForEach(Array(news.prefix(3).enumerated()), id: \.element.id) { idx, item in
                            NavigationLink(value: item) { newsRow(item) }
                                .buttonStyle(.plain)
                                .staggeredAppear(index: idx)
                            if item.id != news.prefix(3).last?.id {
                                Divider().background(Theme.Colors.separator.opacity(0.5))
                            }
                        }
                    }
                }
            } else if vm?.news.isLoading == true {
                SkeletonRow()
            } else {
                ThemedCard {
                    Text("No recent news for \(instrument.symbol).")
                        .font(Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
        }
        .appearAnimation(.rise, index: 3)
    }

    private func newsRow(_ item: NewsItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.headline)
                .font(Typography.subheadline)
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(2)
            HStack(spacing: 6) {
                Text(item.source)
                    .font(Typography.caption)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("·")
                    .font(Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                Text(item.publishedAt.relativeText)
                    .font(Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.headline), \(item.source), \(item.publishedAt.relativeText)")
    }

    // MARK: - AI Research (drill-in)

    @ViewBuilder private var aiResearchRow: some View {
        NavigationLink {
            AIResearchView(instrument: instrument)
        } label: {
            ThemedCard {
                HStack {
                    SectionHeader(title: "AI Research")
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 15))
                        .foregroundColor(Theme.Colors.accent)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .pressScale()
        }
        .buttonStyle(.plain)
        .appearAnimation(.rise, index: 4)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                showingAlertSheet = true
            } label: {
                Image(systemName: "bell.badge")
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            .accessibilityLabel("Create price alert")
            .popover(isPresented: $showingAlertSheet) {
                PriceAlertSheet(instrument: instrument, currentPrice: vm?.quote.value?.last)
                    .presentationDetents([.medium])
            }
            let isWatched = vm?.isWatched == true
            Button {
                vm?.toggleWatchlist()
            } label: {
                Image(systemName: isWatched ? "star.fill" : "star")
                    .foregroundColor(isWatched ? Theme.Colors.accent : Theme.Colors.textPrimary)
                    .symbolEffect(.bounce, value: isWatched)
                    .contentTransition(.symbolEffect(.replace))
                    .animation(Theme.Animation.snappy, value: isWatched)
            }
            .accessibilityLabel(isWatched ? "Remove from watchlist" : "Add to watchlist")
            .sensoryFeedback(.impact(weight: .light), trigger: isWatched)
        }
    }
}
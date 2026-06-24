import SwiftUI

struct InstrumentDetailView: View {
    let instrument: Instrument
    @Environment(\.appEnv) private var env
    @Environment(WatchlistViewModel.self) private var watchlistVM
    @State private var vm: InstrumentDetailViewModel?
    @Namespace private var rangeNamespace

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Metrics.spacingL) {
                headerSection
                chartSection
                statsSection
                aboutSection
                newsRow
                aiResearchRow
            }
            .padding(.horizontal, Theme.Metrics.spacingL)
            .padding(.bottom, 40)
        }
        .background(
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                RadialGradient(
                    colors: [Theme.Colors.textPrimary.opacity(0.03), .clear],
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
        .task {
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

    // MARK: - Header

    @ViewBuilder private var headerSection: some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: Theme.Metrics.spacingS) {
                HStack(spacing: 8) {
                    Text(instrument.name)
                        .font(Typography.subheadline)
                        .foregroundColor(Theme.Colors.textSecondary)
                    Spacer()
                    InstrumentTypeBadge(type: instrument.type)
                }
                if let exchange = instrument.exchange {
                    Text(exchange)
                        .font(Typography.caption2)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                if let q = vm?.quote.value {
                    PriceText(value: q.last, font: Typography.priceLarge)
                        .priceFlash(q.last)
                    ChangeBadge(change: q.change, changePercent: q.changePercent)
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(Typography.caption2)
                        Text("As of \(q.timestamp.asOfTimeText)")
                            .font(Typography.caption2)
                        if q.isDelayed {
                            Text("· Delayed")
                                .font(Typography.caption2)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                    .foregroundColor(Theme.Colors.textSecondary)
                } else if vm?.quote.isLoading == true {
                    GlowLoadingView()
                }
            }
        }
        .appearAnimation(.blur)
    }

    // MARK: - Chart

    @ViewBuilder private var chartSection: some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
                SectionHeader(title: "Price")
                rangePicker
                PriceChartView(
                    candles: vm?.candles.value ?? [],
                    previousClose: vm?.quote.value?.previousClose
                )
                .frame(height: 240)
            }
        }
        .appearAnimation(.blur, index: 1)
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

    // MARK: - Stats

    @ViewBuilder private var statsSection: some View {
        if let stats = vm?.stats.value {
            ThemedCard {
                VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
                    SectionHeader(title: "Key Stats")
                    statsGrid(stats)
                }
            }
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

        return VStack(spacing: 0) {
            ForEach(Array(common.enumerated()), id: \.0) { idx, item in
                StatCell(label: item.0, value: item.1)
                    .staggeredAppear(index: idx)
            }
            if instrument.type == .future || stats.hasFuturesFields {
                ForEach(Array(futures.enumerated()), id: \.0) { idx, item in
                    StatCell(label: item.0, value: item.1)
                        .staggeredAppear(index: common.count + idx)
                }
            } else {
                ForEach(Array(equities.enumerated()), id: \.0) { idx, item in
                    StatCell(label: item.0, value: item.1)
                        .staggeredAppear(index: common.count + idx)
                }
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

    // MARK: - About

    @ViewBuilder private var aboutSection: some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: Theme.Metrics.spacingS) {
                SectionHeader(title: "About")
                Text(aboutText)
                    .font(Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
    }

    private var aboutText: String {
        let stats = vm?.stats.value
        var parts: [String] = []
        if let sector = stats?.sector, !sector.isEmpty {
            parts.append("Sector: \(sector)")
        }
        if let industry = stats?.industry, !industry.isEmpty {
            parts.append("Industry: \(industry)")
        }
        switch instrument.type {
        case .future:
            parts.append("\(instrument.name) is a futures contract listed on \(instrument.exchange ?? "the exchange"). " +
                         "Futures are derivative instruments obligating the buyer to purchase (or seller to sell) " +
                         "the underlying asset at a predetermined future date and price.")
        default:
            parts.append("\(instrument.name) is listed on \(instrument.exchange ?? "its exchange"). " +
                         "This overview is for informational purposes only and is not investment advice.")
        }
        return parts.joined(separator: "\n\n")
    }

    // MARK: - News (drill-in)

    @ViewBuilder private var newsRow: some View {
        NavigationLink {
            NewsListView(symbol: instrument.symbol)
        } label: {
            ThemedCard {
                HStack {
                    SectionHeader(title: "News")
                    Spacer()
                    if let news = vm?.news.value, !news.isEmpty {
                        Text("\(news.count)")
                            .font(Typography.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .pressScale()
        }
        .buttonStyle(.plain)
        .appearAnimation(.blur, index: 2)
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
                        .foregroundColor(Theme.Colors.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .pressScale()
        }
        .buttonStyle(.plain)
        .appearAnimation(.blur, index: 3)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            let isWatched = vm?.isWatched == true
            Button {
                Haptics.light()
                vm?.toggleWatchlist()
            } label: {
                Image(systemName: isWatched ? "star.fill" : "star")
                    .foregroundColor(isWatched ? Theme.Colors.positive : Theme.Colors.textPrimary)
                    .symbolEffect(.bounce, value: isWatched)
                    .contentTransition(.symbolEffect(.replace))
                    .animation(Theme.Animation.snappy, value: isWatched)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: isWatched)
        }
    }
}
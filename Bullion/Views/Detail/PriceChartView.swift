import SwiftUI
import Charts

/// Swift Charts line/area chart with gold accent, gradient fill,
/// prev-close reference line, draggable crosshair, animated draw-in, and
/// optional technical-indicator overlays (SMA-20, Bollinger Bands).
///
/// Candles are plotted by index, not by timestamp: market data has overnight
/// and weekend gaps, and a Date-valued x-axis draws long connecting segments
/// across them. Index plotting keeps the line continuous through trading
/// time only; axis labels resolve back to each candle's date.
struct PriceChartView: View {
    let candles: [Candle]
    let previousClose: Double?
    var showSMA20: Bool = false
    var showBollinger: Bool = false

    @State private var selectedIndex: Int?
    @State private var animateChart = false

    private var smaSeries: [(index: Int, value: Double)] {
        guard showSMA20, candles.count >= 20 else { return [] }
        let closes = candles.map(\.c)
        let period = 20
        var out: [(Int, Double)] = []
        for i in (period - 1)..<closes.count {
            let slice = closes[(i - period + 1)...i]
            let avg = slice.reduce(0, +) / Double(period)
            out.append((i, avg))
        }
        return out
    }

    private var bollingerSeries: [(index: Int, upper: Double, middle: Double, lower: Double)] {
        guard showBollinger, candles.count >= 20 else { return [] }
        let closes = candles.map(\.c)
        let period = 20
        var out: [(Int, Double, Double, Double)] = []
        for i in (period - 1)..<closes.count {
            let slice = Array(closes[(i - period + 1)...i])
            let mean = slice.reduce(0, +) / Double(period)
            let variance = slice.map { pow($0 - mean, 2) }.reduce(0, +) / Double(period)
            let sd = sqrt(variance)
            out.append((i, mean + 2 * sd, mean, mean - 2 * sd))
        }
        return out
    }

    var body: some View {
        if candles.isEmpty {
            EmptyStateView(icon: "chart.line.uptrend.xyaxis", message: "No chart data available.")
                .frame(height: 220)
        } else {
            Chart {
                // Explicit `series:` on every LineMark — without it Swift
                // Charts joins all line points into a single connected series,
                // so enabling an overlay drew stray segments between the price
                // line and the indicator lines.
                ForEach(Array(candles.enumerated()), id: \.offset) { index, candle in
                    LineMark(
                        x: .value("Time", Double(index)),
                        y: .value("Price", candle.c),
                        series: .value("Series", "Price")
                    )
                    .foregroundStyle(Theme.Colors.accent)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .opacity(animateChart ? 1 : 0)

                    AreaMark(
                        x: .value("Time", Double(index)),
                        y: .value("Price", candle.c)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        .linearGradient(
                            colors: [Theme.Colors.accent.opacity(animateChart ? 0.20 : 0),
                                     Theme.Colors.accent.opacity(0)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                }
                // SMA-20 overlay
                if showSMA20 {
                    ForEach(smaSeries, id: \.index) { point in
                        LineMark(
                            x: .value("Time", Double(point.index)),
                            y: .value("SMA20", point.value),
                            series: .value("Series", "SMA 20")
                        )
                        .foregroundStyle(Theme.Colors.textSecondary.opacity(0.7))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 1.25))
                        .opacity(animateChart ? 1 : 0)
                    }
                }
                // Bollinger Bands overlay (upper + lower envelope)
                if showBollinger {
                    ForEach(bollingerSeries, id: \.index) { b in
                        LineMark(
                            x: .value("Time", Double(b.index)),
                            y: .value("BB Upper", b.upper),
                            series: .value("Series", "BB Upper")
                        )
                        .foregroundStyle(Theme.Colors.textSecondary.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        LineMark(
                            x: .value("Time", Double(b.index)),
                            y: .value("BB Lower", b.lower),
                            series: .value("Series", "BB Lower")
                        )
                        .foregroundStyle(Theme.Colors.textSecondary.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                }
                if let prevClose = previousClose {
                    RuleMark(y: .value("Prev Close", prevClose))
                        .foregroundStyle(Theme.Colors.accent.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("Prev Close \(NumberFormatting.price(prevClose))")
                                .font(Typography.chartAxis)
                                .foregroundColor(Theme.Colors.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(Theme.Colors.accent.opacity(0.12))
                                )
                        }
                }
                if let selectedIndex, candles.indices.contains(selectedIndex) {
                    let selected = candles[selectedIndex]
                    RuleMark(x: .value("Time", Double(selectedIndex)))
                        .foregroundStyle(Theme.Colors.accent.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                    PointMark(
                        x: .value("Time", Double(selectedIndex)),
                        y: .value("Price", selected.c)
                    )
                    .foregroundStyle(Theme.Colors.accent)
                    .symbolSize(45)
                    .annotation(position: .top) {
                        crosshairLabel(selected)
                    }
                }
            }
            .chartXScale(domain: xDomain)
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: xAxisValues) { value in
                    AxisGridLine().foregroundStyle(Theme.Colors.separator.opacity(0.3))
                    AxisValueLabel {
                        if let raw = value.as(Double.self) {
                            let i = Int(raw.rounded())
                            if candles.indices.contains(i) {
                                Text(candles[i].t, format: xAxisFormat)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(Theme.Colors.separator.opacity(0.3))
                    AxisValueLabel {
                        if let d = value.as(Double.self) {
                            Text(NumberFormatting.price(d, digits: 0))
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    handleDrag(value: value.location, proxy: proxy, geo: geo)
                                }
                                .onEnded { _ in
                                    withAnimation(Theme.Animation.interactive) {
                                        selectedIndex = nil
                                    }
                                }
                        )
                }
            }
            .onAppear {
                withAnimation(Theme.Animation.slow.delay(0.1)) {
                    animateChart = true
                }
            }
            .accessibilityLabel(accessibilityLabel)
        }
    }

    private var xDomain: ClosedRange<Double> {
        0...Double(max(candles.count - 1, 1))
    }

    /// ~5 evenly spaced candle indices for the x-axis grid/labels.
    private var xAxisValues: [Double] {
        let count = candles.count
        guard count > 1 else { return [0] }
        let step = max(1, (count - 1) / 4)
        return stride(from: 0, through: count - 1, by: step).map(Double.init)
    }

    private var yDomain: ClosedRange<Double> {
        // Include everything actually drawn — closes, indicator overlays, and
        // the prev-close rule — so Bollinger bands aren't clipped and the
        // prev-close line stays visible on gap-up/gap-down days.
        var values = candles.map(\.c)
        values.append(contentsOf: smaSeries.map(\.value))
        for b in bollingerSeries {
            values.append(b.upper)
            values.append(b.lower)
        }
        if let previousClose { values.append(previousClose) }
        guard let lo = values.min(), let hi = values.max() else { return 0...1 }
        let span = hi - lo
        let pad = span > 0 ? span * 0.08 : max(abs(hi) * 0.01, 0.5)
        return (lo - pad)...(hi + pad)
    }

    /// Range-aware x-axis format: intraday ranges show hour:minute; daily/
    /// weekly/monthly ranges show month + day (or month only for multi-year).
    private var xAxisFormat: Date.FormatStyle {
        // Heuristic on the time span of the data, since the chart doesn't
        // carry its ChartRange. 1D candles span < 1 day; 1W < 8 days; 1M <
        // 35 days; anything longer gets a coarser label.
        guard let first = candles.first, let last = candles.last else {
            return .dateTime.hour().minute()
        }
        let span = last.t.timeIntervalSince(first.t)
        let day: TimeInterval = 86_400
        if span < day { return .dateTime.hour().minute() }          // 1D
        if span < day * 8 { return .dateTime.weekday(.abbreviated).day() } // 1W
        if span < day * 95 { return .dateTime.month(.abbreviated).day() }  // 1M / 3M
        if span < day * 400 { return .dateTime.month(.abbreviated).year(.twoDigits) } // 1Y
        return .dateTime.year()                                       // 5Y / MAX
    }

    /// Crosshair timestamp format: clock time only makes sense for intraday
    /// candles; daily/weekly/monthly candles get a date instead of "12:00 AM".
    private var crosshairDateFormat: Date.FormatStyle {
        guard let first = candles.first, let last = candles.last else {
            return .dateTime.hour().minute()
        }
        let span = last.t.timeIntervalSince(first.t)
        let day: TimeInterval = 86_400
        if span < day { return .dateTime.hour().minute() }
        if span < day * 8 { return .dateTime.weekday(.abbreviated).hour().minute() }
        if span < day * 400 { return .dateTime.month(.abbreviated).day() }
        return .dateTime.month(.abbreviated).year(.twoDigits)
    }

    private func handleDrag(value: CGPoint, proxy: ChartProxy, geo: GeometryProxy) {
        guard !candles.isEmpty, let plotFrame = proxy.plotFrame else { return }
        let originX = geo[plotFrame].origin.x
        guard let raw: Double = proxy.value(atX: value.x - originX, as: Double.self) else { return }
        let index = min(max(Int(raw.rounded()), 0), candles.count - 1)
        if selectedIndex == nil { Haptics.light() }
        selectedIndex = index
    }

    private func crosshairLabel(_ candle: Candle) -> some View {
        // "You are here" chip — emerald-accented so the current-price moment
        // pops against the chart. Price in emerald, time in secondary, on a
        // surface card with an emerald-tinted border.
        VStack(spacing: 2) {
            Text(NumberFormatting.price(candle.c))
                .font(Typography.chartCross)
                .monospacedDigit()
                .foregroundColor(Theme.Colors.accent)
            Text(candle.t, format: crosshairDateFormat)
                .font(Typography.chartMicro)
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .padding(8)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Theme.Colors.accent.opacity(0.4), lineWidth: Theme.Metrics.hairline)
        )
        .shadow(color: Theme.Colors.accentShadow, radius: 8, y: 2)
        .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
    }

    private var accessibilityLabel: String {
        guard let first = candles.first, let last = candles.last else { return "Price chart" }
        let fmt = crosshairDateFormat
        return "Price chart from \(first.t.formatted(fmt)) to \(last.t.formatted(fmt)). " +
               "Current \(NumberFormatting.price(last.c))."
    }
}

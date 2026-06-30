import SwiftUI
import Charts

/// Swift Charts line/area chart with gold accent, gradient fill,
/// prev-close reference line, draggable crosshair, animated draw-in, and
/// optional technical-indicator overlays (SMA-20, Bollinger Bands).
struct PriceChartView: View {
    let candles: [Candle]
    let previousClose: Double?
    var showSMA20: Bool = false
    var showBollinger: Bool = false

    @State private var dragLocation: CGPoint?
    @State private var selectedCandle: Candle?
    @State private var animateChart = false

    private var smaSeries: [(date: Date, value: Double)] {
        guard showSMA20, candles.count >= 20 else { return [] }
        let closes = candles.map(\.c)
        let period = 20
        var out: [(Date, Double)] = []
        for i in (period - 1)..<closes.count {
            let slice = closes[(i - period + 1)...i]
            let avg = slice.reduce(0, +) / Double(period)
            out.append((candles[i].t, avg))
        }
        return out
    }

    private var bollingerSeries: [(date: Date, upper: Double, middle: Double, lower: Double)] {
        guard showBollinger, candles.count >= 20 else { return [] }
        let closes = candles.map(\.c)
        let period = 20
        var out: [(Date, Double, Double, Double)] = []
        for i in (period - 1)..<closes.count {
            let slice = Array(closes[(i - period + 1)...i])
            let mean = slice.reduce(0, +) / Double(period)
            let variance = slice.map { pow($0 - mean, 2) }.reduce(0, +) / Double(period)
            let sd = sqrt(variance)
            out.append((candles[i].t, mean + 2 * sd, mean, mean - 2 * sd))
        }
        return out
    }

    var body: some View {
        if candles.isEmpty {
            EmptyStateView(icon: "chart.line.uptrend.xyaxis", message: "No chart data available.")
                .frame(height: 220)
        } else {
            Chart {
                ForEach(candles) { candle in
                    LineMark(
                        x: .value("Time", candle.t),
                        y: .value("Price", candle.c)
                    )
                    .foregroundStyle(Theme.Colors.accent)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .opacity(animateChart ? 1 : 0)

                    AreaMark(
                        x: .value("Time", candle.t),
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
                    ForEach(smaSeries, id: \.date) { point in
                        LineMark(
                            x: .value("Time", point.date),
                            y: .value("SMA20", point.value)
                        )
                        .foregroundStyle(Theme.Colors.textSecondary.opacity(0.7))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 1.25))
                        .opacity(animateChart ? 1 : 0)
                    }
                }
                // Bollinger Bands overlay (upper + lower envelope)
                if showBollinger {
                    ForEach(bollingerSeries, id: \.date) { b in
                        LineMark(x: .value("Time", b.date), y: .value("BB Upper", b.upper))
                            .foregroundStyle(Theme.Colors.textSecondary.opacity(0.35))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        LineMark(x: .value("Time", b.date), y: .value("BB Lower", b.lower))
                            .foregroundStyle(Theme.Colors.textSecondary.opacity(0.35))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                }
                if let prevClose = previousClose {
                    RuleMark(y: .value("Prev Close", prevClose))
                        .foregroundStyle(Theme.Colors.textSecondary.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("Prev Close \(NumberFormatting.price(prevClose))")
                                .font(Typography.chartAxis)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                }
                if let selected = selectedCandle {
                    RuleMark(x: .value("Time", selected.t))
                        .foregroundStyle(Theme.Colors.textSecondary.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                    PointMark(
                        x: .value("Time", selected.t),
                        y: .value("Price", selected.c)
                    )
                    .foregroundStyle(Theme.Colors.accent)
                    .symbolSize(45)
                    .annotation(position: .top) {
                        crosshairLabel(selected)
                    }
                }
            }
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine().foregroundStyle(Theme.Colors.separator.opacity(0.3))
                    AxisValueLabel(format: xAxisFormat)
                        .foregroundStyle(Theme.Colors.textSecondary)
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
                                    if dragLocation == nil { Haptics.light() }
                                    handleDrag(value: value.location, proxy: proxy, geo: geo)
                                }
                                .onEnded { _ in
                                    withAnimation(Theme.Animation.interactive) {
                                        dragLocation = nil
                                        selectedCandle = nil
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

    private var yDomain: ClosedRange<Double> {
        // Domain on the plotted close values, not the H/L extremes — the chart
        // only draws the close line, so padding by H/L compressed the visible
        // line with excessive top/bottom whitespace.
        let closes = candles.map(\.c)
        guard let lo = closes.min(), let hi = closes.max(), hi > lo else { return 0...1 }
        let pad = (hi - lo) * 0.08
        return (lo - pad)...(hi + pad)
    }

    /// Range-aware x-axis format: intraday ranges show hour:minute; daily/
    /// weekly/monthly ranges show month + day (or month only for multi-year).
    /// Previously every range rendered hour:minute, which overlapped and was
    /// meaningless for 1Y/5Y/MAX.
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

    private func handleDrag(value: CGPoint, proxy: ChartProxy, geo: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let originX = geo[plotFrame].origin.x
        let originY = geo[plotFrame].origin.y
        let location = CGPoint(x: value.x - originX, y: value.y - originY)
        guard let date: Date = proxy.value(atX: location.x, as: Date.self) else { return }
        let nearest = candles.min(by: { abs($0.t.timeIntervalSince(date)) < abs($1.t.timeIntervalSince(date)) })
        if let nearest {
            selectedCandle = nearest
            dragLocation = CGPoint(x: value.x, y: originY)
        }
    }

    private func crosshairLabel(_ candle: Candle) -> some View {
        VStack(spacing: 2) {
            Text(NumberFormatting.price(candle.c))
                .font(Typography.chartCross)
                .foregroundColor(Theme.Colors.textPrimary)
            Text(candle.t.asOfTimeText)
                .font(Typography.chartMicro)
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .padding(8)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Theme.Colors.separator, lineWidth: Theme.Metrics.hairline)
        )
        .shadow(color: Theme.Colors.shadow.opacity(0.2), radius: 8, y: 2)
        .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
    }

    private var accessibilityLabel: String {
        guard let first = candles.first, let last = candles.last else { return "Price chart" }
        return "Price chart from \(first.t.asOfTimeText) to \(last.t.asOfTimeText). " +
               "Current \(NumberFormatting.price(last.c))."
    }
}

extension Candle: Identifiable {
    var id: TimeInterval { t.timeIntervalSince1970 }
}
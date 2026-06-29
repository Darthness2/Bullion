import SwiftUI
import Charts

/// Swift Charts line/area chart with gold accent, gradient fill,
/// prev-close reference line, draggable crosshair, and animated draw-in.
struct PriceChartView: View {
    let candles: [Candle]
    let previousClose: Double?
    /// The selected range drives axis date formatting and whether the
    /// prev-close baseline is meaningful (only on the intraday 1D view).
    var range: ChartRange = .oneD

    @State private var dragLocation: CGPoint?
    @State private var selectedCandle: Candle?
    @State private var animateChart = false

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
                    .foregroundStyle(lineColor)
                    // Monotone interpolation hugs the data: catmullRom can
                    // overshoot and draw the line below the period's true low,
                    // which reads as a fake price dip on a finance chart.
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .opacity(animateChart ? 1 : 0)

                    AreaMark(
                        x: .value("Time", candle.t),
                        y: .value("Price", candle.c)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(
                        .linearGradient(
                            colors: [lineColor.opacity(animateChart ? 0.20 : 0),
                                     lineColor.opacity(0)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                }
                if let prevClose = previousClose, showsPrevCloseLine {
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
                            Text(NumberFormatting.price(d, digits: yAxisDigits))
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

    /// Color the line/area by period performance (first vs last close) —
    /// green when up, red when down — matching the markets sparklines and the
    /// convention every major finance app uses.
    private var lineColor: Color {
        guard let first = candles.first?.c, let last = candles.last?.c else {
            return Theme.Colors.accent
        }
        if last > first { return Theme.Colors.positive }
        if last < first { return Theme.Colors.negative }
        return Theme.Colors.accent
    }

    /// The prev-close baseline is only the relevant reference on the intraday
    /// (1D) view; on multi-day ranges it's just a stray line mid-chart.
    private var showsPrevCloseLine: Bool { range == .oneD }

    private var yDomain: ClosedRange<Double> {
        let lows = candles.map(\.l)
        let highs = candles.map(\.h)
        guard let lo = lows.min(), let hi = highs.max() else { return 0...1 }
        // Flat series (lo == hi) would collapse to a zero-height domain and
        // render a degenerate chart — give it a small symmetric band.
        guard hi > lo else {
            let band = max(abs(hi) * 0.01, 0.5)
            return (lo - band)...(hi + band)
        }
        let pad = (hi - lo) * 0.1
        return (lo - pad)...(hi + pad)
    }

    /// Axis decimal precision scaled to price magnitude so low-priced or
    /// tight-range instruments don't collapse to a single repeated label.
    private var yAxisDigits: Int {
        let hi = candles.map(\.h).max() ?? 0
        switch abs(hi) {
        case 1000...:    return 0
        case 100..<1000: return 0
        case 10..<100:   return 1
        case 1..<10:     return 2
        default:         return 4
        }
    }

    /// Axis labels: time-of-day intraday, calendar dates for multi-day ranges,
    /// and year for the long horizons.
    private var xAxisFormat: Date.FormatStyle {
        switch range {
        case .oneD:            return .dateTime.hour().minute()
        case .oneW:            return .dateTime.weekday(.abbreviated)
        case .oneM, .threeM:   return .dateTime.month(.abbreviated).day()
        case .oneY:            return .dateTime.month(.abbreviated)
        case .fiveY, .max:     return .dateTime.year()
        }
    }

    /// Crosshair timestamp: intraday shows the time, longer ranges show the
    /// date (a bare time on a 1Y chart is meaningless).
    private func crosshairDateText(_ date: Date) -> String {
        switch range {
        case .oneD:
            return date.asOfTimeText
        case .oneW:
            return date.shortDateText
        default:
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .none
            return f.string(from: date)
        }
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
            Text(crosshairDateText(candle.t))
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
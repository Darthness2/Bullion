import SwiftUI

/// Compact headline card: symbol, name, price, change, tiny sparkline.
/// Sparkline is real intraday data (or hidden when unavailable — never fake).
struct SummaryCard: View {
    let instrument: Instrument
    let quote: Quote?
    let sparkline: [Double]
    @State private var animateChart = false

    var body: some View {
        ThemedCard(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(instrument.symbol)
                            .font(Typography.symbolCompact)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text(instrument.name)
                            .font(Typography.caption2)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if quote?.isDelayed == true {
                        Text("Delayed")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
                PriceText(value: quote?.last, font: Typography.priceSmall)
                    .priceFlash(quote?.last)
                ChangeBadge(change: quote?.change, changePercent: quote?.changePercent, compact: true)
                if sparkline.count > 1 {
                    MiniSparkline(values: sparkline, color: sparkColor, animate: animateChart)
                        .frame(height: 30)
                } else {
                    // Honest empty state — no fake squiggle.
                    Color.clear.frame(height: 30)
                }
            }
        }
        .frame(width: 168)
        .pressScale()
        .onAppear {
            withAnimation(Theme.Animation.slow.delay(0.2)) {
                animateChart = true
            }
        }
    }

    /// Sparkline color comes from the sparkline's own slope (first vs last),
    /// not the unrelated day-change badge.
    private var sparkColor: Color {
        guard sparkline.count > 1 else { return Theme.Colors.accent }
        let first = sparkline.first ?? 0
        let last = sparkline.last ?? 0
        if last > first { return Theme.Colors.positive }
        if last < first { return Theme.Colors.negative }
        return Theme.Colors.accent
    }
}

/// Tiny sparkline drawn with Path. Animated draw-on appear.
struct MiniSparkline: View {
    let values: [Double]
    let color: Color
    var animate: Bool = true

    var body: some View {
        GeometryReader { geo in
            if values.count > 1 {
                ZStack {
                    Path { path in
                        let minV = values.min() ?? 0
                        let maxV = values.max() ?? 1
                        let range = max(maxV - minV, 0.0001)
                        let stepX = geo.size.width / CGFloat(values.count - 1)
                        for (i, v) in values.enumerated() {
                            let x = CGFloat(i) * stepX
                            let y = geo.size.height * (1 - CGFloat((v - minV) / range))
                            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                            else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .trim(from: 0, to: animate ? 1 : 0)
                    .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    .animation(Theme.Animation.slow, value: color)

                    // Last-point dot — anchors the eye on "current price, up/down".
                    if animate, values.count > 1 {
                        let minV = values.min() ?? 0
                        let maxV = values.max() ?? 1
                        let range = max(maxV - minV, 0.0001)
                        let stepX = geo.size.width / CGFloat(values.count - 1)
                        let lastY = geo.size.height * (1 - CGFloat((values.last! - minV) / range))
                        Circle()
                            .fill(color)
                            .frame(width: 3, height: 3)
                            .position(x: geo.size.width, y: lastY)
                    }
                }
            } else {
                Color.clear
            }
        }
    }
}
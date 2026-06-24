import SwiftUI

/// Compact headline card: symbol, price, change, tiny sparkline.
/// Futuristic glass card with glow and animated sparkline.
struct SummaryCard: View {
    let instrument: Instrument
    let quote: Quote?
    let sparkline: [Double]
    @State private var animateChart = false

    var body: some View {
        ThemedCard(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(instrument.symbol)
                        .font(Typography.symbolCompact)
                        .foregroundColor(Theme.Colors.textPrimary)
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
                MiniSparkline(values: sparkline, color: sparkColor, animate: animateChart)
                    .frame(height: 30)
            }
        }
        .frame(width: 148)
        .pressScale()
        .onAppear {
            withAnimation(Theme.Animation.slow.delay(0.2)) {
                animateChart = true
            }
        }
    }

    private var sparkColor: Color {
        guard let change = quote?.change else { return Theme.Colors.accent }
        return change >= 0 ? Theme.Colors.positive : Theme.Colors.negative
    }
}

/// Tiny sparkline drawn with Path. Animated draw-on appear; the stroke
/// hue gently animates between monochrome and semantic on sign change.
struct MiniSparkline: View {
    let values: [Double]
    let color: Color
    var animate: Bool = true

    var body: some View {
        GeometryReader { geo in
            if values.count > 1 {
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
            } else {
                Color.clear
            }
        }
    }
}
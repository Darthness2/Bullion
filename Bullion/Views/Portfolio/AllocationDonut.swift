import SwiftUI
import Charts

/// Monochrome allocation donut — grayscale slices cycled per holding,
/// with a custom legend showing symbol + percentage. Animated sweep-in.
struct AllocationDonut: View {
    let holdings: [Holding]
    @State private var animate = false
    @State private var selectedSymbol: String?

    var body: some View {
        if holdings.isEmpty {
            EmptyStateView(icon: "chart.pie", message: "No holdings to display.")
        } else {
            HStack(spacing: Theme.Metrics.spacingL) {
                Chart(holdings) { h in
                    SectorMark(
                        angle: .value("Value", h.marketValue * (animate ? 1 : 0.0001)),
                        innerRadius: .ratio(0.58),
                        angularInset: h.symbol == selectedSymbol ? 3 : 1.2
                    )
                    .foregroundStyle(color(for: h.symbol))
                    .opacity(h.symbol == selectedSymbol ? 1 : 0.92)
                }
                .chartLegend(.hidden)
                .frame(maxWidth: .infinity)
                .chartBackground { _ in
                    VStack {
                        Text("Holdings")
                            .font(Typography.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text("\(holdings.count)")
                            .font(Typography.title2)
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                }
                legend
                    .frame(maxWidth: 140)
            }
            .onAppear {
                withAnimation(Theme.Animation.slow.delay(0.15)) {
                    animate = true
                }
            }
            .animation(Theme.Animation.interactive, value: selectedSymbol)
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(legendEntries.enumerated()), id: \.element.symbol) { idx, entry in
                HStack(spacing: 6) {
                    Circle()
                        .fill(entry.color)
                        .frame(width: 8, height: 8)
                        .symbolEffect(.bounce, value: entry.symbol == selectedSymbol)
                    Text(entry.symbol)
                        .font(Typography.caption)
                        .foregroundColor(entry.symbol == selectedSymbol
                                         ? Theme.Colors.textPrimary : Theme.Colors.textPrimary.opacity(0.85))
                        .lineLimit(1)
                    Spacer()
                    Text("\(entry.percent)%")
                        .font(Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .monospacedDigit()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    Haptics.selection()
                    withAnimation(Theme.Animation.interactive) {
                        selectedSymbol = (selectedSymbol == entry.symbol) ? nil : entry.symbol
                    }
                }
            }
        }
    }

    private struct LegendEntry {
        let symbol: String
        let percent: Int
        let color: Color
    }

    private var legendEntries: [LegendEntry] {
        let total = holdings.map(\.marketValue).reduce(0, +)
        guard total > 0 else { return [] }
        return holdings.enumerated().map { idx, h in
            let pct = Int((h.marketValue / total) * 100)
            return LegendEntry(symbol: h.symbol, percent: pct, color: color(for: h.symbol, index: idx))
        }
    }

    private func color(for symbol: String, index: Int? = nil) -> Color {
        let idx = index ?? holdings.firstIndex(where: { $0.symbol == symbol }) ?? 0
        return Theme.monochromeScale[idx % Theme.monochromeScale.count]
    }
}
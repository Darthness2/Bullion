import SwiftUI
import Charts

/// Monochrome allocation donut — grayscale slices cycled per holding,
/// with a custom legend showing symbol + percentage. Animated sweep-in.
///
/// Holdings beyond the top few are folded into a single "Other" slice so a
/// large portfolio doesn't draw dozens of unreadable slivers and an
/// overflowing legend. Percentages use largest-remainder rounding so they
/// always sum to exactly 100%.
struct AllocationDonut: View {
    let holdings: [Holding]
    @State private var animate = false
    @State private var selectedLabel: String?

    /// Top slices shown individually before the rest collapse into "Other".
    private let maxSlices = 8

    var body: some View {
        if holdings.isEmpty || slices.isEmpty {
            EmptyStateView(icon: "chart.pie", message: "No holdings to display.")
        } else {
            HStack(spacing: Theme.Metrics.spacingL) {
                Chart(slices) { slice in
                    SectorMark(
                        angle: .value("Value", slice.value * (animate ? 1 : 0.0001)),
                        innerRadius: .ratio(0.58),
                        angularInset: slice.label == selectedLabel ? 3 : 1.2
                    )
                    .foregroundStyle(slice.color)
                    .opacity(slice.label == selectedLabel ? 1 : 0.92)
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
            .animation(Theme.Animation.interactive, value: selectedLabel)
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(slices) { slice in
                HStack(spacing: 6) {
                    Circle()
                        .fill(slice.color)
                        .frame(width: 8, height: 8)
                        .symbolEffect(.bounce, value: slice.label == selectedLabel)
                    Text(slice.label)
                        .font(Typography.caption)
                        .foregroundColor(slice.label == selectedLabel
                                         ? Theme.Colors.textPrimary : Theme.Colors.textPrimary.opacity(0.85))
                        .lineLimit(1)
                    Spacer()
                    Text("\(slice.percent)%")
                        .font(Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .monospacedDigit()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    Haptics.selection()
                    withAnimation(Theme.Animation.interactive) {
                        selectedLabel = (selectedLabel == slice.label) ? nil : slice.label
                    }
                }
            }
        }
    }

    private struct Slice: Identifiable {
        var id: String { label }
        let label: String
        let value: Double
        let percent: Int
        let color: Color
    }

    /// Sorted, top-N-plus-"Other" slices with summing-to-100 percentages.
    private var slices: [Slice] {
        let total = holdings.map(\.marketValue).reduce(0, +)
        guard total > 0 else { return [] }
        let sorted = holdings.sorted { $0.marketValue > $1.marketValue }

        var grouped: [(label: String, value: Double)]
        if sorted.count > maxSlices {
            let top = sorted.prefix(maxSlices - 1).map { (label: $0.symbol, value: $0.marketValue) }
            let otherValue = sorted.dropFirst(maxSlices - 1).map(\.marketValue).reduce(0, +)
            grouped = top + [(label: "Other", value: otherValue)]
        } else {
            grouped = sorted.map { (label: $0.symbol, value: $0.marketValue) }
        }

        let percents = largestRemainderPercents(grouped.map(\.value), total: total)
        return grouped.enumerated().map { idx, pair in
            Slice(label: pair.label, value: pair.value, percent: percents[idx],
                  color: Theme.monochromeScale[idx % Theme.monochromeScale.count])
        }
    }

    /// Round percentages so they sum to exactly 100 (largest-remainder method),
    /// avoiding the "33 + 33 + 33 = 99" and "0% for everything tiny" artifacts
    /// of naive truncation.
    private func largestRemainderPercents(_ values: [Double], total: Double) -> [Int] {
        guard total > 0 else { return values.map { _ in 0 } }
        let exact = values.map { $0 / total * 100 }
        var floors = exact.map { Int(floor($0)) }
        let remainder = 100 - floors.reduce(0, +)
        if remainder > 0 {
            let byFraction = exact.enumerated()
                .sorted { ($0.element - floor($0.element)) > ($1.element - floor($1.element)) }
            for i in 0..<min(remainder, byFraction.count) {
                floors[byFraction[i].offset] += 1
            }
        }
        return floors
    }
}

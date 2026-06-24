import SwiftUI

/// Reusable sliding-pill selector backed by `matchedGeometryEffect`.
/// Extracted from `RootView`'s tab indicator and `InstrumentDetailView`'s
/// range picker so any segmented control can share one choreography.
///
/// `Options` must be `Identifiable` + `Hashable` + `StringRepresentable`.
struct SegmentedPill<Option: Identifiable & Hashable>: View where Option: SegmentedPillOption {
    let options: [Option]
    @Binding var selection: Option
    var namespace: Namespace.ID
    var onChange: ((Option) -> Void)? = nil

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options) { option in
                let isSelected = selection == option
                Button {
                    Haptics.selection()
                    withAnimation(Theme.Animation.interactive) {
                        selection = option
                    }
                    onChange?(option)
                } label: {
                    Text(option.pillTitle)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected
                                         ? Theme.Colors.textOnPrimary
                                         : Theme.Colors.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            ZStack {
                                if isSelected {
                                    Capsule()
                                        .fill(Theme.Gradients.accentGradient)
                                        .matchedGeometryEffect(id: "segmentedPill", in: namespace)
                                }
                            }
                        )
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? Color.clear : Theme.Colors.separator,
                                        lineWidth: Theme.Metrics.hairline)
                        )
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
            }
        }
        .animation(Theme.Animation.interactive, value: selection)
    }
}

protocol SegmentedPillOption {
    var pillTitle: String { get }
}
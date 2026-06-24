import SwiftUI

/// Reusable shimmering placeholder row consolidating the inline skeleton
/// implementations that were duplicated across Markets/Search/Watchlist.
struct SkeletonRow: View {
    var showsBadge: Bool = true

    var body: some View {
        HStack(spacing: Theme.Metrics.spacing) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Theme.Colors.textPrimary.opacity(0.12))
                        .frame(width: 54, height: 14)
                    if showsBadge {
                        Capsule()
                            .fill(Theme.Colors.textPrimary.opacity(0.10))
                            .frame(width: 34, height: 16)
                    }
                }
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Theme.Colors.textPrimary.opacity(0.08))
                    .frame(width: 88, height: 10)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Theme.Colors.textPrimary.opacity(0.12))
                    .frame(width: 60, height: 14)
                Capsule()
                    .fill(Theme.Colors.textPrimary.opacity(0.08))
                    .frame(width: 48, height: 14)
            }
        }
        .padding(.vertical, 6)
        .redacted(reason: .placeholder)
        .shimmer()
    }
}

/// Compact skeleton card sized to match `SummaryCard`.
struct SkeletonSummaryCard: View {
    var body: some View {
        ThemedCard(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Theme.Colors.textPrimary.opacity(0.12))
                    .frame(width: 48, height: 14)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Theme.Colors.textPrimary.opacity(0.12))
                    .frame(width: 70, height: 14)
                Capsule()
                    .fill(Theme.Colors.textPrimary.opacity(0.08))
                    .frame(width: 54, height: 14)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Theme.Colors.textPrimary.opacity(0.08))
                    .frame(maxWidth: .infinity, maxHeight: 30)
            }
        }
        .frame(width: 148)
        .redacted(reason: .placeholder)
        .shimmer()
    }
}
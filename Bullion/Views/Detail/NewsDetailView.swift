import SwiftUI

/// Native news detail screen showing the headline, source/date, summary
/// (if present), and an "Open in Safari" button for the full article.
struct NewsDetailView: View {
    let item: NewsItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Metrics.spacing) {
                Text(item.headline)
                    .font(Typography.title2)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .staggeredAppear(index: 0)
                HStack(spacing: 6) {
                    Text(item.source)
                        .font(Typography.caption)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text("·")
                        .font(Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    Text(item.publishedAt.relativeText)
                        .font(Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .staggeredAppear(index: 1)

                if let summary = item.summary {
                    Text(summary)
                        .font(Typography.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .staggeredAppear(index: 2)
                }

                if let related = item.relatedSymbols, !related.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(related, id: \.self) { sym in
                            Text(sym)
                                .font(Typography.caption2)
                                .foregroundColor(Theme.Colors.textPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Theme.Colors.textPrimary.opacity(0.10))
                                .clipShape(Capsule())
                        }
                    }
                    .staggeredAppear(index: 3)
                }

                Link(destination: item.url) {
                    HStack(spacing: Theme.Metrics.spacingS) {
                        Image(systemName: "safari")
                        Text("Open in Safari")
                    }
                    .font(Typography.headline)
                    .foregroundColor(Theme.Colors.textOnPrimary)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Theme.Gradients.inkGradient)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous))
                    .shadow(color: Theme.Colors.textPrimary.opacity(0.18), radius: 10, x: 0, y: 0)
                }
                .pressScale()
                .padding(.top, Theme.Metrics.spacingS)
                .staggeredAppear(index: 4)
            }
            .padding(Theme.Metrics.spacingL)
        }
        .background(
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                RadialGradient(
                    colors: [Theme.Colors.textPrimary.opacity(0.03), .clear],
                    center: .top, startRadius: 10, endRadius: 300
                )
                .ignoresSafeArea()
            }
        )
        .navigationTitle("Article")
        .navigationBarTitleDisplayMode(.inline)
    }
}
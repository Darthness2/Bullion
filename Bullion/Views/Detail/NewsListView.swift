import SwiftUI

/// Per-symbol news list pushed from InstrumentDetailView. Each row tappable
/// to open the article URL in Safari (via NewsDetailView for a native feel).
struct NewsListView: View {
    let symbol: String
    @Environment(\.appEnv) private var env
    @State private var items: [NewsItem] = []
    @State private var loadState: LoadState<[NewsItem]> = .idle

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Metrics.spacingS) {
                switch loadState {
                case .idle, .loading:
                    ForEach(0..<5, id: \.self) { _ in
                        SkeletonRow().padding(.horizontal, Theme.Metrics.spacingL)
                    }
                case .empty:
                    EmptyStateView(icon: "newspaper",
                                   message: "No news for \(symbol).")
                        .padding(.top, 60)
                case .failed(let msg):
                    ErrorView(message: msg) { Task { await load() } }
                        .padding(.top, 60)
                case .loaded(let news):
                    LazyVStack(spacing: Theme.Metrics.spacingS) {
                        ForEach(Array(news.enumerated()), id: \.element.id) { idx, item in
                            NavigationLink(value: item) {
                                newsRow(item)
                            }
                            .buttonStyle(.plain)
                            .staggeredAppear(index: idx)
                        }
                    }
                    .padding(.horizontal, Theme.Metrics.spacingL)
                }
            }
            .padding(.vertical, Theme.Metrics.spacingL)
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
        .navigationTitle("\(symbol) News")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: NewsItem.self) { item in
            NewsDetailView(item: item)
        }
        .task { await load() }
    }

    private func newsRow(_ item: NewsItem) -> some View {
        ThemedCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.headline)
                    .font(Typography.subheadline)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(2)
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
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
        }
        .pressScale()
    }

    @MainActor
    private func load() async {
        loadState = .loading
        do {
            let news = try await env.marketProvider.news(symbol)
            loadState = news.isEmpty ? .empty : .loaded(news)
            items = news
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }
}
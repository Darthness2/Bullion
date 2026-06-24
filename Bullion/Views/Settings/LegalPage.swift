import SwiftUI

/// Plain legal/info page shell — scrollable monochrome text content.
struct LegalPage: View {
    let title: String
    let sections: [LegalSection]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Metrics.spacingL) {
                ForEach(sections.indices, id: \.self) { idx in
                    let section = sections[idx]
                    VStack(alignment: .leading, spacing: Theme.Metrics.spacingS) {
                        Text(section.heading)
                            .font(Typography.headline)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .staggeredAppear(index: idx * 2)
                        Text(section.text)
                            .font(Typography.body)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .staggeredAppear(index: idx * 2 + 1)
                    }
                }
            }
            .padding(Theme.Metrics.spacingL)
        }
        .background(Theme.Colors.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LegalSection {
    let heading: String
    let text: String
}
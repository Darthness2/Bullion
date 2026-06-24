import Foundation

struct NewsItem: Identifiable, Codable, Hashable, Sendable {
    let id: Int
    let headline: String
    let summary: String?
    let source: String
    let url: URL
    let publishedAt: Date
    let relatedSymbols: [String]?
}
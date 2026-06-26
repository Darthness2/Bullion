import SwiftUI

/// Tiny observable for cross-tab routing — e.g. an "empty state" button that
/// switches to Search, or a deep link from Onboarding → Portfolio → Connect.
///
/// Tab rawValues match the visual order in RootView's TabView (0-indexed).
@Observable
final class AppNav {
    enum Tab: Int {
        case markets = 0
        case watchlist = 1
        case search = 2
        case portfolio = 3
        case settings = 4
    }
    var selectedTab: Tab = .portfolio
}
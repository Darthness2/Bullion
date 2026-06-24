import SwiftUI

/// Tiny observable for cross-tab routing — e.g. an "empty state" button that
/// switches to Search, or a deep link from Onboarding → Portfolio → Connect.
@Observable
final class AppNav {
    enum Tab: Int {
        case markets = 0
        case search = 1
        case watchlist = 4
        case portfolio = 2
        case settings = 3
    }
    var selectedTab: Tab = .portfolio
}
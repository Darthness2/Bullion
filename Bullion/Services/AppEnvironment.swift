import Foundation
import SwiftUI

/// Lightweight dependency container. The app uses Yahoo Finance (no key, no
/// rate limit) for market data and a backend-less, on-device SnapTrade
/// integration (`DirectSnapTradeService`) for portfolio data.
@Observable
final class AppEnvironment {
    let marketProvider: any MarketDataProvider
    let portfolioService: any PortfolioService
    let quoteCache: QuoteCache
    let aiSettings: AISettingsStore
    let aiService: AIService

    init(marketProvider: (any MarketDataProvider)? = nil,
         portfolioService: (any PortfolioService)? = nil,
         quoteCache: QuoteCache = QuoteCache(),
         aiSettings: AISettingsStore = AISettingsStore()) {
        self.marketProvider = marketProvider ?? YahooFinanceProvider()
        self.portfolioService = portfolioService ?? DirectSnapTradeService()
        self.quoteCache = quoteCache
        self.aiSettings = aiSettings
        self.aiService = AIService(settings: aiSettings)
    }
}

// MARK: - Environment key

private struct AppEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppEnvironment = AppEnvironment()
}

extension EnvironmentValues {
    var appEnv: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}
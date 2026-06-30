# Bullion

A native iOS investing app — market data, portfolio tracking, brokerage linking via SnapTrade, and an AI research agent. Built in Swift + SwiftUI.

**Read-only tracking and analytics tool. Not a trading terminal.**

## Status

Production-track. Market data is live (Yahoo Finance, no API key), SnapTrade brokerage linking is backend-less (on-device HMAC signing), and an AI research agent (Anthropic / OpenAI / local Ollama) produces structured analyses with multi-turn follow-up. App Store readiness (privacy manifest, scoped ATS, encryption export, hosted legal) is in place.

## Requirements

- Xcode 16+ (project uses synchronized file groups)
- iOS 18+ deployment target
- Swift 5.10+ (Observation framework, `@Observable`)
- A SnapTrade `clientId` + `consumerKey` (entered in-app) — no server required
- An AI provider API key (Anthropic or OpenAI), or a local Ollama instance — entered in-app

## Open the project

```bash
open Bullion.xcodeproj
```

Select the **Bullion** scheme and an iOS Simulator, then build (Cmd+B) and run (Cmd+R). Tests: Cmd+U.

## Architecture

- **MVVM** with `@Observable` view models (Observation framework), `@MainActor`-isolated state.
- **`MarketDataProvider` protocol** with `supportsEquities` / `supportsFutures` capability flags — swappable from Yahoo to Mock without touching the UI.
- **No third-party iOS packages.** Swift Charts, URLSession + async/await, SwiftData, CryptoKit, UserNotifications.
- **Backend-less SnapTrade.** The app talks to the SnapTrade REST API directly, signing each request on-device (HMAC-SHA256, CryptoKit) via `DirectSnapTradeService`. The `clientId`/`consumerKey` are entered in-app and stored in the iOS Keychain (`SnapTradeKeyStore`). No proxy server. Your brokerage credentials are entered only with SnapTrade and your broker, never with Bullion.
- **Live FX.** Multi-currency portfolios are converted to a base currency (USD) via `FXService` (Yahoo forex symbols) before aggregation.
- **Portfolio analytics.** `PortfolioAnalyticsEngine` computes beta vs SPY, annualized Sharpe, max drawdown, and concentration from 3-month candle history — client-side, no API key.
- **Price alerts.** Local notifications (no push tokens) checked on app foreground; `PriceAlert` persisted in SwiftData.
- **AI research agent.** `AIService` gathers quote/stats/candles/news, computes technical indicators (RSI Wilder, SMA/EMA/MACD/Bollinger), and calls the configured LLM; multi-turn follow-up chat reuses the cached context.
- **Motion & animation.** All curves live in `Theme.Animation` (physics-based `.smooth`/`.bouncy` springs, iOS 18). Reusable modifiers in `DesignSystem/Modifiers/`.

## Folders

```
Bullion/
  Models/          — Instrument, Quote, KeyStats, Candle, NewsItem, BrokerageAccount, Holding, WatchlistItem, PriceAlert
  Models/AI/       — AIAnalysis, TechnicalIndicators
  Services/        — MarketDataProvider, YahooFinanceProvider, MockMarketDataProvider, APIClient, QuoteCache, PortfolioService, AppEnvironment, AppNav, FXService, ConnectivityMonitor, AlertService, PortfolioAnalyticsEngine
  Services/SnapTrade/ — DirectSnapTradeService, SnapTradeKeyStore, SnapTradeSigner (on-device, no backend)
  Services/AI/     — AIService, AIProvider, AISettingsStore, AIKeyStore, AIPromptBuilder, Anthropic/OpenAI/Ollama providers
  ViewModels/      — @Observable VMs + LoadState
  Views/           — Root, Markets, Search, Detail, Watchlist, Portfolio, Settings, Onboarding, Shared, AI
  DesignSystem/    — Theme (monochrome blue accent, Light+Dark), Typography, reusable components
  Utilities/       — NumberFormatting, Date helpers, KeychainStore, Haptics
  Config/          — Secrets.swift (gitignored; OAuth callback scheme only)
  PrivacyInfo.xcprivacy — App Store privacy manifest
  Localizable.xcstrings — String Catalog for localization
BullionTests/      — QuoteMath, MockProvider, TechnicalIndicator, SnapTradeSigner, KeychainStore, PortfolioAggregation, PortfolioAnalyticsEngine, FXService, PriceAlert
```

## Distribution model: bring your own keys (backend-less)

Bullion ships **no shared server and no shared API credentials**. Each user supplies their own:

| Secret | Where to get it | Stored |
|--------|----------------|--------|
| SnapTrade `clientId` + `consumerKey` | [dashboard.snaptrade.com](https://dashboard.snaptrade.com) (free partner account) | iOS Keychain via `SnapTradeKeyStore` |
| SnapTrade `userSecret` | Returned by `registerUser` after first connect | iOS Keychain (never typed by the user) |
| Anthropic or OpenAI API key | provider's developer console | iOS Keychain via `AIKeyStore` |
| Ollama endpoint | local install, default `http://localhost:11434` | UserDefaults |

This is a deliberate privacy choice: your keys, holdings, and AI prompts never pass through a Bullion server — they go directly from your device to the provider you selected. The tradeoff is that every user must obtain their own SnapTrade partner credentials and AI API key. This suits a privacy-first, power-user audience; it is not the friction-minimizing model for mass distribution.

In `Info.plist`, ATS is scoped to allow cleartext only to `localhost` (for Ollama); every real endpoint (Yahoo, SnapTrade, Anthropic, OpenAI) is HTTPS under default ATS. The OAuth callback scheme is `ledger://snaptrade-callback` (whitelist this redirect URI in your SnapTrade dashboard).

## App Store readiness

- **Privacy manifest** (`PrivacyInfo.xcprivacy`): declares financial info, user content, user ID, and search history as linked (not tracked) data sent to SnapTrade / AI providers / Yahoo; UserDefaults + file-timestamp API reasons.
- **Encryption export**: `ITSAppUsesNonExemptEncryption = false` (standard HTTPS/TLS only).
- **Privacy Policy & Terms**: in-app at `Views/Settings/PrivacyPolicyView.swift` and `TermsView.swift`. For App Store Connect submission, host these at public HTTPS URLs (e.g. a GitHub Pages site) and paste the URLs into App Store Connect.
- **SnapTrade + AI data disclosure**: declare both as third-party partners receiving user data in App Store Connect.

## Disclaimers

For informational purposes only — not investment advice. Market data may be delayed. AI-generated analyses may be wrong, outdated, or misleading.

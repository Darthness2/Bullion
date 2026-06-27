# Bullion

A native iOS investing app — stock and futures market-data, portfolio tracking, and live brokerage linking via SnapTrade. Built in Swift + SwiftUI.

**Read-only tracking and analytics tool. Not a trading terminal.**

## Status

Milestone 1 — scaffold, design system, and mock data. The full UI is navigable on `MockMarketDataProvider`; real data and SnapTrade linking land in later milestones.

## Requirements

- Xcode 16+ (project uses synchronized file groups)
- iOS 18+ deployment target
- Swift 5.10+ (Observation framework, `@Observable`)
- A SnapTrade `clientId` + `consumerKey` (entered in-app) — no server required

## Open the project

```bash
open Bullion.xcodeproj
```

Select the **Bullion** scheme and an iOS Simulator, then build (Cmd+B) and run (Cmd+R).

## Architecture

- **MVVM** with `@Observable` view models (Observation framework).
- **`MarketDataProvider` protocol** with `supportsEquities` / `supportsFutures` capability flags — swappable from Mock to Polygon without touching the UI.
- **No third-party iOS packages.** Swift Charts (Apple), URLSession + async/await, SwiftData (M2).
- **Backend-less SnapTrade.** The app talks to the SnapTrade REST API directly, signing each request on-device (HMAC-SHA256, CryptoKit) via `DirectSnapTradeService`. The `clientId`/`consumerKey` are entered in-app and stored in the iOS Keychain (`SnapTradeKeyStore`). No proxy server. Tradeoff: the consumer key ships in the app — fine for a personal build, not multi-user distribution. Your brokerage credentials are still entered only with SnapTrade and your broker, never with Bullion.
- **Motion & animation.** All curves live in `Theme.Animation` (physics-based `.smooth`/`.bouncy` springs, iOS 18). Reusable modifiers (`.appearAnimation`, `.staggeredAppear`, `.pressScale`, `.shimmer`, `.priceFlash`, `.interactiveCard`) are in `DesignSystem/Modifiers/AnimationModifiers.swift`. Hero zoom navigation links list rows to `InstrumentDetailView` via `.matchedTransitionSource` + `.navigationTransition(.zoom)`. Gesture-driven sites use UIKit `Haptics`; declarative control-state changes use `.sensoryFeedback`.

## Folders

```
Bullion/
  Models/          — Instrument, Quote, KeyStats, Candle, NewsItem, BrokerageAccount, Holding
  Services/        — MarketDataProvider, MockMarketDataProvider, APIClient, QuoteCache, PortfolioService, AppEnvironment
  Services/SnapTrade/ — DirectSnapTradeService, SnapTradeKeyStore, SnapTradeSigner (on-device, no backend)
  ViewModels/      — @Observable VMs + LoadState
  Views/           — Root, Markets, Search, Detail, Watchlist, Portfolio, Settings, Shared
  DesignSystem/    — Theme (blue/white/gold, Light+Dark), Typography, reusable components
  Utilities/       — NumberFormatting, Date helpers, KeychainStore
  Config/          — Secrets.swift (gitignored; SnapTrade OAuth callback scheme only)
```

## Build order (milestones)

1. **Scaffold + design system + mock data** ← you are here
2. Markets, Search, Detail, Watchlist wired to mock data + Swift Charts + SwiftData
3. Real Polygon `MarketDataProvider` (equities + futures, capability flags, rate-limit throttling)
4. Backend-less SnapTrade: on-device request signing + `DirectSnapTradeService`
5. End-to-end SnapTrade connect flow (`ASWebAuthenticationSession`, `ledger://` callback, reconnect/disconnect)
6. Polish, accessibility, error/empty states, settings, tests

## Secrets

| Key | Where | Notes |
|-----|-------|-------|
| SnapTrade `clientId`, `consumerKey` | Entered in-app (Settings → Advanced → Brokerage) | Stored in the iOS Keychain via `SnapTradeKeyStore`. |
| SnapTrade `userSecret` | iOS Keychain | Returned by registerUser; never typed by the user. |
| OAuth callback scheme | `Bullion/Config/Secrets.swift` | Gitignored. Must match `Info.plist` `CFBundleURLSchemes` and your SnapTrade redirect URI (`ledger://snaptrade-callback`). |

Get your SnapTrade keys from [dashboard.snaptrade.com](https://dashboard.snaptrade.com), and whitelist the `ledger://snaptrade-callback` redirect URI there.

## Disclaimers

For informational purposes only — not investment advice. Data may be delayed. A privacy policy and accurate data-use disclosures will be required before App Store submission (flagged for Milestone 6).

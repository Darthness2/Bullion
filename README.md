# Bullion

A native iOS investing app — stock and futures market-data, portfolio tracking, and live brokerage linking via SnapTrade. Built in Swift + SwiftUI.

**Read-only tracking and analytics tool. Not a trading terminal.**

## Status

Milestone 1 — scaffold, design system, and mock data. The full UI is navigable on `MockMarketDataProvider`; real data and SnapTrade linking land in later milestones.

## Requirements

- Xcode 16+ (project uses synchronized file groups)
- iOS 18+ deployment target
- Swift 5.10+ (Observation framework, `@Observable`)
- Node 20+ (for the backend proxy)

## Open the project

```bash
open Bullion.xcodeproj
```

Select the **Bullion** scheme and an iOS Simulator, then build (Cmd+B) and run (Cmd+R).

## Architecture

- **MVVM** with `@Observable` view models (Observation framework).
- **`MarketDataProvider` protocol** with `supportsEquities` / `supportsFutures` capability flags — swappable from Mock to Polygon without touching the UI.
- **No third-party iOS packages.** Swift Charts (Apple), URLSession + async/await, SwiftData (M2).
- **SnapTrade secrets stay server-side.** The app only calls our own backend. `userSecret` and brokerage credentials never touch the app.
- **Motion & animation.** All curves live in `Theme.Animation` (physics-based `.smooth`/`.bouncy` springs, iOS 18). Reusable modifiers (`.appearAnimation`, `.staggeredAppear`, `.pressScale`, `.shimmer`, `.priceFlash`, `.interactiveCard`) are in `DesignSystem/Modifiers/AnimationModifiers.swift`. Hero zoom navigation links list rows to `InstrumentDetailView` via `.matchedTransitionSource` + `.navigationTransition(.zoom)`. Gesture-driven sites use UIKit `Haptics`; declarative control-state changes use `.sensoryFeedback`.

## Folders

```
Bullion/
  Models/          — Instrument, Quote, KeyStats, Candle, NewsItem, BrokerageAccount, Holding
  Services/        — MarketDataProvider, MockMarketDataProvider, APIClient, QuoteCache, PortfolioService, AppEnvironment
  ViewModels/      — @Observable VMs + LoadState
  Views/           — Root, Markets, Search, Detail, Watchlist, Portfolio, Settings, Shared
  DesignSystem/    — Theme (blue/white/gold, Light+Dark), Typography, reusable components
  Utilities/       — NumberFormatting, Date helpers, KeychainStore
  Config/          — Secrets.swift (gitignored; backend URL only)
backend/
  server.js        — Express entry
  routes/snaptrade.js — SnapTrade proxy (register, portal, accounts, holdings, transactions, disconnect)
  routes/market.js — Optional Polygon proxy
```

## Build order (milestones)

1. **Scaffold + design system + mock data** ← you are here
2. Markets, Search, Detail, Watchlist wired to mock data + Swift Charts + SwiftData
3. Real Polygon `MarketDataProvider` (equities + futures, capability flags, rate-limit throttling)
4. Node backend SnapTrade proxy + iOS `PortfolioService` talking to it
5. End-to-end SnapTrade connect flow (`ASWebAuthenticationSession`, `ledger://` callback, reconnect/disconnect)
6. Polish, accessibility, error/empty states, settings, tests

## Secrets

| Key | Where | Notes |
|-----|-------|-------|
| SnapTrade `clientId`, `consumerKey` | `backend/.env` | Server-side only. Never in the app. |
| Polygon API key | `backend/.env` | Server-side (if proxying) or app-side (M3). |
| Backend URL | `Bullion/Config/Secrets.swift` | Gitignored. Only value the app needs. |
| Backend session token | iOS Keychain | For our backend auth, not SnapTrade. |

You already have keys in `~/.config/snaptrade/settings.json` and `~/market_v2/.env.example`.

## Disclaimers

For informational purposes only — not investment advice. Data may be delayed. A privacy policy and accurate data-use disclosures will be required before App Store submission (flagged for Milestone 6).

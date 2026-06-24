# Bullion Backend

Thin proxy that holds SnapTrade + market-data secrets server-side.
The iOS app talks only to this backend for anything SnapTrade-related.

## Why a backend?

SnapTrade authenticates requests with a `clientId` + `consumerKey`. The
`consumerKey` is a **secret that must never ship inside the iOS app** —
anyone can extract strings from an app binary. So all SnapTrade calls go
through this proxy.

## Setup

```bash
cd backend
cp .env.example .env       # fill in your keys
npm install
npm start                  # http://localhost:8787
```

You already have the keys:
- SnapTrade credentials in `~/.config/snaptrade/settings.json`
- Polygon / Finnhub keys referenced in `~/market_v2/.env.example`

## Endpoints

### SnapTrade
| Method | Path | Purpose |
|--------|------|---------|
| POST   | `/snaptrade/register-user` | Register/return SnapTrade userId |
| POST   | `/snaptrade/connection-portal-url` | Generate Connection Portal login URL |
| GET    | `/snaptrade/accounts` | List connected brokerage accounts |
| GET    | `/snaptrade/accounts/:id/holdings` | Positions + balances |
| GET    | `/snaptrade/accounts/:id/transactions` | Recent activity |
| DELETE | `/snaptrade/connections/:id` | Disconnect a brokerage |
| POST   | `/snaptrade/refresh/:connectionId` | Re-sync a connection |

### Market (optional proxy)
| Method | Path | Purpose |
|--------|------|---------|
| GET    | `/market/quote/:symbol` | Last trade |
| GET    | `/market/candles/:symbol?range=1M` | Aggregates |
| GET    | `/market/search?q=apple` | Ticker search |

## Auth

**Stub for v1.** A single hard-coded dev user is used. All `// TODO: real auth`
markers show where to wire JWT/session/OAuth tied to real user identity.

## Deploy

The repo includes a `render.yaml` Blueprint for one-click deployment to Render
(free tier; sleeps when idle, wakes on first request with a ~10-15s cold start).

1. Push this repo to GitHub.
2. In Render, **New → Blueprint** → select the repo. Render reads `render.yaml`.
3. In the service's **Environment** tab, set the secret env vars (do NOT commit
   real values to the repo):
   - `SNAPTRADE_CLIENT_ID`, `SNAPTRADE_CONSUMER_KEY`, `SNAPTRADE_USER_ID`,
     `SNAPTRADE_USER_SECRET`
   - `CORS_ORIGIN` (the iOS app isn't browser-based, so you can set this to `*`
     or leave it unset for now)
4. Deploy. Note the service URL (e.g. `https://bullion-backend.onrender.com`).
5. In the iOS app, set `BULLION_BACKEND_URL` (via xcconfig or the `Info.plist`
   build setting injected by `Secrets.swift`) to that URL. For local dev it
   still defaults to `http://localhost:8787`.

Equivalent hosts work too: Railway (`railway up`), Fly.io (`fly deploy`), or any
Node host. The server is a plain Express app with no special requirements.

## Local dev (when you don't want a cloud host)

```bash
cd backend
cp .env.example .env       # fill in your keys
npm install
npm start                  # http://localhost:8787
```

`localhost:8787` works from the iOS Simulator (same machine). For a physical
device over Wi-Fi, use your Mac's LAN IP instead of `localhost`, or deploy to
a cloud host.

## Verify against current SnapTrade docs

The SnapTrade API evolves. Before relying on any endpoint, check:
- https://docs.snaptrade.com/docs/getting-started
- https://docs.snaptrade.com/docs/implement-connection-portal
- The `snaptrade-typescript-sdk` README for current method signatures.

Method names in `routes/snaptrade.js` mirror the SDK; verify before shipping.
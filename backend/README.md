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

The backend ships in two forms:

### Option A — Vercel serverless (recommended, scales to zero)

The `api/` folder contains Vercel serverless functions (one file per route).
No always-on process — each request spins up briefly and dies, billed per
invocation (free tier covers thousands of calls/day).

1. Install the Vercel CLI: `npm i -g vercel`
2. From the `backend/` folder: `vercel` (link the project; accept defaults)
3. Set env vars in the Vercel dashboard (Settings → Environment Variables),
   or via CLI:
   ```
   vercel env add SNAPTRADE_CLIENT_ID
   vercel env add SNAPTRADE_CONSUMER_KEY
   vercel env add SNAPTRADE_USER_ID
   vercel env add SNAPTRADE_REDIRECT_URI   # ledger://snaptrade-callback
   vercel env add BULLION_API_TOKEN        # a long random string; set for auth
   ```
   (SNAPTRADE_USER_SECRET is set AFTER the first register-user call — see below.)
4. `vercel --prod` to deploy. Copy the URL (e.g.
   `https://bullion-backend.vercel.app`).
5. In the iOS app, set `BULLION_BACKEND_URL` (xcconfig / Build Setting) to
   that URL. For local dev it still defaults to `http://localhost:8787`.

**One-time SnapTrade user registration (serverless is stateless):**
After deploying, run `curl -X POST https://<your-url>/snaptrade/register-user`
once. The response includes `userSecret`. Paste that as
`vercel env add SNAPTRADE_USER_SECRET`, redeploy (`vercel --prod`), and the
register endpoint short-circuits on all future calls. Until you do this, the
data endpoints (accounts/holdings/transactions) return 400.

### Option B — Render (always-on, uses the classic Express server)

A `render.yaml` Blueprint is included for one-click Render deployment (free
tier; sleeps when idle, wakes on first request with a ~10–15s cold start).
The Express `server.js` + `routes/` persist the userSecret to a gitignored
file so no second deploy is needed after registration.

1. Push this repo to GitHub.
2. In Render: **New → Blueprint** → select the repo. Render reads
   `render.yaml`.
3. Set the secret env vars in the dashboard.
4. Deploy. Use the service URL as `BULLION_BACKEND_URL`.

Equivalent hosts work too: Railway (`railway up`), Fly.io (`fly deploy`).

## Local dev (when you don't want a cloud host)

The classic Express server (`server.js` + `routes/`) runs locally and persists
the userSecret to a gitignored file:

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
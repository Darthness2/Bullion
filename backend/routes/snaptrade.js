// SnapTrade proxy routes.
//
// All SnapTrade operations that require the consumerKey happen HERE —
// never in the iOS app. The app calls these endpoints only.
//
// Verified against SnapTrade SDK v10 (snaptrade-typescript-sdk@10.0.14).

import { Router } from "express";
import { z } from "zod";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const router = Router();

const __dirname = path.dirname(fileURLToPath(import.meta.url));
// Where a registered user's secret is persisted so it survives restarts.
// Gitignored — never commit. Override with SNAPTRADE_SECRET_FILE.
const SECRET_FILE =
  process.env.SNAPTRADE_SECRET_FILE ||
  path.join(__dirname, "..", ".snaptrade-secret.json");

// --- Shared-token auth gate ----------------------------------------------
// v1 has a single backend user, so this is a shared bearer token rather than
// per-user identity (tracked as a follow-up). If BULLION_API_TOKEN is unset we
// stay open for local dev but server.js logs a loud warning at boot.
function requireAuth(req, res, next) {
  const expected = process.env.BULLION_API_TOKEN;
  if (!expected) return next(); // dev mode: open (warned at startup)
  const header = req.get("authorization") || "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : null;
  if (token !== expected) {
    return res.status(401).json({ error: "Unauthorized." });
  }
  next();
}

// --- User secret: load from env or persisted file, persist on register ----
function loadPersistedSecret() {
  if (process.env.SNAPTRADE_USER_SECRET) return process.env.SNAPTRADE_USER_SECRET;
  try {
    const raw = fs.readFileSync(SECRET_FILE, "utf8");
    return JSON.parse(raw)?.userSecret || "";
  } catch {
    return "";
  }
}

function persistSecret(userSecret) {
  process.env.SNAPTRADE_USER_SECRET = userSecret;
  try {
    fs.writeFileSync(
      SECRET_FILE,
      JSON.stringify({ userSecret }, null, 2),
      { mode: 0o600 }
    );
  } catch (e) {
    console.error("Failed to persist SnapTrade secret:", e?.message);
  }
}

function getUser() {
  return {
    userId: process.env.SNAPTRADE_USER_ID || "bullion-dev-user",
    userSecret: loadPersistedSecret(),
  };
}

// Lazily initialized SnapTrade SDK client.
let snaptrade = null;
async function getSnapTrade() {
  if (snaptrade) return snaptrade;
  const { Snaptrade } = await import("snaptrade-typescript-sdk");
  snaptrade = new Snaptrade({
    clientId: process.env.SNAPTRADE_CLIENT_ID,
    consumerKey: process.env.SNAPTRADE_CONSUMER_KEY,
  });
  return snaptrade;
}

function requireKeys(_req, res, next) {
  if (!process.env.SNAPTRADE_CLIENT_ID || !process.env.SNAPTRADE_CONSUMER_KEY) {
    return res
      .status(503)
      .json({ error: "SnapTrade credentials not configured on the server." });
  }
  next();
}

// Wraps an async handler so a rejected promise reaches Express' error handler
// instead of hanging the request.
const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);

// Require a registered user (userSecret present) for data endpoints.
function requireUser(req, res, next) {
  if (!getUser().userSecret) {
    return res
      .status(400)
      .json({ error: "User not registered. Call /register-user first." });
  }
  next();
}

// Validate a route param against a schema; 400 on failure.
const validateParam = (name, schema) => (req, res, next) => {
  const result = schema.safeParse(req.params[name]);
  if (!result.success) {
    return res.status(400).json({ error: `Invalid ${name}.` });
  }
  req.params[name] = result.data;
  next();
};

// SnapTrade ids are opaque but bounded; reject empty / absurdly long values.
const idSchema = z.string().trim().min(1).max(128);

router.use(requireAuth);
router.use(requireKeys);

// POST /snaptrade/register-user
// Idempotent: registers or returns existing SnapTrade user for this person.
router.post(
  "/register-user",
  asyncHandler(async (_req, res) => {
    const user = getUser();
    if (user.userSecret) {
      return res.json({ userId: user.userId, registered: true, existing: true });
    }
    try {
      const sdk = await getSnapTrade();
      const response = await sdk.authentication.registerSnapTradeUser({
        userId: user.userId,
      });
      const data = response.data || response;
      if (data?.userSecret) {
        persistSecret(data.userSecret);
      }
      res.json({ userId: data?.userId || user.userId, registered: true });
    } catch (err) {
      console.error("register-user failed:", err?.message?.substring(0, 200) || "error");
      res.status(500).json({
        error:
          "Failed to register SnapTrade user. If the user already exists, set SNAPTRADE_USER_SECRET in .env.",
      });
    }
  })
);

// POST /snaptrade/connection-portal-url
const portalBodySchema = z.object({ brokerId: z.string().trim().max(64).optional() });

router.post(
  "/connection-portal-url",
  requireUser,
  asyncHandler(async (req, res) => {
    const parsed = portalBodySchema.safeParse(req.body || {});
    if (!parsed.success) {
      return res.status(400).json({ error: "Invalid request body." });
    }
    const user = getUser();
    const sdk = await getSnapTrade();
    const { brokerId } = parsed.data;
    const response = await sdk.authentication.loginSnapTradeUser({
      userId: user.userId,
      userSecret: user.userSecret,
      redirectURI: process.env.SNAPTRADE_REDIRECT_URI || "ledger://snaptrade-callback",
      ...(brokerId ? { broker: brokerId } : {}),
    });
    const data = response.data || response;
    res.json({ url: data?.connectionPortalUrl || data?.redirectURI });
  })
);

// GET /snaptrade/accounts
router.get(
  "/accounts",
  asyncHandler(async (_req, res) => {
    const user = getUser();
    if (!user.userSecret) {
      return res.json({ accounts: [], partial: false });
    }
    const sdk = await getSnapTrade();
    const connectionsResp = await sdk.connections.listBrokerageAuthorizations({
      userId: user.userId,
      userSecret: user.userSecret,
    });
    const connections = JSON.parse(
      JSON.stringify(connectionsResp.data || connectionsResp || [])
    );
    const allAccounts = [];
    const failedConnections = [];
    for (const conn of connections) {
      try {
        const accsResp = await sdk.connections.listBrokerageAuthorizationAccounts({
          authorizationId: conn.id,
          userId: user.userId,
          userSecret: user.userSecret,
        });
        const accs = JSON.parse(JSON.stringify(accsResp.data || accsResp || []));
        for (const a of accs) {
          allAccounts.push({
            id: a.id,
            name: a.name,
            brokerage: conn.brokerage?.name || conn.brokerage?.slug || "Unknown",
            number: a.number,
            institution: a.institution,
            syncStatus: conn.syncStatus,
            connectionId: conn.id,
          });
        }
      } catch (e) {
        console.error(`Failed to list accounts for connection ${conn.id}:`, e?.message);
        failedConnections.push(conn.id);
      }
    }
    // Surface partial failures so the client can warn instead of silently
    // showing an incomplete portfolio.
    res.json({
      accounts: allAccounts,
      partial: failedConnections.length > 0,
      failedConnections,
    });
  })
);

// GET /snaptrade/accounts/:id/holdings
router.get(
  "/accounts/:id/holdings",
  validateParam("id", idSchema),
  requireUser,
  asyncHandler(async (req, res) => {
    const sdk = await getSnapTrade();
    const accountId = req.params.id;
    const user = getUser();
    const params = { accountId, userId: user.userId, userSecret: user.userSecret };

    const [positionsResp, balancesResp] = await Promise.all([
      sdk.accountInformation.getUserAccountPositions(params),
      sdk.accountInformation.getUserAccountBalance(params),
    ]);

    const cleanPositions = JSON.parse(
      JSON.stringify(positionsResp.data || positionsResp || [])
    );
    const cleanBalances = JSON.parse(
      JSON.stringify(balancesResp.data || balancesResp || {})
    );
    const positions = Array.isArray(cleanPositions) ? cleanPositions : [];

    const holdings = positions.map((p) => {
      const units = p.units ?? p.quantity ?? 0;
      const price = p.price ?? 0;
      const symObj = p.symbol?.symbol ?? p.symbol ?? {};
      const sym = symObj.symbol || symObj.raw_symbol || "UNKNOWN";
      const name = symObj.description || sym || "Unknown";
      return {
        symbol: sym,
        name,
        quantity: units,
        avgCost: p.averagePurchasePrice ?? p.averagePrice ?? null,
        marketValue: units * price,
        dayChange: null,
        dayChangePercent: null,
      };
    });

    const totalValue =
      cleanBalances?.total?.[0]?.value ??
      holdings.reduce((s, h) => s + h.marketValue, 0);

    res.json({
      accountId,
      totalValue,
      currency: cleanBalances?.total?.[0]?.currency || "USD",
      holdings,
      lastSynced: new Date().toISOString(),
    });
  })
);

// GET /snaptrade/accounts/:id/transactions
router.get(
  "/accounts/:id/transactions",
  validateParam("id", idSchema),
  requireUser,
  asyncHandler(async (req, res) => {
    const sdk = await getSnapTrade();
    const accountId = req.params.id;
    const user = getUser();
    const ordersResp = await sdk.accountInformation.getUserAccountOrders({
      accountId,
      userId: user.userId,
      userSecret: user.userSecret,
    });
    const rawOrders = JSON.parse(JSON.stringify(ordersResp.data || ordersResp || []));
    const orders = Array.isArray(rawOrders) ? rawOrders : [];
    const transactions = orders.map((o) => {
      const symObj = o.symbol?.symbol ?? o.symbol ?? {};
      const sym = symObj.symbol || symObj.raw_symbol || "";
      return {
        id: o.id,
        symbol: sym,
        type: o.action,
        quantity: o.units,
        price: o.price,
        amount: (o.units ?? 0) * (o.price ?? 0),
        // Leave null when the upstream has no usable date — the client renders
        // "—" rather than pretending the trade happened now.
        date: o.executionPrice?.asOf || o.createdDate || o.timeExecuted || null,
        description: `${o.action || "order"} ${o.units ?? ""} ${sym}`.trim(),
      };
    });
    res.json({ transactions });
  })
);

// DELETE /snaptrade/connections/:id
router.delete(
  "/connections/:id",
  validateParam("id", idSchema),
  requireUser,
  asyncHandler(async (req, res) => {
    const sdk = await getSnapTrade();
    const user = getUser();
    await sdk.connections.deleteConnection({
      authorizationId: req.params.id,
      userId: user.userId,
      userSecret: user.userSecret,
    });
    res.json({ disconnected: true });
  })
);

// POST /snaptrade/refresh/:connectionId
router.post(
  "/refresh/:connectionId",
  validateParam("connectionId", idSchema),
  requireUser,
  asyncHandler(async (req, res) => {
    const sdk = await getSnapTrade();
    const user = getUser();
    await sdk.connections.refreshBrokerageAuthorization({
      authorizationId: req.params.connectionId,
      userId: user.userId,
      userSecret: user.userSecret,
    });
    res.json({ refreshing: true });
  })
);

export default router;

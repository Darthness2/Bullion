// SnapTrade proxy routes.
//
// All SnapTrade operations that require the consumerKey happen HERE —
// never in the iOS app. The app calls these endpoints only.
//
// Verified against SnapTrade SDK v10 (snaptrade-typescript-sdk@10.0.14)
// by inspecting the actual runtime exports:
//   - new Snaptrade({ clientId, consumerKey })
//   - s.authentication.registerSnapTradeUser({ userId })
//   - s.authentication.loginSnapTradeUser({ userId, userSecret, ... })
//   - s.connections.listBrokerageAuthorizations({ userId, userSecret })
//   - s.connections.listBrokerageAuthorizationAccounts({ authorizationId, userId, userSecret })
//   - s.connections.deleteConnection({ authorizationId, userId, userSecret })
//   - s.connections.refreshBrokerageAuthorization({ authorizationId, userId, userSecret })
//   - s.accountInformation.getUserAccountPositions({ accountId, userId, userSecret })
//   - s.accountInformation.getUserAccountBalance({ accountId, userId, userSecret })
//   - s.accountInformation.getUserAccountOrders({ accountId, userId, userSecret })

import { Router } from "express";

const router = Router();

// TODO: real auth — replace with JWT/session/OAuth tied to real user identity.
// For v1 dev we use the SnapTrade userId/userSecret from .env or
// ~/.config/snaptrade/settings.json.
// Read lazily because ES module imports are hoisted before dotenv.config().
function getUser() {
  return {
    userId: process.env.SNAPTRADE_USER_ID || "bullion-dev-user",
    userSecret: process.env.SNAPTRADE_USER_SECRET || "",
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

router.use(requireKeys);

// POST /snaptrade/register-user
// Idempotent: registers or returns existing SnapTrade user for this person.
// If the user already exists (400 from SnapTrade) and we already have a
// userSecret in .env, we just return the userId.
router.post("/register-user", async (_req, res) => {
  // If we already have a userSecret, the user is already registered.
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
      process.env.SNAPTRADE_USER_SECRET = data.userSecret;
    }
    res.json({ userId: data?.userId || user.userId, registered: true });
  } catch (err) {
    // 400 usually means the user already exists but we don't have the secret.
    // In that case, the operator needs to reset the secret via the SnapTrade dashboard.
    console.error("register-user failed:", err?.message?.substring(0, 200) || err);
    res.status(500).json({
      error: "Failed to register SnapTrade user. If the user already exists, set SNAPTRADE_USER_SECRET in .env.",
    });
  }
});

// POST /snaptrade/connection-portal-url
// Returns a one-time Connection Portal login URL for ASWebAuthenticationSession.
router.post("/connection-portal-url", async (req, res) => {
  try {
    const user = getUser();
    if (!user.userSecret) {
      return res.status(400).json({ error: "User not registered. Call /register-user first." });
    }
    const sdk = await getSnapTrade();
    const body = req.body || {};
    const response = await sdk.authentication.loginSnapTradeUser({
      userId: user.userId,
      userSecret: user.userSecret,
      redirectURI: process.env.SNAPTRADE_REDIRECT_URI || "ledger://snaptrade-callback",
      ...(body.brokerId ? { broker: body.brokerId } : {}),
    });
    const data = response.data || response;
    res.json({ url: data?.connectionPortalUrl || data?.redirectURI });
  } catch (err) {
    console.error("connection-portal-url failed:", err?.message || err);
    res.status(500).json({ error: "Failed to generate Connection Portal URL." });
  }
});

// GET /snaptrade/accounts
// Lists all connected brokerage accounts for the user.
router.get("/accounts", async (_req, res) => {
  try {
    const user = getUser();
    if (!user.userSecret) {
      return res.json({ accounts: [] });
    }
    const sdk = await getSnapTrade();
    // Step 1: list connections (brokerage authorizations).
    const connectionsResp = await sdk.connections.listBrokerageAuthorizations({
      userId: user.userId,
      userSecret: user.userSecret,
    });
    const connections = JSON.parse(JSON.stringify(connectionsResp.data || connectionsResp || []));
    // Step 2: for each connection, list its accounts.
    const allAccounts = [];
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
      }
    }
    res.json({ accounts: allAccounts });
  } catch (err) {
    console.error("accounts failed:", err?.message || err);
    res.status(500).json({ error: "Failed to list accounts." });
  }
});

// GET /snaptrade/accounts/:id/holdings
// Returns positions + balances for one account.
router.get("/accounts/:id/holdings", async (req, res) => {
  try {
    const sdk = await getSnapTrade();
    const accountId = req.params.id;
    const user = getUser();
    const params = { accountId, userId: user.userId, userSecret: user.userSecret };

    const [positionsResp, balancesResp] = await Promise.all([
      sdk.accountInformation.getUserAccountPositions(params),
      sdk.accountInformation.getUserAccountBalance(params),
    ]);

    const positions = positionsResp.data || positionsResp || [];
    const balances = balancesResp.data || balancesResp || {};

    // The SDK wraps objects with getters that cause recursive access.
    // Stringify + re-parse to get plain objects.
    const cleanPositions = JSON.parse(JSON.stringify(positions));
    const cleanBalances = JSON.parse(JSON.stringify(balances));

    const holdings = cleanPositions.map((p) => {
      const units = p.units ?? p.quantity ?? 0;
      const price = p.price ?? 0;
      // SnapTrade SDK v10 wraps symbol in an extra layer:
      // p.symbol.symbol.symbol = "LLY", p.symbol.symbol.description = "Eli Lilly..."
      const symObj = p.symbol?.symbol ?? p.symbol ?? {};
      const sym = symObj.symbol || symObj.raw_symbol || "UNKNOWN";
      const name = symObj.description || sym || "Unknown";
      return {
        symbol: sym,
        name: name,
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
  } catch (err) {
    console.error("holdings failed:", err?.message || err);
    res.status(500).json({ error: "Failed to fetch holdings." });
  }
});

// GET /snaptrade/accounts/:id/transactions
// Returns recent activity (orders).
router.get("/accounts/:id/transactions", async (req, res) => {
  try {
    const sdk = await getSnapTrade();
    const accountId = req.params.id;
    const user = getUser();
    const ordersResp = await sdk.accountInformation.getUserAccountOrders({
      accountId,
      userId: user.userId,
      userSecret: user.userSecret,
    });
    const rawOrders = ordersResp.data || ordersResp || [];
    const orders = JSON.parse(JSON.stringify(rawOrders));
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
        date: o.executionPrice?.asOf || o.createdDate || new Date().toISOString(),
        description: `${o.action || "order"} ${o.units ?? ""} ${sym}`.trim(),
      };
    });
    res.json({ transactions });
  } catch (err) {
    console.error("transactions failed:", err?.message || err);
    res.status(500).json({ error: "Failed to fetch transactions." });
  }
});

// DELETE /snaptrade/connections/:id
// Disconnect a brokerage connection (read-only app: no trading).
router.delete("/connections/:id", async (req, res) => {
  try {
    const sdk = await getSnapTrade();
    const user = getUser();
    await sdk.connections.deleteConnection({
      authorizationId: req.params.id,
      userId: user.userId,
      userSecret: user.userSecret,
    });
    res.json({ disconnected: true });
  } catch (err) {
    console.error("disconnect failed:", err?.message || err);
    res.status(500).json({ error: "Failed to disconnect." });
  }
});

// POST /snaptrade/refresh/:connectionId
// Trigger a re-sync of a connection.
router.post("/refresh/:connectionId", async (req, res) => {
  try {
    const sdk = await getSnapTrade();
    const user = getUser();
    await sdk.connections.refreshBrokerageAuthorization({
      authorizationId: req.params.connectionId,
      userId: user.userId,
      userSecret: user.userSecret,
    });
    res.json({ refreshing: true });
  } catch (err) {
    console.error("refresh failed:", err?.message || err);
    res.status(500).json({ error: "Failed to refresh connection." });
  }
});

export default router;
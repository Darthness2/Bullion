import express from "express";
import cors from "cors";
import dotenv from "dotenv";

dotenv.config();

const app = express();
const PORT = process.env.PORT || 8787;

// Plaid API base URL — sandbox/development/production
const PLAID_ENV = process.env.PLAID_ENV || "sandbox";
const PLAID_BASE = `https://${PLAID_ENV}.plaid.com`;

const PLAID_CLIENT_ID = process.env.PLAID_CLIENT_ID;
const PLAID_SECRET = process.env.PLAID_SECRET;

// Demo mode: if Plaid credentials aren't set, return mock data so the app
// is fully functional for testing. When real credentials are added to .env,
// the server switches to real Plaid API calls automatically.
const DEMO_MODE = !PLAID_CLIENT_ID || !PLAID_SECRET || PLAID_CLIENT_ID === "PLACEHOLDER_FILL_ME_IN";

if (DEMO_MODE) {
  console.log("⚠️  Running in DEMO MODE — add Plaid credentials to .env for real broker linking");
} else {
  console.log("✅ Plaid credentials configured — real API mode");
}

// CORS: allow the iOS app
const allowedOrigins = (process.env.CORS_ORIGIN || "*").split(",").map(s => s.trim());
app.use(cors({
  origin: (origin, callback) => {
    if (!origin || allowedOrigins.includes("*") || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error("Not allowed by CORS"));
    }
  }
}));
app.use(express.json());

// Health check
app.get("/health", (req, res) => {
  res.json({ status: "ok", env: PLAID_ENV, demo: DEMO_MODE });
});

/**
 * Create a link token — the iOS app calls this to initialize Plaid Link.
 */
app.post("/api/link_token", async (req, res) => {
  if (DEMO_MODE) {
    // Return a fake link token — the app will open a mock connect flow
    return res.json({
      link_token: "link-demo-mode-token",
      expiration: 60,
      request_id: "demo-request-id"
    });
  }

  try {
    const resp = await fetch(`${PLAID_BASE}/link/token/create`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        client_id: PLAID_CLIENT_ID,
        secret: PLAID_SECRET,
        products: ["investments"],
        country_codes: ["US"],
        language: "en",
        client_name: "Bullion",
        redirect_uri: req.body.redirect_uri || "bullion://plaid-callback",
      })
    });
    const data = await resp.json();
    if (!resp.ok) {
      return res.status(resp.status).json(data);
    }
    res.json(data);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * Exchange a public_token for an access_token. In demo mode, returns a
 * fake access token so the app can proceed to fetch mock holdings.
 */
app.post("/api/exchange_token", async (req, res) => {
  if (DEMO_MODE) {
    return res.json({
      access_token: "demo-access-token",
      item_id: "demo-item-id",
      request_id: "demo-exchange-request-id"
    });
  }

  try {
    const { public_token } = req.body;
    if (!public_token) {
      return res.status(400).json({ error: "public_token required" });
    }
    const resp = await fetch(`${PLAID_BASE}/item/public_token/exchange`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        client_id: PLAID_CLIENT_ID,
        secret: PLAID_SECRET,
        public_token
      })
    });
    const data = await resp.json();
    if (!resp.ok) {
      return res.status(resp.status).json(data);
    }
    res.json({
      access_token: data.access_token,
      item_id: data.item_id,
      request_id: data.request_id
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * Proxy data calls to Plaid — in demo mode, returns mock holdings/transactions.
 * This endpoint is called directly from the iOS device.
 */
app.post("/api/plaid/*", async (req, res) => {
  if (DEMO_MODE) {
    const path = req.params["0"];
    if (path.includes("holdings")) {
      return res.json(mockHoldings());
    }
    if (path.includes("balance") || path.includes("accounts")) {
      return res.json(mockBalances());
    }
    if (path.includes("transactions")) {
      return res.json(mockTransactions());
    }
    return res.json({});
  }

  // Real mode: forward to Plaid
  try {
    const plaidPath = req.params["0"];
    const body = { ...req.body, client_id: PLAID_CLIENT_ID, secret: PLAID_SECRET };
    const resp = await fetch(`${PLAID_BASE}/${plaidPath}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body)
    });
    const data = await resp.json();
    if (!resp.ok) {
      return res.status(resp.status).json(data);
    }
    res.json(data);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- Mock data for demo mode ---

function mockBalances() {
  return {
    accounts: [
      {
        account_id: "acc-demo-1",
        name: "Margin Account",
        official_name: "Fidelity Margin Account",
        balances: { current: 152340.55, available: 50000, investment: 152340.55, iso_currency_code: "USD" },
        subtype: "brokerage",
        type: "investment"
      },
      {
        account_id: "acc-demo-2",
        name: "Roth IRA",
        official_name: "Schwab Roth IRA",
        balances: { current: 48210.10, available: 0, investment: 48210.10, iso_currency_code: "USD" },
        subtype: "ira",
        type: "investment"
      }
    ],
    item: { item_id: "demo-item-id", institution_id: "ins_fidelity", institution_name: "Fidelity" }
  };
}

function mockHoldings() {
  return {
    accounts: [
      { account_id: "acc-demo-1", name: "Margin Account", balances: { current: 152340.55, iso_currency_code: "USD" } },
      { account_id: "acc-demo-2", name: "Roth IRA", balances: { current: 48210.10, iso_currency_code: "USD" } }
    ],
    holdings: [
      { account_id: "acc-demo-1", security_id: "sec-aapl", quantity: 120, cost_basis: 165.40, institution_price: 214.32, latest_price: 214.32, ticker_symbol: "AAPL", name: "Apple Inc." },
      { account_id: "acc-demo-1", security_id: "sec-nvda", quantity: 200, cost_basis: 42.10, institution_price: 124.55, latest_price: 124.55, ticker_symbol: "NVDA", name: "NVIDIA Corporation" },
      { account_id: "acc-demo-1", security_id: "sec-msft", quantity: 80, cost_basis: 310.25, institution_price: 428.90, latest_price: 428.90, ticker_symbol: "MSFT", name: "Microsoft Corporation" },
      { account_id: "acc-demo-1", security_id: "sec-tsla", quantity: 60, cost_basis: 220.00, institution_price: 248.50, latest_price: 248.50, ticker_symbol: "TSLA", name: "Tesla, Inc." },
      { account_id: "acc-demo-1", security_id: "sec-spy", quantity: 50, cost_basis: 480.00, institution_price: 543.21, latest_price: 543.21, ticker_symbol: "SPY", name: "SPDR S&P 500 ETF" },
      { account_id: "acc-demo-2", security_id: "sec-googl", quantity: 30, cost_basis: 125.00, institution_price: 178.40, latest_price: 178.40, ticker_symbol: "GOOGL", name: "Alphabet Inc." },
      { account_id: "acc-demo-2", security_id: "sec-amzn", quantity: 40, cost_basis: 130.00, institution_price: 186.50, latest_price: 186.50, ticker_symbol: "AMZN", name: "Amazon.com, Inc." }
    ],
    securities: [
      { security_id: "sec-aapl", ticker_symbol: "AAPL", name: "Apple Inc.", type: "equity", close_price: 214.32 },
      { security_id: "sec-nvda", ticker_symbol: "NVDA", name: "NVIDIA Corporation", type: "equity", close_price: 124.55 },
      { security_id: "sec-msft", ticker_symbol: "MSFT", name: "Microsoft Corporation", type: "equity", close_price: 428.90 },
      { security_id: "sec-tsla", ticker_symbol: "TSLA", name: "Tesla, Inc.", type: "equity", close_price: 248.50 },
      { security_id: "sec-spy", ticker_symbol: "SPY", name: "SPDR S&P 500 ETF", type: "etf", close_price: 543.21 },
      { security_id: "sec-googl", ticker_symbol: "GOOGL", name: "Alphabet Inc.", type: "equity", close_price: 178.40 },
      { security_id: "sec-amzn", ticker_symbol: "AMZN", name: "Amazon.com, Inc.", type: "equity", close_price: 186.50 }
    ]
  };
}

function mockTransactions() {
  return {
    investment_transactions: [
      { investment_transaction_id: "t1", account_id: "acc-demo-1", amount: -2366.00, quantity: 20, price: 118.30, type: "buy", name: "Bought 20 NVDA", date: "2026-06-28", ticker_symbol: "NVDA" },
      { investment_transaction_id: "t2", account_id: "acc-demo-1", amount: 24.15, quantity: null, price: null, type: "dividend", name: "Dividend payment AAPL", date: "2026-06-24", ticker_symbol: "AAPL" },
      { investment_transaction_id: "t3", account_id: "acc-demo-1", amount: 2520.00, quantity: 10, price: 252.00, type: "sell", name: "Sold 10 TSLA", date: "2026-06-21", ticker_symbol: "TSLA" },
      { investment_transaction_id: "t4", account_id: "acc-demo-2", amount: -5352.00, quantity: 30, price: 178.40, type: "buy", name: "Bought 30 GOOGL", date: "2026-06-20", ticker_symbol: "GOOGL" }
    ],
    total_transactions: 4
  };
}

app.listen(PORT, () => {
  console.log(`Bullion Plaid backend running on port ${PORT} (${PLAID_ENV})${DEMO_MODE ? " [DEMO MODE]" : ""}`);
});
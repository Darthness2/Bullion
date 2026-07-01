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

if (!PLAID_CLIENT_ID || !PLAID_SECRET) {
  console.error("FATAL: PLAID_CLIENT_ID and PLAID_SECRET must be set in .env");
  process.exit(1);
}

// CORS: allow the iOS app (via custom scheme) and dev origins
const allowedOrigins = (process.env.CORS_ORIGIN || "*").split(",").map(s => s.trim());
app.use(cors({
  origin: (origin, callback) => {
    // Allow requests with no origin (iOS app, curl, etc.)
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
  res.json({ status: "ok", env: PLAID_ENV });
});

/**
 * Create a link token — the iOS app calls this to initialize Plaid Link.
 * The client_id and secret stay server-side; the device only gets the
 * link_token which is safe to expose.
 */
app.post("/api/link_token", async (req, res) => {
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
        // The iOS app's custom URL scheme for OAuth redirects
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
 * Exchange a public_token (from Plaid Link on the device) for an
 * access_token. This is the ONLY endpoint that handles secrets —
 * the access_token is returned to the device, stored in iOS Keychain,
 * and used for all subsequent data calls (client-side).
 */
app.post("/api/exchange_token", async (req, res) => {
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
    // Return access_token + item_id to the device
    res.json({
      access_token: data.access_token,
      item_id: data.item_id,
      request_id: data.request_id
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.listen(PORT, () => {
  console.log(`Bullion Plaid backend running on port ${PORT} (${PLAID_ENV})`);
});
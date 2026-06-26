import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import snaptradeRoutes from "./routes/snaptrade.js";
import marketRoutes from "./routes/market.js";

dotenv.config();

// Fail loud instead of silently on unhandled async errors.
process.on("unhandledRejection", (reason) => {
  console.error("Unhandled promise rejection:", reason);
});
process.on("uncaughtException", (err) => {
  console.error("Uncaught exception:", err);
});

const app = express();

// Validate PORT rather than letting an invalid value silently bind to :0.
const port = Number.parseInt(process.env.PORT || "8787", 10);
if (Number.isNaN(port) || port < 1 || port > 65535) {
  console.error(`Invalid PORT "${process.env.PORT}". Must be 1–65535.`);
  process.exit(1);
}

const corsOrigin = process.env.CORS_ORIGIN || "*";
if (corsOrigin === "*") {
  console.warn(
    "WARNING: CORS_ORIGIN is '*' (any origin). Set it explicitly for a non-local deployment."
  );
}
app.use(cors({ origin: corsOrigin }));

// Cap request bodies — these endpoints only take tiny JSON payloads.
app.use(express.json({ limit: "10kb" }));

// Simple request logger (method + path only — never bodies/headers, which
// could contain secrets).
app.use((req, _res, next) => {
  console.log(`${new Date().toISOString()} ${req.method} ${req.path}`);
  next();
});

// Health check. Reports whether SnapTrade is actually configured so an
// orchestrator can tell "up" from "up but non-functional".
app.get("/health", (_req, res) => {
  const snaptradeConfigured = Boolean(
    process.env.SNAPTRADE_CLIENT_ID && process.env.SNAPTRADE_CONSUMER_KEY
  );
  res.json({
    status: "ok",
    version: "0.1.0",
    snaptradeConfigured,
  });
});

// Routes
app.use("/snaptrade", snaptradeRoutes);
app.use("/market", marketRoutes);

// 404 + error handlers
app.use((_req, res) => {
  res.status(404).json({ error: "Not found" });
});

// Express error handler — handles malformed JSON (body-parser) and anything
// thrown synchronously in a handler.
app.use((err, _req, res, _next) => {
  if (err?.type === "entity.too.large") {
    return res.status(413).json({ error: "Request body too large." });
  }
  if (err?.type === "entity.parse.failed") {
    return res.status(400).json({ error: "Malformed JSON body." });
  }
  console.error("Unhandled error:", err?.message || err);
  res.status(500).json({ error: "Internal server error" });
});

// Bind to '::' so the server accepts both IPv6 (::1) and IPv4 (127.0.0.1)
// connections. Node defaults to IPv4-only, which breaks `localhost` on macOS
// where it resolves to ::1 first — URLSession then gets ECONNREFUSED.
app.listen(port, "::", () => {
  console.log(`Bullion backend listening on http://localhost:${port} (IPv4 + IPv6)`);
  if (!process.env.SNAPTRADE_CLIENT_ID || !process.env.SNAPTRADE_CONSUMER_KEY) {
    console.warn(
      "WARNING: SNAPTRADE_CLIENT_ID or SNAPTRADE_CONSUMER_KEY not set. SnapTrade routes will not work."
    );
  }
  if (!process.env.BULLION_API_TOKEN) {
    console.warn(
      "WARNING: BULLION_API_TOKEN not set — /snaptrade endpoints are UNAUTHENTICATED. Set it before deploying."
    );
  }
});

export default app;

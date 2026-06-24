import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import snaptradeRoutes from "./routes/snaptrade.js";
import marketRoutes from "./routes/market.js";

dotenv.config();

const app = express();
const port = process.env.PORT || 8787;

app.use(
  cors({
    origin: process.env.CORS_ORIGIN || "*",
  })
);
app.use(express.json());

// Simple request logger
app.use((req, _res, next) => {
  console.log(`${new Date().toISOString()} ${req.method} ${req.path}`);
  next();
});

// Health check
app.get("/health", (_req, res) => {
  res.json({ status: "ok", version: "0.1.0" });
});

// Routes
app.use("/snaptrade", snaptradeRoutes);
app.use("/market", marketRoutes);

// 404 + error handlers
app.use((_req, res) => {
  res.status(404).json({ error: "Not found" });
});

app.use((err, _req, res, _next) => {
  console.error("Unhandled error:", err);
  res.status(500).json({ error: "Internal server error" });
});

app.listen(port, () => {
  console.log(`Bullion backend listening on http://localhost:${port}`);
  if (!process.env.SNAPTRADE_CLIENT_ID || !process.env.SNAPTRADE_CONSUMER_KEY) {
    console.warn(
      "WARNING: SNAPTRADE_CLIENT_ID or SNAPTRADE_CONSUMER_KEY not set. SnapTrade routes will not work."
    );
  }
});

export default app;
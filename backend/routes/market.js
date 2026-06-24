// Market data is handled entirely client-side via Yahoo Finance.
// No API key needed, no rate limit, no proxy required.
// This file is kept for potential future use if we need to proxy data.

import { Router } from "express";

const router = Router();

router.get("/health", (_req, res) => {
  res.json({ status: "ok", message: "Market data uses Yahoo Finance directly — no proxy needed." });
});

export default router;
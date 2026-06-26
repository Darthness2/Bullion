// Shared helpers for the Bullion serverless SnapTrade proxy.
// Vercel serverless functions are stateless: the SnapTrade userSecret is read
// from an environment variable (set once after the first /register-user call)
// rather than a filesystem file.

import { z } from "zod";

// --- Auth gate ---------------------------------------------------------------
// v1 has a single backend user, so this is a shared bearer token. If
// BULLION_API_TOKEN is unset we stay open (dev), but a warning is surfaced
// via the /health endpoint's `tokenConfigured` field.
export function requireAuth(req) {
  const expected = process.env.BULLION_API_TOKEN;
  if (!expected) return { ok: true }; // dev mode: open
  const header = req.headers.get("authorization") || req.headers.get("Authorization") || "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : null;
  if (token !== expected) {
    return { ok: false, response: json({ error: "Unauthorized." }, { status: 401 }) };
  }
  return { ok: true };
}

// --- User identity -----------------------------------------------------------
export function getUser() {
  return {
    userId: process.env.SNAPTRADE_USER_ID || "bullion-dev-user",
    userSecret: process.env.SNAPTRADE_USER_SECRET || "",
  };
}

export function hasUserSecret() {
  return Boolean(getUser().userSecret);
}

// --- SnapTrade SDK client (lazily initialized, per-invocation cache) --------
let snaptrade = null;
export async function getSnapTrade() {
  if (snaptrade) return snaptrade;
  const { Snaptrade } = await import("snaptrade-typescript-sdk");
  snaptrade = new Snaptrade({
    clientId: process.env.SNAPTRADE_CLIENT_ID,
    consumerKey: process.env.SNAPTRADE_CONSUMER_KEY,
  });
  return snaptrade;
}

// --- Validation --------------------------------------------------------------
export const idSchema = z.string().trim().min(1).max(128);

export function validateId(value, name = "id") {
  const result = idSchema.safeParse(value);
  if (!result.success) return { ok: false, response: json({ error: `Invalid ${name}.` }, { status: 400 }) };
  return { ok: true, value: result.data };
}

// --- Response helper ---------------------------------------------------------
export function json(body, init = {}) {
  return new Response(JSON.stringify(body), {
    headers: { "content-type": "application/json; charset=utf-8", ...corsHeaders() },
    ...init,
  });
}

export function corsHeaders() {
  const origin = process.env.CORS_ORIGIN || "*";
  return {
    "access-control-allow-origin": origin,
    "access-control-allow-methods": "GET,POST,DELETE,OPTIONS",
    "access-control-allow-headers": "Content-Type, Authorization",
  };
}

// --- Guard helpers -----------------------------------------------------------
export function requireConfigured() {
  if (!process.env.SNAPTRADE_CLIENT_ID || !process.env.SNAPTRADE_CONSUMER_KEY) {
    return json({ error: "SnapTrade credentials not configured." }, { status: 503 });
  }
  return null;
}

export function requireRegisteredUser() {
  if (!hasUserSecret()) {
    return json({ error: "User not registered. Call /snaptrade/register-user first." }, { status: 400 });
  }
  return null;
}

// --- SnapTrade response normalizer -------------------------------------------
// The SDK wraps responses with getters that cause recursive access; stringify
// + re-parse to get plain objects.
export function clean(resp) {
  return JSON.parse(JSON.stringify(resp.data || resp || []));
}
// POST /api/snaptrade/register-user
// Idempotent: returns the existing SnapTrade user if a userSecret env var is
// set. Otherwise registers a new user.
//
// IMPORTANT: serverless is stateless. After the FIRST successful registration,
// copy the returned `userSecret` into your Vercel project env vars as
// SNAPTRADE_USER_SECRET and redeploy. Subsequent calls then short-circuit.
import { json, corsHeaders, requireAuth, getUser, getSnapTrade, requireConfigured, clean } from "../api/_lib/snaptrade.js";

export async function POST(req) {
  const auth = requireAuth(req);
  if (!auth.ok) return auth.response;
  const notConfigured = requireConfigured();
  if (notConfigured) return notConfigured;

  const user = getUser();
  if (user.userSecret) {
    return json({ userId: user.userId, registered: true, existing: true });
  }

  try {
    const sdk = await getSnapTrade();
    const response = await sdk.authentication.registerSnapTradeUser({ userId: user.userId });
    const data = clean(response);
    return json({
      userId: data?.userId || user.userId,
      registered: true,
      userSecret: data?.userSecret || null,
      // Note to operator: persist this as SNAPTRADE_USER_SECRET env var.
      note: "Set SNAPTRADE_USER_SECRET in Vercel env vars and redeploy to persist registration.",
    });
  } catch (err) {
    console.error("register-user failed:", err?.message?.substring(0, 200) || "error");
    return json(
      { error: "Failed to register SnapTrade user. If the user already exists, set SNAPTRADE_USER_SECRET in env." },
      { status: 500 }
    );
  }
}

export async function OPTIONS() {
  return new Response(null, { status: 204, headers: corsHeaders() });
}
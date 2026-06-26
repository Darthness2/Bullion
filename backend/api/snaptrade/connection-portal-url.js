// POST /api/snaptrade/connection-portal-url
import { z } from "zod";
import { json, corsHeaders, requireAuth, requireConfigured, requireRegisteredUser, getUser, getSnapTrade, clean } from "../api/_lib/snaptrade.js";

const portalBodySchema = z.object({ brokerId: z.string().trim().max(64).optional() });

export async function POST(req) {
  const auth = requireAuth(req);
  if (!auth.ok) return auth.response;
  const notConfigured = requireConfigured();
  if (notConfigured) return notConfigured;
  const notRegistered = requireRegisteredUser();
  if (notRegistered) return notRegistered;

  let body = {};
  try { body = await req.json(); } catch { /* empty body is fine */ }
  const parsed = portalBodySchema.safeParse(body || {});
  if (!parsed.success) return json({ error: "Invalid request body." }, { status: 400 });

  const user = getUser();
  const sdk = await getSnapTrade();
  const { brokerId } = parsed.data;
  const response = await sdk.authentication.loginSnapTradeUser({
    userId: user.userId,
    userSecret: user.userSecret,
    redirectURI: process.env.SNAPTRADE_REDIRECT_URI || "ledger://snaptrade-callback",
    ...(brokerId ? { broker: brokerId } : {}),
  });
  const data = clean(response);
  return json({ url: data?.connectionPortalUrl || data?.redirectURI });
}

export async function OPTIONS() {
  return new Response(null, { status: 204, headers: corsHeaders() });
}
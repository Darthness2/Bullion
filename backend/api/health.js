// GET /api/health
import { json, corsHeaders } from "../api/_lib/snaptrade.js";

export async function GET() {
  const snaptradeConfigured = Boolean(
    process.env.SNAPTRADE_CLIENT_ID && process.env.SNAPTRADE_CONSUMER_KEY
  );
  const tokenConfigured = Boolean(process.env.BULLION_API_TOKEN);
  const userRegistered = Boolean(process.env.SNAPTRADE_USER_SECRET);
  return json({
    status: "ok",
    version: "0.2.0",
    snaptradeConfigured,
    tokenConfigured,
    userRegistered,
  });
}

export async function OPTIONS() {
  return new Response(null, { status: 204, headers: corsHeaders() });
}
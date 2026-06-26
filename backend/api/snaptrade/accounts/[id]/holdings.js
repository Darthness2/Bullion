// GET /api/snaptrade/accounts/:id/holdings
import { json, corsHeaders, requireAuth, requireConfigured, requireRegisteredUser, getUser, getSnapTrade, clean, validateId } from "../../_lib/snaptrade.js";

export async function GET(req, { params }) {
  const auth = requireAuth(req);
  if (!auth.ok) return auth.response;
  const notConfigured = requireConfigured();
  if (notConfigured) return notConfigured;
  const notRegistered = requireRegisteredUser();
  if (notRegistered) return notRegistered;

  const idCheck = validateId(params?.id);
  if (!idCheck.ok) return idCheck.response;
  const accountId = idCheck.value;

  const user = getUser();
  const sdk = await getSnapTrade();
  const p = { accountId, userId: user.userId, userSecret: user.userSecret };

  const [positionsResp, balancesResp] = await Promise.all([
    sdk.accountInformation.getUserAccountPositions(p),
    sdk.accountInformation.getUserAccountBalance(p),
  ]);

  const positions = Array.isArray(clean(positionsResp)) ? clean(positionsResp) : [];
  const balances = clean(balancesResp);

  const holdings = positions.map((p) => {
    const units = p.units ?? p.quantity ?? 0;
    const price = p.price ?? 0;
    const symObj = p.symbol?.symbol ?? p.symbol ?? {};
    const sym = symObj.symbol || symObj.raw_symbol || "UNKNOWN";
    const name = symObj.description || sym || "Unknown";
    return {
      symbol: sym,
      name,
      quantity: units,
      avgCost: p.averagePurchasePrice ?? p.averagePrice ?? null,
      marketValue: units * price,
      dayChange: null,
      dayChangePercent: null,
    };
  });

  const totalValue =
    balances?.total?.[0]?.value ??
    holdings.reduce((s, h) => s + h.marketValue, 0);

  return json({
    accountId,
    totalValue,
    currency: balances?.total?.[0]?.currency || "USD",
    holdings,
    lastSynced: new Date().toISOString(),
  });
}

export async function OPTIONS() {
  return new Response(null, { status: 204, headers: corsHeaders() });
}
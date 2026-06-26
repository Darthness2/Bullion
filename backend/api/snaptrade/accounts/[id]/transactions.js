// GET /api/snaptrade/accounts/:id/transactions
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
  const ordersResp = await sdk.accountInformation.getUserAccountOrders({
    accountId,
    userId: user.userId,
    userSecret: user.userSecret,
  });
  const rawOrders = clean(ordersResp);
  const orders = Array.isArray(rawOrders) ? rawOrders : [];
  const transactions = orders.map((o) => {
    const symObj = o.symbol?.symbol ?? o.symbol ?? {};
    const sym = symObj.symbol || symObj.raw_symbol || "";
    return {
      id: o.id,
      symbol: sym,
      type: o.action,
      quantity: o.units,
      price: o.price,
      amount: (o.units ?? 0) * (o.price ?? 0),
      date: o.executionPrice?.asOf || o.createdDate || o.timeExecuted || null,
      description: `${o.action || "order"} ${o.units ?? ""} ${sym}`.trim(),
    };
  });
  return json({ transactions });
}

export async function OPTIONS() {
  return new Response(null, { status: 204, headers: corsHeaders() });
}
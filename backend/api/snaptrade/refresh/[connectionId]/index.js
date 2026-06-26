// POST /api/snaptrade/refresh/:connectionId
import { json, corsHeaders, requireAuth, requireConfigured, requireRegisteredUser, getUser, getSnapTrade, validateId } from "../../_lib/snaptrade.js";

export async function POST(req, { params }) {
  const auth = requireAuth(req);
  if (!auth.ok) return auth.response;
  const notConfigured = requireConfigured();
  if (notConfigured) return notConfigured;
  const notRegistered = requireRegisteredUser();
  if (notRegistered) return notRegistered;

  const idCheck = validateId(params?.connectionId, "connectionId");
  if (!idCheck.ok) return idCheck.response;

  const user = getUser();
  const sdk = await getSnapTrade();
  await sdk.connections.refreshBrokerageAuthorization({
    authorizationId: idCheck.value,
    userId: user.userId,
    userSecret: user.userSecret,
  });
  return json({ refreshing: true });
}

export async function OPTIONS() {
  return new Response(null, { status: 204, headers: corsHeaders() });
}
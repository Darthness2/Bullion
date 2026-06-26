// DELETE /api/snaptrade/connections/:id
import { json, corsHeaders, requireAuth, requireConfigured, requireRegisteredUser, getUser, getSnapTrade, validateId } from "../../_lib/snaptrade.js";

export async function DELETE(req, { params }) {
  const auth = requireAuth(req);
  if (!auth.ok) return auth.response;
  const notConfigured = requireConfigured();
  if (notConfigured) return notConfigured;
  const notRegistered = requireRegisteredUser();
  if (notRegistered) return notRegistered;

  const idCheck = validateId(params?.id);
  if (!idCheck.ok) return idCheck.response;

  const user = getUser();
  const sdk = await getSnapTrade();
  await sdk.connections.deleteConnection({
    authorizationId: idCheck.value,
    userId: user.userId,
    userSecret: user.userSecret,
  });
  return json({ disconnected: true });
}

export async function OPTIONS() {
  return new Response(null, { status: 204, headers: corsHeaders() });
}
// GET /api/snaptrade/accounts
import { json, corsHeaders, requireAuth, requireConfigured, requireRegisteredUser, getUser, getSnapTrade, clean } from "../api/_lib/snaptrade.js";

export async function GET(req) {
  const auth = requireAuth(req);
  if (!auth.ok) return auth.response;
  const notConfigured = requireConfigured();
  if (notConfigured) return notConfigured;
  const notRegistered = requireRegisteredUser();
  if (notRegistered) return notRegistered;

  const user = getUser();
  const sdk = await getSnapTrade();
  const connectionsResp = await sdk.connections.listBrokerageAuthorizations({
    userId: user.userId,
    userSecret: user.userSecret,
  });
  const connections = clean(connectionsResp);
  const allAccounts = [];
  const failedConnections = [];
  for (const conn of connections) {
    try {
      const accsResp = await sdk.connections.listBrokerageAuthorizationAccounts({
        authorizationId: conn.id,
        userId: user.userId,
        userSecret: user.userSecret,
      });
      const accs = clean(accsResp);
      for (const a of accs) {
        allAccounts.push({
          id: a.id,
          name: a.name,
          brokerage: conn.brokerage?.name || conn.brokerage?.slug || "Unknown",
          number: a.number,
          institution: a.institution,
          syncStatus: conn.syncStatus,
          connectionId: conn.id,
        });
      }
    } catch (e) {
      console.error(`Failed to list accounts for connection ${conn.id}:`, e?.message);
      failedConnections.push(conn.id);
    }
  }
  return json({
    accounts: allAccounts,
    partial: failedConnections.length > 0,
    failedConnections,
  });
}

export async function OPTIONS() {
  return new Response(null, { status: 204, headers: corsHeaders() });
}
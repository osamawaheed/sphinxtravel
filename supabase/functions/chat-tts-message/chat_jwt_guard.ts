// =====================================================================
// Booking-scoped Odoo JWT guard for chat Edge Functions (local copy so the
// function bundles standalone). Active only when the function secret
// ODOO_CHAT_AUTH_ENABLED === "true"; otherwise `jwtAuthEnabled()` is false
// and the function keeps its existing (legacy) behaviour.
//
// The guard never decodes or trusts JWT claims itself. It forwards the
// caller's Authorization token to PostgREST and asks the DATABASE
// (chat_sec_can_view / chat_sec_can_send, SECURITY DEFINER, fail-closed).
// Identity is NEVER read from the request body on this path.
// =====================================================================

export type GuardOk = { ok: true };
export type GuardDeny = { ok: false; status: number; error: string };
export type GuardResult = GuardOk | GuardDeny;

export function jwtAuthEnabled(): boolean {
  return (Deno.env.get("ODOO_CHAT_AUTH_ENABLED") ?? "").toLowerCase() === "true";
}

function callerJwt(req: Request): string {
  const h = req.headers.get("authorization") ?? "";
  return h.toLowerCase().startsWith("bearer ") ? h.slice(7).trim() : "";
}

async function callPredicate(
  fn: "chat_sec_can_view" | "chat_sec_can_send",
  conversationId: string,
  jwt: string,
): Promise<boolean | "unauthorized" | "error"> {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  if (!url || !anon) return "error";
  try {
    const res = await fetch(`${url}/rest/v1/rpc/${fn}`, {
      method: "POST",
      headers: {
        apikey: anon,
        Authorization: `Bearer ${jwt}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ p_conversation_id: conversationId }),
    });
    if (res.status === 401 || res.status === 403) return "unauthorized";
    if (!res.ok) return "error";
    return (await res.json()) === true;
  } catch (_) {
    return "error";
  }
}

/**
 * Authorizes the caller for ONE conversation using their booking JWT.
 * `needSend` = true for actions that must be refused to a replaced driver.
 * Fails closed on every error path.
 */
export async function guardConversation(
  req: Request,
  conversationId: string,
  needSend: boolean,
): Promise<GuardResult> {
  const jwt = callerJwt(req);
  if (!jwt) return { ok: false, status: 401, error: "Unauthorized" };

  const view = await callPredicate("chat_sec_can_view", conversationId, jwt);
  if (view === "unauthorized") {
    return { ok: false, status: 401, error: "Unauthorized" };
  }
  if (view === "error") {
    return { ok: false, status: 503, error: "Authorization unavailable" };
  }
  if (view !== true) return { ok: false, status: 403, error: "Forbidden" };

  if (needSend) {
    const send = await callPredicate("chat_sec_can_send", conversationId, jwt);
    if (send === "error") {
      return { ok: false, status: 503, error: "Authorization unavailable" };
    }
    if (send !== true) return { ok: false, status: 403, error: "Forbidden" };
  }
  return { ok: true };
}

// =====================================================================
// Edge Function: chat-file-sign  (TEST) — NOT DEPLOYED AUTOMATICALLY
//
// Issues a SHORT-LIVED signed download URL for an attachment stored in the
// PRIVATE `chat-files` bucket. No AI service is involved; this file is
// independent from chat-translate / chat-transcribe-message.
//
// Request body: { message_id, viewer_role, viewer_id }
//
// Security (TEST architecture, NOT production-grade):
//   * Caller must present this project's anon / publishable key.
//   * The message must be a `file` message.
//   * Viewer must be the sender, or the opposite role in the same
//     conversation. Negative ids are TEST identities valid only on the TEST
//     booking (same rule as chat-transcribe-message).
//   * Signed URL lifetime: 300 seconds. Already-issued URLs cannot be
//     revoked before they expire.
// =====================================================================

type Row = Record<string, unknown>;

const BUCKET = "chat-files";
const URL_TTL_SECONDS = 300;
const TEST_BOOKING_REFERENCE = "RQ.TEST14596";
const UUID_RE =
  /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const json = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
      ...CORS,
    },
  });

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

function loadProjectKeys(): string[] {
  const keys: string[] = [];
  if (ANON_KEY) keys.push(ANON_KEY);
  const raw = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS") ?? "";
  if (raw) {
    try {
      const parsed = JSON.parse(raw);
      if (parsed && typeof parsed === "object") {
        for (const v of Object.values(parsed)) {
          if (typeof v === "string" && v.length > 0) keys.push(v);
        }
      } else if (typeof parsed === "string" && parsed.length > 0) {
        keys.push(parsed);
      }
    } catch {
      if (raw.length > 0) keys.push(raw);
    }
  }
  return keys;
}
const PROJECT_KEYS = loadProjectKeys();

const PROJECT_REF = (() => {
  try {
    return new URL(SUPABASE_URL).hostname.split(".")[0] ?? "";
  } catch {
    return "";
  }
})();

function jwtClaims(token: string): Record<string, unknown> | null {
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  try {
    const b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const padded = b64 + "=".repeat((4 - (b64.length % 4)) % 4);
    const parsed = JSON.parse(atob(padded));
    return parsed && typeof parsed === "object" ? parsed : null;
  } catch {
    return null;
  }
}

function isThisProjectAnon(token: string): boolean {
  const c = jwtClaims(token);
  if (!c || !PROJECT_REF) return false;
  return c.role === "anon" && c.ref === PROJECT_REF;
}

function hasProjectKey(req: Request): boolean {
  const apikey = req.headers.get("apikey") ?? "";
  const bearer = (req.headers.get("authorization") ?? "").replace(
    /^Bearer\s+/i,
    "",
  );
  const candidates = [apikey, bearer].filter((v) => v.length > 0);
  return candidates.some(
    (v) => PROJECT_KEYS.includes(v) || isThisProjectAnon(v),
  );
}

const restHeaders = {
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  "Content-Type": "application/json",
};

const rest = (path: string) => `${SUPABASE_URL}/rest/v1/${path}`;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return json({ ok: true });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  if (!SUPABASE_URL || !SERVICE_KEY || PROJECT_KEYS.length === 0) {
    return json({ error: "Function not configured" }, 503);
  }
  if (!hasProjectKey(req)) return json({ error: "Unauthorized" }, 401);

  let body: Row;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid request" }, 400);
  }

  const messageId = body?.message_id;
  const viewerRole = body?.viewer_role;
  const viewerId = Number(body?.viewer_id);
  if (
    typeof messageId !== "string" || !UUID_RE.test(messageId) ||
    (viewerRole !== "customer" && viewerRole !== "driver") ||
    !Number.isInteger(viewerId) || viewerId === 0
  ) {
    return json({ error: "Invalid request" }, 400);
  }

  try {
    const msgRes = await fetch(
      rest(
        `chat_messages?id=eq.${messageId}` +
          `&select=id,conversation_id,sender_role,odoo_sender_id,` +
          `message_type,file_path`,
      ),
      { headers: restHeaders },
    );
    if (!msgRes.ok) return json({ error: "Message lookup failed" }, 502);
    const rows = await msgRes.json();
    if (!Array.isArray(rows) || rows.length === 0) {
      return json({ error: "Forbidden" }, 403);
    }
    const msg = rows[0] as Row;
    if (msg.message_type !== "file" || !msg.file_path) {
      return json({ error: "Forbidden" }, 403);
    }

    const convRes = await fetch(
      rest(
        `chat_conversations?id=eq.${msg.conversation_id}` +
          `&select=id,booking_reference&limit=1`,
      ),
      { headers: restHeaders },
    );
    if (!convRes.ok) return json({ error: "Lookup failed" }, 502);
    const convs = await convRes.json();
    if (!Array.isArray(convs) || convs.length === 0) {
      return json({ error: "Forbidden" }, 403);
    }
    const isTestConv =
      String((convs[0] as Row).booking_reference ?? "").trim().toUpperCase() ===
        TEST_BOOKING_REFERENCE;
    if (viewerId < 0 && !isTestConv) return json({ error: "Forbidden" }, 403);

    const senderRole = String(msg.sender_role ?? "");
    const senderId = Number(msg.odoo_sender_id);
    if (viewerRole === senderRole) {
      if (viewerId !== senderId) return json({ error: "Forbidden" }, 403);
    } else if (isTestConv && viewerId < 0) {
      const expected = viewerRole === "customer" ? -1 : -2;
      if (viewerId !== expected) return json({ error: "Forbidden" }, 403);
    } else {
      // Recipient with a real Odoo id must already be a participant of this
      // conversation (has posted as this role, or is a recorded driver).
      let known = false;
      if (viewerRole === "driver") {
        const chgRes = await fetch(
          rest(
            `chat_driver_changes?conversation_id=eq.${msg.conversation_id}` +
              `&or=(new_driver_odoo_id.eq.${viewerId},` +
              `previous_driver_odoo_id.eq.${viewerId})&select=id&limit=1`,
          ),
          { headers: restHeaders },
        );
        if (chgRes.ok) {
          const chg = await chgRes.json();
          known = Array.isArray(chg) && chg.length > 0;
        }
      }
      if (!known) {
        const partRes = await fetch(
          rest(
            `chat_messages?conversation_id=eq.${msg.conversation_id}` +
              `&sender_role=eq.${viewerRole}&odoo_sender_id=eq.${viewerId}` +
              `&select=id&limit=1`,
          ),
          { headers: restHeaders },
        );
        if (partRes.ok) {
          const part = await partRes.json();
          known = Array.isArray(part) && part.length > 0;
        }
      }
      if (!known) return json({ error: "Forbidden" }, 403);
    }

    const objectPath = String(msg.file_path)
      .split("/")
      .map(encodeURIComponent)
      .join("/");
    const signRes = await fetch(
      `${SUPABASE_URL}/storage/v1/object/sign/${BUCKET}/${objectPath}`,
      {
        method: "POST",
        headers: restHeaders,
        body: JSON.stringify({ expiresIn: URL_TTL_SECONDS }),
      },
    );
    if (!signRes.ok) {
      console.error("sign file failed:", signRes.status);
      return json({ error: "File unavailable" }, 404);
    }
    const signed = await signRes.json();
    const rel = String(signed?.signedURL ?? signed?.signedUrl ?? "");
    if (!rel) return json({ error: "File unavailable" }, 404);
    const url = rel.startsWith("http")
      ? rel
      : `${SUPABASE_URL}/storage/v1${rel.startsWith("/") ? "" : "/"}${rel}`;
    return json({ status: "ok", url, expires_in: URL_TTL_SECONDS });
  } catch (e) {
    console.error("chat-file-sign error:", (e as Error)?.message ?? "unknown");
    return json({ error: "Internal error" }, 500);
  }
});

// ======================================================
// TourOps Smart Chat
// Edge Function: chat-sync-driver  (Phase 1 - Odoo -> Supabase driver sync)
//
// Called by the Flutter app when opening Smart Chat, BEFORE it queries
// chat_conversations. The client sends ONLY:
//   * body   { booking_id }
//   * header X-Odoo-Mobile-Authorization: Bearer <Odoo Mobile Access Token>
//   * header Authorization / apikey: Supabase anon key (gateway only)
//
// Security model:
//   * The driver id is NEVER read from the client. It is taken exclusively
//     from Odoo's authoritative GET /api/v1/chat/bookings/{booking_id}
//     response, which Odoo authorizes with the caller's own Mobile token.
//   * The Odoo token is forwarded once, in memory, to Odoo. It is never
//     logged, stored, echoed or returned.
//   * The service-role key exists only in this function's environment and is
//     used only to call chat_sec_ensure_conversation.
//   * chat_sec_ensure_conversation -> chat_sec_try_set_driver keeps the
//     stale-event / never-regress protection, so this call can never
//     overwrite a newer driver assignment.
//
// Required secrets (Supabase Edge Function secrets - set, do not commit):
//   SUPABASE_URL                 (provided by the platform)
//   SUPABASE_SERVICE_ROLE_KEY    (provided by the platform)
//   ODOO_API_BASE_URL            e.g. https://test.sphinx-travel.com (no path)
// ======================================================

const ODOO_TOKEN_HEADER = "x-odoo-mobile-authorization";
const ODOO_TIMEOUT_MS = 15000;

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info, x-odoo-mobile-authorization",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

function fail(status: number, error: string): Response {
  return json(status, { ok: false, error });
}

/** Extracts the Odoo Mobile Access Token from the dedicated header only. */
function odooToken(req: Request): string {
  const h = req.headers.get(ODOO_TOKEN_HEADER) ?? "";
  const token = h.toLowerCase().startsWith("bearer ") ? h.slice(7).trim() : "";
  return token;
}

function toPositiveInt(v: unknown): number | null {
  if (typeof v === "number" && Number.isSafeInteger(v) && v > 0) return v;
  if (typeof v === "string" && /^[0-9]{1,15}$/.test(v.trim())) {
    const n = Number(v.trim());
    return Number.isSafeInteger(n) && n > 0 ? n : null;
  }
  return null;
}

function asObject(v: unknown): Record<string, unknown> | null {
  return v !== null && typeof v === "object" && !Array.isArray(v)
    ? (v as Record<string, unknown>)
    : null;
}

type OdooBooking = {
  bookingId: number;
  reference: string;
  driverId: number;
  closed: boolean;
};

type OdooResult =
  | { ok: true; booking: OdooBooking }
  | { ok: false; status: number; error: string };

/** True when Odoo reports the trip/chat as completed or closed. */
function isClosedByOdoo(obj: Record<string, unknown>): boolean {
  if (obj["chat_closed"] === true || obj["is_closed"] === true ||
      obj["closed"] === true || obj["is_completed"] === true) {
    return true;
  }
  const trip = asObject(obj["trip"]);
  const statuses = [
    obj["status"], obj["trip_status"], obj["trip_state"], obj["state"],
    trip ? trip["status"] : null, trip ? trip["state"] : null,
  ];
  for (const s of statuses) {
    const v = typeof s === "string" ? s.trim().toLowerCase() : "";
    if (v === "completed" || v === "done" || v === "closed") return true;
  }
  // Same calendar rule as the app: closed from the day after departure
  // (Asia/Tbilisi, UTC+4).
  const dep = String(
    obj["departure_date"] ?? (trip ? trip["departure_date"] : "") ?? "",
  );
  const m = /(\d{4})-(\d{1,2})-(\d{1,2})/.exec(dep);
  if (m) {
    const now = new Date(Date.now() + 4 * 3600 * 1000);
    const today = Date.UTC(
      now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(),
    );
    const endDay = Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3])) +
      86400000;
    if (today >= endDay) return true;
  }
  return false;
}

/** Writes Odoo's closure verdict (service role only). */
async function setClosed(
  supabaseUrl: string,
  serviceKey: string,
  bookingId: number,
  closed: boolean,
): Promise<void> {
  try {
    await fetch(
      `${supabaseUrl.replace(/\/+$/, "")}/rest/v1/rpc/chat_sec_set_conversation_closed`,
      {
        method: "POST",
        headers: {
          apikey: serviceKey,
          Authorization: `Bearer ${serviceKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          p_odoo_booking_id: bookingId,
          p_closed: closed,
        }),
      },
    );
  } catch (_) {
    // Best effort: the app also enforces closure and the DB keeps the last
    // verdict it was given.
  }
}

/** Asks Odoo (authoritative) whether the caller may open this booking. */
async function fetchOdooBooking(
  baseUrl: string,
  token: string,
  bookingId: number,
): Promise<OdooResult> {
  const base = baseUrl.replace(/\/+$/, "");
  const url = `${base}/api/v1/chat/bookings/${bookingId}`;
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), ODOO_TIMEOUT_MS);
  let res: Response;
  try {
    res = await fetch(url, {
      method: "GET",
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: "application/json",
      },
      signal: ctrl.signal,
    });
  } catch (_) {
    return { ok: false, status: 502, error: "Odoo unreachable" };
  } finally {
    clearTimeout(timer);
  }

  if (res.status === 401) return { ok: false, status: 401, error: "Unauthorized" };
  if (res.status === 403) return { ok: false, status: 403, error: "Forbidden" };
  if (res.status === 404) return { ok: false, status: 404, error: "Booking not found" };
  if (!res.ok) return { ok: false, status: 502, error: "Odoo request failed" };

  let data: unknown;
  try {
    data = await res.json();
  } catch (_) {
    return { ok: false, status: 502, error: "Invalid Odoo response" };
  }
  const obj = asObject(data);
  if (!obj) return { ok: false, status: 502, error: "Invalid Odoo response" };

  // Odoo must explicitly grant access.
  if (obj["allowed"] !== true) {
    return { ok: false, status: 403, error: "Forbidden" };
  }

  // The booking returned must be the booking we asked for.
  const returnedId = toPositiveInt(obj["booking_id"] ?? obj["id"]);
  if (returnedId === null || returnedId !== bookingId) {
    return { ok: false, status: 502, error: "Invalid Odoo response" };
  }

  const reference = String(
    obj["booking_reference"] ?? obj["reference"] ?? "",
  ).trim();
  if (!reference) return { ok: false, status: 502, error: "Invalid Odoo response" };

  const driver = asObject(obj["current_driver"]);
  const driverId = driver ? toPositiveInt(driver["id"]) : null;
  if (driverId === null) {
    // No authoritative current driver: never guess one.
    return { ok: false, status: 409, error: "No current driver assigned" };
  }

  return {
    ok: true,
    booking: { bookingId: returnedId, reference, driverId, closed: isClosedByOdoo(obj) },
  };
}

/** Calls chat_sec_ensure_conversation with the service role (server only). */
async function ensureConversation(
  supabaseUrl: string,
  serviceKey: string,
  booking: OdooBooking,
  observedAt: string,
): Promise<{ ok: true; conversationId: string } | { ok: false }> {
  try {
    const res = await fetch(
      `${supabaseUrl.replace(/\/+$/, "")}/rest/v1/rpc/chat_sec_ensure_conversation`,
      {
        method: "POST",
        headers: {
          apikey: serviceKey,
          Authorization: `Bearer ${serviceKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          p_odoo_booking_id: booking.bookingId,
          p_booking_reference: booking.reference,
          p_current_driver_id: booking.driverId,
          p_observed_at: observedAt,
        }),
      },
    );
    if (!res.ok) return { ok: false };
    const value = await res.json();
    const id = typeof value === "string" ? value : null;
    if (
      !id ||
      !/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/
        .test(id)
    ) {
      return { ok: false };
    }
    return { ok: true, conversationId: id };
  } catch (_) {
    return { ok: false };
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") return fail(405, "Method not allowed");

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const odooBase = Deno.env.get("ODOO_API_BASE_URL") ?? "";
  if (!supabaseUrl || !serviceKey || !odooBase) {
    return fail(503, "Service not configured");
  }

  const token = odooToken(req);
  if (!token) return fail(401, "Unauthorized");

  let payload: unknown;
  try {
    payload = await req.json();
  } catch (_) {
    return fail(400, "Invalid request");
  }
  const body = asObject(payload);
  // Only booking_id is read. Any driver id in the body is ignored.
  const bookingId = body ? toPositiveInt(body["booking_id"]) : null;
  if (bookingId === null) return fail(400, "booking_id required");

  // Timestamp the authoritative read BEFORE the Odoo call so a concurrent
  // newer event written meanwhile is never overwritten (stale protection).
  const observedAt = new Date().toISOString();

  const odoo = await fetchOdooBooking(odooBase, token, bookingId);
  if (!odoo.ok) return fail(odoo.status, odoo.error);

  const ensured = await ensureConversation(
    supabaseUrl,
    serviceKey,
    odoo.booking,
    observedAt,
  );
  if (!ensured.ok) return fail(502, "Conversation sync failed");

  await setClosed(supabaseUrl, serviceKey, odoo.booking.bookingId, odoo.booking.closed);

  return json(200, {
    ok: true,
    conversation_id: ensured.conversationId,
    booking_id: odoo.booking.bookingId,
    closed: odoo.booking.closed,
  });
});

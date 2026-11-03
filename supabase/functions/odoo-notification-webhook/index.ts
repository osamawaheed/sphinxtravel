// ======================================================
// TourOps: Edge Function  odoo-notification-webhook   (PHASE 1)
//
// SELF-CONTAINED single file (no relative imports) so that deploy tools that
// bundle only index.ts (e.g. dashboard / MCP deploy) work.
//
// Receives ONE HMAC-signed Odoo notification event per HTTP POST.
// Server-to-server: no Supabase user JWT is required, so this function
// must be deployed with verify_jwt = false. Authenticity is enforced by the
// HMAC signature below.
//
// Flow
//   1. POST only. Read RAW body bytes (before any JSON parsing).
//   2. Verify HMAC-SHA256 over  timestamp + "." + raw_body  (constant time),
//      timestamp within +/-300s.            -> 401 on failure
//   3. Parse JSON, validate envelope/schema.  -> 400 on failure
//   4. X-Sphinx-Event-Id must equal body.event_id. -> 400
//   5. Row-locked claim (odoo_notif_claim_event), keyed on event_id:
//        new                -> store + claim, fan out
//        failed / received  -> claim again, fan out again (safe retry)
//        pending_recipient  -> claim again, re-evaluate recipients using the
//                              latest signed payload
//        processed          -> 200 {"status":"duplicate"}
//        lease held by a concurrent request -> 503 (Odoo retries)
//        db error           -> 503 (Odoo retries)
//   6. Fan-out + status update in ONE database transaction
//      (odoo_notif_fanout). Notification dedupe via unique constraints.
//        success            -> 200 {"status":"accepted"}
//        recipients missing -> 200 {"status":"accepted_pending_recipient"}
//                              (event preserved; re-send re-evaluates it)
//        fan-out failure    -> event marked 'failed', 503 (Odoo retries)
//   7. 2xx is returned only for events that are processed, or durably
//      preserved as pending_recipient.
//
// Secrets (Supabase Edge Function secrets, never in Flutter / env.json):
//   ODOO_WEBHOOK_HMAC_SECRET     shared HMAC secret (set by the owner)
//   SUPABASE_URL                 provided by the platform
//   SUPABASE_SERVICE_ROLE_KEY    provided by the platform
// ======================================================

// ------------------------------------------------------
// HMAC verification
// Signed message = timestamp (ASCII) + "." + RAW request body bytes.
// ------------------------------------------------------

const TIMESTAMP_TOLERANCE_SECONDS = 300;

const encoder = new TextEncoder();

function hexToBytes(hex: string): Uint8Array | null {
  if (hex.length === 0 || hex.length % 2 !== 0) return null;
  if (!/^[0-9a-fA-F]+$/.test(hex)) return null;
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(hex.substr(i * 2, 2), 16);
  }
  return out;
}

/** Constant-time comparison of two byte arrays. */
function timingSafeEqual(a: Uint8Array, b: Uint8Array): boolean {
  const len = Math.max(a.length, b.length);
  let diff = a.length ^ b.length;
  for (let i = 0; i < len; i++) {
    diff |= (a[i] ?? 0) ^ (b[i] ?? 0);
  }
  return diff === 0;
}

type SignatureResult =
  | { ok: true }
  | { ok: false; reason: "missing_signature" | "missing_timestamp" |
      "bad_timestamp" | "timestamp_out_of_range" | "bad_signature_format" |
      "signature_mismatch" | "secret_not_configured" };

async function verifySignature(
  secret: string,
  signatureHeader: string | null,
  timestampHeader: string | null,
  rawBody: Uint8Array,
  nowSeconds: number = Math.floor(Date.now() / 1000),
): Promise<SignatureResult> {
  if (!secret) return { ok: false, reason: "secret_not_configured" };
  if (!signatureHeader) return { ok: false, reason: "missing_signature" };
  if (!timestampHeader) return { ok: false, reason: "missing_timestamp" };

  const tsStr = timestampHeader.trim();
  if (!/^[0-9]{1,12}$/.test(tsStr)) {
    return { ok: false, reason: "bad_timestamp" };
  }
  const ts = Number(tsStr);
  if (Math.abs(nowSeconds - ts) > TIMESTAMP_TOLERANCE_SECONDS) {
    return { ok: false, reason: "timestamp_out_of_range" };
  }

  const sig = signatureHeader.trim();
  const prefix = "sha256=";
  if (!sig.toLowerCase().startsWith(prefix)) {
    return { ok: false, reason: "bad_signature_format" };
  }
  const provided = hexToBytes(sig.slice(prefix.length));
  if (!provided || provided.length !== 32) {
    return { ok: false, reason: "bad_signature_format" };
  }

  // message = ascii(timestamp) + "." + raw body bytes
  const head = encoder.encode(`${tsStr}.`);
  const message = new Uint8Array(head.length + rawBody.length);
  message.set(head, 0);
  message.set(rawBody, head.length);

  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const expected = new Uint8Array(await crypto.subtle.sign("HMAC", key, message));

  return timingSafeEqual(expected, provided)
    ? { ok: true }
    : { ok: false, reason: "signature_mismatch" };
}

// ------------------------------------------------------
// Payload validation (schema_version 1.x). Unknown fields are ignored.
// ------------------------------------------------------

const SUPPORTED_EVENT_TYPES: ReadonlySet<string> = new Set([
  // Booking
  "BOOKING_CONFIRMED", "BOOKING_CANCELLED", "BOOKING_UPDATED",
  "FLIGHT_DETAILS_UPDATED", "HOTEL_CHANGED",
  // Trip and driver assignment
  "TRIP_SCHEDULE_UPDATED", "DRIVER_ASSIGNED", "DRIVER_CHANGED",
  "TRIP_ASSIGNED", "TRIP_UNASSIGNED", "PICKUP_TIME_CHANGED",
  "PICKUP_LOCATION_CHANGED", "SUPPORT_INSTRUCTIONS_UPDATED",
  // Trip status
  "TRIP_STATUS_CHANGED", "DRIVER_STATUS_ON_THE_WAY", "DRIVER_STATUS_ARRIVED",
  "CUSTOMER_MET", "TRIP_STARTED", "TRIP_COMPLETED",
  // Customer reminders
  "PICKUP_60M_REMINDER", "PICKUP_30M_REMINDER", "PICKUP_15M_REMINDER",
  "PICKUP_10M_REMINDER", "TRIP_TOMORROW_REMINDER", "TRIP_7_DAYS_AWAY",
  "TRIP_48H_REMINDER", "TRIP_24H_REMINDER", "DEPARTURE_TRANSFER_24H",
  "DEPARTURE_TRANSFER_60M", "RATING_REQUEST_ELIGIBLE",
  // Driver reminders
  "DRIVER_TRIP_24H_REMINDER", "DRIVER_TRIP_2H_REMINDER",
  "DRIVER_TRIP_60M_REMINDER", "DRIVER_TRIP_30M_REMINDER",
  "DRIVER_TRIP_15M_REMINDER", "DRIVER_DEPARTURE_REMINDER",
  // Driver account
  "DRIVER_ACCOUNT_ACTIVATED", "DRIVER_ACCOUNT_SUSPENDED",
  // Driver wallet
  "WALLET_EARNINGS_ADDED", "WALLET_WITHDRAWAL_REQUESTED",
  "WALLET_WITHDRAWAL_APPROVED", "WALLET_WITHDRAWAL_REJECTED",
  "WALLET_PAYMENT_RECORDED", "WALLET_PAYMENT_COMPLETED",
  "WALLET_PAYMENT_FAILED",
]);

/** Phase 1 accepts only these environments. */
const ACCEPTED_ENVIRONMENTS: ReadonlySet<string> = new Set(["test"]);

const SUPPORTED_ROLES: ReadonlySet<string> = new Set(["customer", "driver"]);

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const ISO_UTC_RE =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?(Z|\+00:00)$/;

type OdooEvent = {
  schemaVersion: string;
  eventId: string;
  eventType: string;
  occurredAt: string; // normalized ISO
  source: string;
  environment: string;
  bookingId: number | null;
  bookingReference: string | null;
  tripId: number | null;
  customerOdooId: number | null;
  driverOdooId: number | null;
  recipientRoles: string[];
  data: Record<string, unknown>;
};

type ValidationResult =
  | { ok: true; event: OdooEvent }
  | { ok: false; error: string };

function isObject(v: unknown): v is Record<string, unknown> {
  return v !== null && typeof v === "object" && !Array.isArray(v);
}

/** Positive safe integer, or null. Accepts integer numbers only. */
function toIdOrNull(v: unknown): number | null | "invalid" {
  if (v === null || v === undefined) return null;
  if (typeof v === "number" && Number.isSafeInteger(v) && v > 0) return v;
  return "invalid";
}

function validateEvent(body: unknown): ValidationResult {
  if (!isObject(body)) return { ok: false, error: "body must be a JSON object" };

  const schemaVersion = body["schema_version"];
  if (typeof schemaVersion !== "string" || !/^1(\.\d+)*$/.test(schemaVersion)) {
    return { ok: false, error: "unsupported schema_version" };
  }

  const eventId = body["event_id"];
  if (typeof eventId !== "string" || !UUID_RE.test(eventId)) {
    return { ok: false, error: "event_id must be a UUID" };
  }

  const eventType = body["event_type"];
  if (typeof eventType !== "string" || !SUPPORTED_EVENT_TYPES.has(eventType)) {
    return { ok: false, error: "unsupported event_type" };
  }

  const occurredAtRaw = body["occurred_at"];
  if (typeof occurredAtRaw !== "string" || !ISO_UTC_RE.test(occurredAtRaw)) {
    return { ok: false, error: "occurred_at must be a UTC ISO-8601 timestamp" };
  }
  const occurredMs = Date.parse(occurredAtRaw);
  if (Number.isNaN(occurredMs)) {
    return { ok: false, error: "occurred_at is not a valid timestamp" };
  }

  if (body["source"] !== "odoo") {
    return { ok: false, error: "source must be 'odoo'" };
  }

  const environment = body["environment"];
  if (typeof environment !== "string" || !ACCEPTED_ENVIRONMENTS.has(environment)) {
    return { ok: false, error: "environment not accepted" };
  }

  const bookingId = toIdOrNull(body["booking_id"]);
  const tripId = toIdOrNull(body["trip_id"]);
  const customerOdooId = toIdOrNull(body["customer_odoo_id"]);
  const driverOdooId = toIdOrNull(body["driver_odoo_id"]);
  if (
    bookingId === "invalid" || tripId === "invalid" ||
    customerOdooId === "invalid" || driverOdooId === "invalid"
  ) {
    return { ok: false, error: "id fields must be positive integers or null" };
  }

  const refRaw = body["booking_reference"];
  if (refRaw !== null && refRaw !== undefined &&
      (typeof refRaw !== "string" || refRaw.length > 100)) {
    return { ok: false, error: "booking_reference must be a string or null" };
  }

  const rolesRaw = body["recipient_roles"];
  if (!Array.isArray(rolesRaw) || rolesRaw.length === 0 || rolesRaw.length > 4) {
    return { ok: false, error: "recipient_roles must be a non-empty array" };
  }
  const roles: string[] = [];
  for (const r of rolesRaw) {
    if (typeof r !== "string" || !SUPPORTED_ROLES.has(r)) {
      return { ok: false, error: "unsupported recipient role" };
    }
    if (!roles.includes(r)) roles.push(r);
  }

  const data = body["data"];
  if (!isObject(data)) return { ok: false, error: "data must be an object" };

  return {
    ok: true,
    event: {
      schemaVersion,
      eventId: eventId.toLowerCase(),
      eventType,
      occurredAt: new Date(occurredMs).toISOString(),
      source: "odoo",
      environment,
      bookingId: bookingId as number | null,
      bookingReference: typeof refRaw === "string" ? refRaw : null,
      tripId: tripId as number | null,
      customerOdooId: customerOdooId as number | null,
      driverOdooId: driverOdooId as number | null,
      recipientRoles: roles,
      data,
    },
  };
}

// ------------------------------------------------------
// Recipient resolution (trusted, server-side only)
//
// A verified recipient is the pair (role, odooId). IDs come ONLY from the
// HMAC-authenticated Odoo payload, never from a mobile client. If a role has
// no resolvable ID it is reported as unresolved (event kept pending).
// ------------------------------------------------------

type Recipient = { role: "customer" | "driver"; odooId: number };

type Resolution = {
  recipients: Recipient[];
  unresolvedRoles: string[];
};

function positiveInt(v: unknown): number | null {
  return typeof v === "number" && Number.isSafeInteger(v) && v > 0 ? v : null;
}

function idList(v: unknown): number[] {
  if (!Array.isArray(v)) return [];
  const out: number[] = [];
  for (const x of v) {
    const n = positiveInt(x);
    if (n !== null && !out.includes(n)) out.push(n);
  }
  return out;
}

function resolveRecipients(ev: OdooEvent): Resolution {
  const recipients: Recipient[] = [];
  const unresolvedRoles: string[] = [];
  const seen = new Set<string>();
  const add = (role: "customer" | "driver", id: number) => {
    const k = `${role}:${id}`;
    if (!seen.has(k)) {
      seen.add(k);
      recipients.push({ role, odooId: id });
    }
  };

  for (const role of ev.recipientRoles) {
    if (role === "customer") {
      if (ev.customerOdooId !== null) add("customer", ev.customerOdooId);
      else unresolvedRoles.push("customer");
      continue;
    }

    // role === "driver"
    const drivers: number[] = [];

    if (ev.eventType === "TRIP_UNASSIGNED" || ev.eventType === "DRIVER_CHANGED") {
      const prev = positiveInt(ev.data["previous_driver_odoo_id"]);
      if (ev.eventType === "TRIP_UNASSIGNED") {
        // The old driver is the recipient.
        if (prev !== null) drivers.push(prev);
        else if (ev.driverOdooId !== null) drivers.push(ev.driverOdooId);
      } else {
        // DRIVER_CHANGED with role=driver: the NEW driver (driver_odoo_id).
        // The previous driver is notified via a separate TRIP_UNASSIGNED.
        if (ev.driverOdooId !== null) drivers.push(ev.driverOdooId);
      }
    } else {
      if (ev.driverOdooId !== null) drivers.push(ev.driverOdooId);
      for (const d of idList(ev.data["driver_odoo_ids"])) {
        if (!drivers.includes(d)) drivers.push(d);
      }
    }

    if (drivers.length === 0) unresolvedRoles.push("driver");
    else for (const d of drivers) add("driver", d);
  }

  return { recipients, unresolvedRoles };
}

/**
 * Same-transition dedupe key: TRIP_STATUS_CHANGED and a specific status event
 * for one transition both map to ONE user-facing notification. Returns null
 * when it cannot be built safely (prefer a possible duplicate over dropping).
 */
const STATUS_EVENT_TO_STATUS: Record<string, string> = {
  DRIVER_STATUS_ON_THE_WAY: "on_the_way",
  DRIVER_STATUS_ARRIVED: "arrived",
  CUSTOMER_MET: "customer_met",
  TRIP_STARTED: "started",
  TRIP_COMPLETED: "completed",
};

function normStatus(v: unknown): string | null {
  if (typeof v !== "string") return null;
  const s = v.trim().toLowerCase().replace(/[\s-]+/g, "_");
  return s.length > 0 && s.length <= 64 ? s : null;
}

const STATUS_ALIASES: Record<string, string> = {
  driver_on_the_way: "on_the_way",
  on_way: "on_the_way",
  driver_arrived: "arrived",
  customer_picked_up: "customer_met",
  in_progress: "started",
  done: "completed",
};

function buildDedupeKey(ev: OdooEvent): string | null {
  if (ev.tripId === null) return null;

  let status: string | null = STATUS_EVENT_TO_STATUS[ev.eventType] ?? null;

  if (ev.eventType === "TRIP_STATUS_CHANGED") {
    const raw = normStatus(ev.data["new_status"] ?? ev.data["status"] ??
      ev.data["trip_status"]);
    if (raw) status = STATUS_ALIASES[raw] ?? raw;
  }
  if (!status) return null;
  return `trip-status:${ev.tripId}:${status}`;
}

// ------------------------------------------------------
// Handler
// ------------------------------------------------------

const MAX_BODY_BYTES = 256 * 1024; // 256 KB per event

function json(
  status: number,
  body: Record<string, unknown>,
  extra: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...extra },
  });
}

/** Logs only non-sensitive metadata. Never secrets or payload data. */
function log(msg: string, meta: Record<string, unknown> = {}): void {
  console.log(JSON.stringify({ fn: "odoo-notification-webhook", msg, ...meta }));
}

function restHeaders(serviceKey: string, extra: Record<string, string> = {}) {
  return {
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`,
    "Content-Type": "application/json",
    ...extra,
  };
}

/** Reads the body with a hard size cap. Returns null when too large. */
async function readRawBody(req: Request): Promise<Uint8Array | null> {
  const declared = Number(req.headers.get("content-length") ?? "0");
  if (declared > MAX_BODY_BYTES) return null;
  const buf = new Uint8Array(await req.arrayBuffer());
  return buf.length > MAX_BODY_BYTES ? null : buf;
}

type ClaimAction =
  | "inserted"     // new event stored + claimed
  | "retry"        // previously failed/received event claimed again
  | "recheck"      // pending_recipient event claimed again
  | "duplicate"    // already processed
  | "in_progress"; // another request holds a fresh lease

/**
 * Atomic, row-locked ingest + claim (see migration
 * 20260201000100_odoo_notifications_retry_safety.sql). Throws on any
 * database/transport error so the caller can answer 503 (Odoo retries).
 */
async function claimEvent(
  base: string,
  key: string,
  ev: OdooEvent,
): Promise<ClaimAction> {
  const res = await fetch(`${base}/rest/v1/rpc/odoo_notif_claim_event`, {
    method: "POST",
    headers: restHeaders(key),
    body: JSON.stringify({
      p_event_id: ev.eventId,
      p_schema_version: ev.schemaVersion,
      p_event_type: ev.eventType,
      p_occurred_at: ev.occurredAt,
      p_source: ev.source,
      p_environment: ev.environment,
      p_booking_id: ev.bookingId,
      p_booking_reference: ev.bookingReference,
      p_trip_id: ev.tripId,
      p_customer_odoo_id: ev.customerOdooId,
      p_driver_odoo_id: ev.driverOdooId,
      p_recipient_roles: ev.recipientRoles,
      p_data: ev.data,
      p_lease_seconds: 60,
    }),
  });
  if (!res.ok) throw new Error(`claim failed status=${res.status}`);
  const out = await res.json();
  const action = isObject(out) ? out["action"] : null;
  if (
    action === "inserted" || action === "retry" || action === "recheck" ||
    action === "duplicate" || action === "in_progress"
  ) {
    return action;
  }
  throw new Error("claim returned unexpected result");
}

/**
 * Atomic fan-out: notifications + event status update in ONE database
 * transaction. Idempotent (unique constraints, ON CONFLICT DO NOTHING).
 * Returns the resulting processing_status.
 */
async function fanoutEvent(
  base: string,
  key: string,
  ev: OdooEvent,
  recipients: Recipient[],
  unresolvedRoles: string[],
  dedupeKey: string | null,
): Promise<string> {
  const res = await fetch(`${base}/rest/v1/rpc/odoo_notif_fanout`, {
    method: "POST",
    headers: restHeaders(key),
    body: JSON.stringify({
      p_event_id: ev.eventId,
      p_rows: recipients.map((r) => ({
        recipient_role: r.role,
        recipient_odoo_id: r.odooId,
        dedupe_key: dedupeKey,
      })),
      p_unresolved: unresolvedRoles,
    }),
  });
  if (!res.ok) throw new Error(`fanout failed status=${res.status}`);
  const out = await res.json();
  return typeof out === "string" ? out : "processed";
}

/** Records the failure and releases the lease. Best effort. */
async function markFailed(
  base: string,
  key: string,
  eventId: string,
  message: string,
): Promise<void> {
  const res = await fetch(`${base}/rest/v1/rpc/odoo_notif_mark_failed`, {
    method: "POST",
    headers: restHeaders(key),
    body: JSON.stringify({ p_event_id: eventId, p_error: message }),
  });
  if (!res.ok) throw new Error(`mark failed status=${res.status}`);
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return json(405, { status: "error", error: "method not allowed" }, {
      Allow: "POST",
    });
  }

  const secret = Deno.env.get("ODOO_WEBHOOK_HMAC_SECRET") ?? "";
  const supabaseUrl = (Deno.env.get("SUPABASE_URL") ?? "").replace(/\/+$/, "");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!secret || !supabaseUrl || !serviceKey) {
    // Misconfiguration: temporary from Odoo's point of view -> retry.
    log("server_not_configured");
    return json(503, { status: "error", error: "service unavailable" });
  }

  // 1) RAW body first. Never parse before verifying.
  let raw: Uint8Array | null;
  try {
    raw = await readRawBody(req);
  } catch (_) {
    return json(400, { status: "error", error: "unreadable body" });
  }
  if (raw === null) return json(400, { status: "error", error: "body too large" });

  // 2) HMAC + timestamp window.
  const sig = await verifySignature(
    secret,
    req.headers.get("x-sphinx-signature"),
    req.headers.get("x-sphinx-timestamp"),
    raw,
  );
  if (!sig.ok) {
    log("signature_rejected", { reason: sig.reason });
    // Same generic body for every auth failure (no oracle).
    return json(401, { status: "error", error: "unauthorized" });
  }

  // 3) Parse + validate (only after authentication).
  let parsed: unknown;
  try {
    parsed = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(raw));
  } catch (_) {
    return json(400, { status: "error", error: "invalid JSON" });
  }
  const v = validateEvent(parsed);
  if (!v.ok) {
    log("payload_rejected", { error: v.error });
    return json(400, { status: "error", error: v.error });
  }
  const ev = v.event;

  // 4) Header event id must match body event id.
  const headerEventId = (req.headers.get("x-sphinx-event-id") ?? "")
    .trim().toLowerCase();
  if (headerEventId !== ev.eventId) {
    log("event_id_mismatch", { event_id: ev.eventId });
    return json(400, { status: "error", error: "event id mismatch" });
  }

  // 5) Durable, idempotent, row-locked claim. Any failure here means the
  //    event is not safely recorded -> 503 so Odoo retries.
  let action: ClaimAction;
  try {
    action = await claimEvent(supabaseUrl, serviceKey, ev);
  } catch (_) {
    log("claim_failed", { event_id: ev.eventId });
    return json(503, { status: "error", error: "temporary failure" }, {
      "Retry-After": "30",
    });
  }

  if (action === "duplicate") {
    // Only already-processed events are reported as duplicates.
    log("duplicate", { event_id: ev.eventId });
    return json(200, { status: "duplicate" });
  }

  if (action === "in_progress") {
    // Another request is processing this event right now. Do NOT claim
    // success: ask Odoo to retry shortly (the retry will see the result).
    log("in_progress", { event_id: ev.eventId });
    return json(503, { status: "error", error: "event is being processed" }, {
      "Retry-After": "15",
    });
  }

  // action: inserted | retry | recheck  -> we hold the lease; fan out.
  const { recipients, unresolvedRoles } = resolveRecipients(ev);
  const dedupeKey = buildDedupeKey(ev);

  try {
    const finalStatus = await fanoutEvent(
      supabaseUrl,
      serviceKey,
      ev,
      recipients,
      unresolvedRoles,
      dedupeKey,
    );

    if (finalStatus === "pending_recipient") {
      // Durably stored and preserved. Re-sends of the same event_id are
      // re-evaluated (action "recheck"), so recovery is possible once
      // recipient information is available. See report: Odoo retries stop
      // after a 2xx, so a recovery job / manual re-send is required.
      log("pending_recipient", {
        event_id: ev.eventId,
        event_type: ev.eventType,
        action,
      });
      return json(200, { status: "accepted_pending_recipient" });
    }

    log("accepted", {
      event_id: ev.eventId,
      event_type: ev.eventType,
      action,
      recipients: recipients.length,
    });
    return json(200, { status: "accepted" });
  } catch (fanoutErr) {
    log("fanout_failed", { event_id: ev.eventId, action });
    try {
      await markFailed(
        supabaseUrl,
        serviceKey,
        ev.eventId,
        String((fanoutErr as Error)?.message ?? "fanout error"),
      );
    } catch (_) {
      // Lease expires on its own; the event stays retryable.
    }
    // NOT a success: the event is stored as 'failed' and Odoo must retry.
    return json(503, { status: "error", error: "temporary failure" }, {
      "Retry-After": "30",
    });
  }
});

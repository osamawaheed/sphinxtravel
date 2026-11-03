// ======================================================
// Odoo notification payload validation (schema_version 1.x)
// Unknown fields are ignored for forward compatibility.
// ======================================================

export const SUPPORTED_EVENT_TYPES: ReadonlySet<string> = new Set([
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
export const ACCEPTED_ENVIRONMENTS: ReadonlySet<string> = new Set(["test"]);

export const SUPPORTED_ROLES: ReadonlySet<string> = new Set([
  "customer", "driver",
]);

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const ISO_UTC_RE =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?(Z|\+00:00)$/;

export type OdooEvent = {
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

export type ValidationResult =
  | { ok: true; event: OdooEvent }
  | { ok: false; error: string };

function isObject(v: unknown): v is Record<string, unknown> {
  return v !== null && typeof v === "object" && !Array.isArray(v);
}

/** Positive safe integer, or null. Accepts integer numbers only. */
export function toIdOrNull(v: unknown): number | null | "invalid" {
  if (v === null || v === undefined) return null;
  if (typeof v === "number" && Number.isSafeInteger(v) && v > 0) return v;
  return "invalid";
}

export function validateEvent(body: unknown): ValidationResult {
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

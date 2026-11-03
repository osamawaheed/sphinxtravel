// ======================================================
// Recipient resolution (trusted, server-side only)
//
// Identity model: the app authenticates with an Odoo-issued JWT carrying
// odoo_user_id + odoo_role. So a verified recipient is the pair
// (role, odooId). These IDs come ONLY from the HMAC-authenticated Odoo
// payload (customer_odoo_id / driver_odoo_id / data.driver_odoo_ids /
// data.previous_driver_odoo_id), never from a mobile client.
//
// Nothing is invented: if a role listed in recipient_roles has no
// resolvable Odoo ID, that role is reported as `unresolved` and the event
// is kept as 'pending_recipient' (blocked) instead of being delivered.
// ======================================================

import type { OdooEvent } from "./validate.ts";

export type Recipient = { role: "customer" | "driver"; odooId: number };

export type Resolution = {
  recipients: Recipient[];
  /** Roles requested by Odoo for which no trusted ID was available. */
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

export function resolveRecipients(ev: OdooEvent): Resolution {
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
      // The previous driver must be told they were removed/replaced.
      const prev = positiveInt(ev.data["previous_driver_odoo_id"]);
      if (ev.eventType === "TRIP_UNASSIGNED") {
        // The old driver is the recipient. Prefer the explicit previous id,
        // fall back to driver_odoo_id (Odoo may put the removed driver there).
        if (prev !== null) drivers.push(prev);
        else if (ev.driverOdooId !== null) drivers.push(ev.driverOdooId);
      } else {
        // DRIVER_CHANGED with role=driver: the NEW driver (driver_odoo_id).
        // The previous driver is notified through a separate
        // TRIP_UNASSIGNED event; we do not guess here.
        if (ev.driverOdooId !== null) drivers.push(ev.driverOdooId);
      }
    } else {
      if (ev.driverOdooId !== null) drivers.push(ev.driverOdooId);
      // Booking-level events may list several drivers.
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
 * Same-transition dedupe key. Odoo may emit TRIP_STATUS_CHANGED AND a
 * specific status event for one transition. Both are stored in
 * odoo_notification_events (audit), but both map to ONE user-facing
 * notification via a shared dedupe_key (unique per recipient).
 *
 * Key = "trip-status:<trip_id>:<status>". Returns null when it cannot be
 * built safely, in which case no cross-event dedupe is applied (we prefer
 * a possible duplicate over silently dropping a notification).
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

export function buildDedupeKey(ev: OdooEvent): string | null {
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

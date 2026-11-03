// ======================================================
// Odoo notification webhook - TEST EVENT SENDER (dummy TEST data only)
//
// Usage (after the function is deployed, with owner approval):
//   ODOO_WEBHOOK_HMAC_SECRET=... \
//   WEBHOOK_URL=https://uwllcyhmsletdflnrpcm.supabase.co/functions/v1/odoo-notification-webhook \
//   deno run --allow-env --allow-net send_test_event.ts <case>
//
// The secret is read from the local shell environment ONLY. Never commit it.
//
// Cases: valid | duplicate | bad_sig | old_ts | id_mismatch | bad_env |
//        bad_type | no_driver | no_driver_resend | unassign | status_pair
// ======================================================

const url = Deno.env.get("WEBHOOK_URL") ?? "";
const secret = Deno.env.get("ODOO_WEBHOOK_HMAC_SECRET") ?? "";
if (!url || !secret) {
  console.error("Set WEBHOOK_URL and ODOO_WEBHOOK_HMAC_SECRET");
  Deno.exit(1);
}

const enc = new TextEncoder();

async function sign(ts: string, body: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"],
  );
  const mac = new Uint8Array(
    await crypto.subtle.sign("HMAC", key, enc.encode(`${ts}.${body}`)),
  );
  return "sha256=" + [...mac].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function baseEvent(over: Record<string, unknown> = {}) {
  return {
    schema_version: "1.0",
    event_id: crypto.randomUUID(),
    event_type: "PICKUP_30M_REMINDER",
    occurred_at: new Date().toISOString().replace(/\.\d+Z$/, "Z"),
    source: "odoo",
    environment: "test",
    booking_id: 999001,
    booking_reference: "TEST-S999001",
    trip_id: 999101,
    customer_odoo_id: 999201,
    driver_odoo_id: 999301,
    recipient_roles: ["customer"],
    data: {
      pickup_at: "2026-11-02T09:00:00Z",
      pickup_timezone: "Asia/Tbilisi",
      pickup_location: "Tbilisi International Airport",
      destination: "Hotel Example",
    },
    ...over,
  };
}

async function send(
  ev: Record<string, unknown>,
  opts: { tsOffset?: number; badSig?: boolean; headerEventId?: string } = {},
) {
  const body = JSON.stringify(ev);
  const ts = String(Math.floor(Date.now() / 1000) + (opts.tsOffset ?? 0));
  const sig = opts.badSig ? "sha256=" + "0".repeat(64) : await sign(ts, body);
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Sphinx-Signature": sig,
      "X-Sphinx-Timestamp": ts,
      "X-Sphinx-Event-Id": opts.headerEventId ?? String(ev.event_id),
    },
    body,
  });
  console.log(res.status, await res.text());
}

const c = Deno.args[0] ?? "valid";
switch (c) {
  case "valid": await send(baseEvent()); break;                       // 200 accepted
  case "duplicate": {                                                 // 200 accepted, then 200 duplicate
    const e = baseEvent();
    await send(e); await send(e); break;
  }
  case "bad_sig": await send(baseEvent(), { badSig: true }); break;   // 401
  case "old_ts": await send(baseEvent(), { tsOffset: -4000 }); break; // 401
  case "id_mismatch":                                                 // 400
    await send(baseEvent(), { headerEventId: crypto.randomUUID() }); break;
  case "bad_env": await send(baseEvent({ environment: "production" })); break; // 400
  case "bad_type": await send(baseEvent({ event_type: "NOPE" })); break;       // 400
  case "no_driver":                                                   // 200 accepted_pending_recipient
    await send(baseEvent({
      event_type: "TRIP_ASSIGNED", recipient_roles: ["driver"], driver_odoo_id: null,
    })); break;
  case "no_driver_resend": {                                          // 200 pending, then 200 accepted (recovered)
    const e = baseEvent({
      event_type: "TRIP_ASSIGNED", recipient_roles: ["driver"], driver_odoo_id: null,
    });
    await send(e);
    await send({ ...e, driver_odoo_id: 999301 });
    break;
  }
  case "unassign":                                                    // 200, old driver notified
    await send(baseEvent({
      event_type: "TRIP_UNASSIGNED", recipient_roles: ["driver"],
      driver_odoo_id: 999302, data: { previous_driver_odoo_id: 999301 },
    })); break;
  case "status_pair": {                                               // 2 events, 1 notification
    await send(baseEvent({
      event_type: "TRIP_STATUS_CHANGED", recipient_roles: ["customer"],
      data: { new_status: "arrived" },
    }));
    await send(baseEvent({
      event_type: "DRIVER_STATUS_ARRIVED", recipient_roles: ["customer"], data: {},
    }));
    break;
  }
  default: console.error("unknown case");
}

// ======================================================
// Odoo -> Supabase notification webhook: HMAC verification
//
// Signed message = timestamp (ASCII) + "." + RAW request body bytes.
// Algorithm      = HMAC-SHA256, header "X-Sphinx-Signature: sha256=<hex>".
// The body is NEVER parsed / re-serialized before verification.
// ======================================================

export const TIMESTAMP_TOLERANCE_SECONDS = 300;

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

/** Constant-time comparison of two equal-purpose byte arrays. */
function timingSafeEqual(a: Uint8Array, b: Uint8Array): boolean {
  // Always iterate over the longer length to avoid early exit on length.
  const len = Math.max(a.length, b.length);
  let diff = a.length ^ b.length;
  for (let i = 0; i < len; i++) {
    diff |= (a[i] ?? 0) ^ (b[i] ?? 0);
  }
  return diff === 0;
}

export type SignatureResult =
  | { ok: true }
  | { ok: false; reason: "missing_signature" | "missing_timestamp" |
      "bad_timestamp" | "timestamp_out_of_range" | "bad_signature_format" |
      "signature_mismatch" | "secret_not_configured" };

/**
 * Verifies the Odoo HMAC signature against the exact raw body bytes.
 * `nowSeconds` is injectable for tests.
 */
export async function verifySignature(
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

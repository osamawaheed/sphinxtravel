// ======================================================
// TourOps Smart Chat
// Edge Function: chat-transcribe-message  (PHASE 3.1 v2, TEST)
//
// Called by the Flutter app with:
//   { message_id, target_language, viewer_role, viewer_id, retry? }
//
// Secrets stay server-side:
//   * SUPABASE_SERVICE_ROLE_KEY (reads private chat-voice audio, writes DB)
//   * OPENAI_API_KEY            (speech-to-text)
//   * CHAT_INTERNAL_TOKEN       (authenticates to chat-translate)
//
// v2 changes
//   1. AUTHORIZATION (TEST architecture preserved: anon key + Odoo ids,
//      no Supabase JWT). The caller must present the project anon key and a
//      viewer identity. The function resolves the message AND its
//      conversation server-side and only serves:
//        - the original sender (their own voice message), or
//        - the opposite role in the same conversation (the recipient).
//      Anything else gets a generic 403/404 (no existence leak).
//      Negative TEST ids are only honoured on the explicit TEST booking.
//   2. LANGUAGE: script detection for ar/ka/ru; Latin transcripts are
//      resolved by evidence (az letters/words, EN words), then by a
//      language-ID fallback (the json STT format has no language field).
//      Unresolved => "language_uncertain": nothing is stored as English.
//   3. DB RELIABILITY: every write is checked. A failed save never returns
//      "ready". The paid transcript is kept in a recovery column so a retry
//      never calls OpenAI again.
//   4. RETRY: atomic claim (SQL RPC) + try/finally guarantees the row never
//      stays 'pending'; stale pending rows are taken over; bounded attempts.
// ======================================================

const LANGUAGES = ["ar", "en", "ru", "ka", "az"];
const MAX_SECONDS = 60;
const MODEL = "gpt-4o-mini-transcribe";
const BUCKET = "chat-voice";
const STALE_SECONDS = 120;
const MAX_ATTEMPTS = 3;
const OPENAI_TIMEOUT_MS = 45_000;
const TEST_BOOKING_REFERENCE = "RQ.TEST14596";
const UUID_RE = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;

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

// Projects that moved to the new API keys expose them as a JSON object
// ({"default":"sb_publishable_..."}) in SUPABASE_PUBLISHABLE_KEYS. The client
// may send either the legacy anon JWT or a publishable key, so both are valid
// "project keys". Only keys that belong to THIS project are accepted.
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

// Project ref derived from SUPABASE_URL (https://<ref>.supabase.co).
const PROJECT_REF = (() => {
  try {
    return new URL(SUPABASE_URL).hostname.split(".")[0] ?? "";
  } catch {
    return "";
  }
})();

// Reads (does NOT verify) the claims of a JWT. The Supabase API gateway has
// already validated the signature of any apikey it forwards, so the claims are
// only used to confirm the key is this project's low-privilege anon key.
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

const restHeaders = {
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  "Content-Type": "application/json",
};

const rest = (path: string) => `${SUPABASE_URL}/rest/v1/${path}`;
type Row = Record<string, unknown>;

// ---------------------------------------------------------------
// Audio container detection (from the leading bytes, never the file name).
// WebM/Matroska (1A 45 DF A3), MP4/M4A ("ftyp" at offset 4), WAV
// ("RIFF"...."WAVE"), Ogg ("OggS"), MP3 ("ID3" or frame sync FF Ex/Fx).
// Returns null when the bytes are not recognised so the caller can fall back
// to the stored extension.
// ---------------------------------------------------------------
function sniffAudio(b: Uint8Array): { ext: string; mime: string } | null {
  const at = (i: number, sig: number[]): boolean => {
    if (b.length < i + sig.length) return false;
    for (let k = 0; k < sig.length; k++) {
      if (b[i + k] !== sig[k]) return false;
    }
    return true;
  };
  if (at(0, [0x1a, 0x45, 0xdf, 0xa3])) return { ext: "webm", mime: "audio/webm" };
  if (at(4, [0x66, 0x74, 0x79, 0x70])) return { ext: "m4a", mime: "audio/mp4" };
  if (at(0, [0x52, 0x49, 0x46, 0x46]) && at(8, [0x57, 0x41, 0x56, 0x45])) {
    return { ext: "wav", mime: "audio/wav" };
  }
  if (at(0, [0x4f, 0x67, 0x67, 0x53])) return { ext: "ogg", mime: "audio/ogg" };
  if (at(0, [0x49, 0x44, 0x33])) return { ext: "mp3", mime: "audio/mpeg" };
  if (b.length >= 2 && b[0] === 0xff && (b[1] & 0xe0) === 0xe0) {
    return { ext: "mp3", mime: "audio/mpeg" };
  }
  return null;
}

// ---------------------------------------------------------------
// AI service switches (public.chat_ai_settings), read per request so an
// administrator change applies immediately without redeploying anything.
// Fails OPEN when the row cannot be read (chat must keep working).
// ---------------------------------------------------------------

type AiFlags = {
  voice_transcription_enabled: boolean;
  voice_text_translation_enabled: boolean;
};

async function loadAiFlags(): Promise<AiFlags> {
  const open: AiFlags = {
    voice_transcription_enabled: true,
    voice_text_translation_enabled: true,
  };
  try {
    const res = await fetch(
      rest(
        "chat_ai_settings?id=eq.1" +
          "&select=voice_transcription_enabled,voice_text_translation_enabled" +
          "&limit=1",
      ),
      { headers: restHeaders },
    );
    if (!res.ok) {
      console.error("ai settings read failed:", res.status);
      return open;
    }
    const rows = await res.json();
    if (!Array.isArray(rows) || rows.length === 0) return open;
    return {
      voice_transcription_enabled:
        rows[0].voice_transcription_enabled !== false,
      voice_text_translation_enabled:
        rows[0].voice_text_translation_enabled !== false,
    };
  } catch (_) {
    console.error("ai settings read error");
    return open;
  }
}

// Metadata-only usage record. Never contains transcript text, audio URLs or
// keys. A logging failure never affects the response.
async function logUsage(entry: {
  service: "voice_transcription" | "voice_text_translation";
  success: boolean;
  model?: string | null;
  audioSeconds?: number | null;
  errorCode?: string | null;
}): Promise<void> {
  try {
    const res = await fetch(rest("chat_ai_usage_log"), {
      method: "POST",
      headers: { ...restHeaders, Prefer: "return=minimal" },
      body: JSON.stringify({
        service_type: entry.service,
        success: entry.success,
        model: entry.model ?? null,
        audio_seconds: entry.audioSeconds ?? null,
        // No reliable per-request pricing is available: never invented.
        estimated_cost_usd: null,
        error_code: entry.errorCode ?? null,
      }),
    });
    if (!res.ok) console.error("usage log failed:", res.status);
  } catch (_) {
    console.error("usage log error");
  }
}

// ---------------------------------------------------------------
// Language detection
// ---------------------------------------------------------------

function detectScript(text: string): "ar" | "ka" | "ru" | "latin" | null {
  let ar = 0, ka = 0, ru = 0, la = 0;
  for (const ch of text) {
    const c = ch.codePointAt(0)!;
    if ((c >= 0x0600 && c <= 0x06ff) || (c >= 0x0750 && c <= 0x077f) ||
        (c >= 0xfb50 && c <= 0xfdff) || (c >= 0xfe70 && c <= 0xfeff)) ar++;
    else if ((c >= 0x10a0 && c <= 0x10ff) || (c >= 0x1c90 && c <= 0x1cbf)) ka++;
    else if (c >= 0x0400 && c <= 0x04ff) ru++;
    else if ((c >= 0x41 && c <= 0x5a) || (c >= 0x61 && c <= 0x7a) ||
             (c >= 0xc0 && c <= 0x24f)) la++;
  }
  const max = Math.max(ar, ka, ru, la);
  if (max === 0) return null;
  if (max === ar) return "ar";
  if (max === ka) return "ka";
  if (max === ru) return "ru";
  return "latin";
}

// Maps OpenAI language names / ISO codes to our codes. Unknown => null.
function normalizeLang(raw: unknown): string | null {
  const v = String(raw ?? "").trim().toLowerCase();
  const map: Record<string, string> = {
    ar: "ar", arabic: "ar",
    en: "en", english: "en",
    ru: "ru", russian: "ru",
    ka: "ka", georgian: "ka",
    az: "az", azerbaijani: "az", azeri: "az",
  };
  return map[v] ?? null;
}

const EN_WORDS = new Set([
  "the", "and", "is", "are", "was", "were", "you", "your", "we", "my",
  "to", "of", "in", "on", "at", "for", "with", "please", "hello", "thanks",
  "thank", "will", "be", "am", "it", "this", "that", "here", "there",
  "where", "when", "what", "how", "okay", "yes", "not", "have", "has",
  "can", "arrived", "waiting", "outside", "minutes", "pickup", "driver",
  "hotel", "airport", "ready", "location", "way", "i'm", "i", "me",
]);
const AZ_WORDS = new Set([
  "salam", "sağ", "olun", "təşəkkür", "təşəkkürlər", "var", "yox", "bəli",
  "xahiş", "edirəm", "mən", "sən", "biz", "siz", "necə", "harada", "nə",
  "zaman", "gəlirəm", "gəldim", "gözləyirəm", "otel", "hava", "limanı",
  "dəqiqə", "dəqiqəyə", "yoldayam", "çatdım", "hazıram", "salamlar",
  "sabah", "bu", "və", "ilə", "üçün", "də", "bir", "çox", "yaxşı",
  "buyurun", "zəhmət", "olmasa", "ünvan", "sürücü", "müştəri",
]);
const AZ_ONLY_LETTERS = /[əƏ]/;
const AZ_LETTERS = /[əƏğĞıİöÖüÜçÇşŞ]/;

type LatinGuess = "en" | "az" | "unknown";

// Evidence-based. Returns "unknown" instead of guessing English.
function guessLatin(text: string): LatinGuess {
  const words = text.toLowerCase().match(/[\p{L}']+/gu) ?? [];
  if (words.length === 0) return "unknown";
  if (AZ_ONLY_LETTERS.test(text)) return "az";
  let az = 0, en = 0;
  for (const w of words) {
    if (AZ_WORDS.has(w)) az++;
    if (EN_WORDS.has(w)) en++;
  }
  const hasAz = AZ_LETTERS.test(text);
  if (az >= 1 && az > en) return "az";
  if (hasAz && az >= en && az > 0) return "az";
  // English needs real evidence AND no Azerbaijani-only letters.
  if (en >= 2 && en > az && !hasAz) return "en";
  return "unknown";
}

type Resolved = {
  language: string | null;
  uncertain: boolean;
  // True when the transcript is Latin-script, script/word evidence is not
  // conclusive and no usable language metadata exists: the caller must run
  // the language-ID fallback (identifyLatinLanguage).
  needsLangId: boolean;
};

// Priority: non-Latin script > Latin evidence > OpenAI reported language
// (only if it is one of our five AND consistent with the script).
// Never falls back to the sender's app language and never defaults to
// English on missing evidence.
function resolveLanguage(transcript: string, openaiLang: unknown): Resolved {
  const script = detectScript(transcript);
  if (script === "ar" || script === "ka" || script === "ru") {
    return { language: script, uncertain: false, needsLangId: false };
  }
  const reported = normalizeLang(openaiLang);
  if (script === "latin") {
    const g = guessLatin(transcript);
    if (g !== "unknown") {
      return { language: g, uncertain: false, needsLangId: false };
    }
    // Ambiguous Latin: trust the transcription model's own language metadata
    // when it names a Latin-script language we support.
    if (reported === "en" || reported === "az") {
      return { language: reported, uncertain: false, needsLangId: false };
    }
    // No usable metadata (json format never returns it). Latin script alone
    // cannot separate English / Azerbaijani, and a spoken Russian or Arabic
    // phrase may be transliterated: use the language-ID fallback.
    return { language: null, uncertain: true, needsLangId: true };
  }
  // Digits/symbols only: no evidence at all.
  return { language: null, uncertain: true, needsLangId: false };
}

// Language identification fallback for ambiguous Latin-script transcripts.
// Uses a deterministic (temperature 0) classification restricted to our five
// languages. Returns one of LANGUAGES, or null when it is not confident or
// the call fails (the caller then stores the language as uncertain; nothing
// is ever silently labelled English).
async function identifyLatinLanguage(
  text: string,
  apiKey: string | undefined,
): Promise<string | null> {
  if (!apiKey) return null;
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), 15_000);
  try {
    const res = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        temperature: 0,
        max_tokens: 5,
        messages: [
          {
            role: "system",
            content:
              "You are a language identifier. The user text is a speech " +
              "transcript. Identify the language that was SPOKEN, even if " +
              "written in Latin letters. Answer with exactly one code: " +
              "en (English), az (Azerbaijani), ru (Russian), ar (Arabic), " +
              "ka (Georgian), or unknown if you are not confident. " +
              "Output only the code.",
          },
          { role: "user", content: text.slice(0, 500) },
        ],
      }),
      signal: ctl.signal,
    });
    if (!res.ok) {
      console.error("language-id failed:", res.status);
      return null;
    }
    const data = await res.json();
    const raw = String(data?.choices?.[0]?.message?.content ?? "")
      .trim()
      .toLowerCase()
      .replace(/[^a-z]/g, "");
    return LANGUAGES.includes(raw) ? raw : null;
  } catch (_) {
    console.error("language-id error");
    return null;
  } finally {
    clearTimeout(timer);
  }
}

// ---------------------------------------------------------------
// Authorization
// ---------------------------------------------------------------

function bearer(req: Request): string {
  const h = req.headers.get("authorization") ?? "";
  return h.toLowerCase().startsWith("bearer ") ? h.slice(7).trim() : "";
}

// TEST architecture: the app only holds the anon key. Require it so the
// endpoint is not an open, unauthenticated relay.
function hasProjectKey(req: Request): boolean {
  if (PROJECT_KEYS.length === 0 && !PROJECT_REF) return false;
  const k = req.headers.get("apikey") ?? "";
  const b = bearer(req);
  // 1. Exact match with a configured project key (legacy anon or publishable).
  const exact = PROJECT_KEYS.some((p) => p === k || p === b);
  // 2. The apikey is this project's anon JWT (ref + role=anon). A signed-in
  //    user's session JWT in Authorization (role=authenticated) is NOT used
  //    for this check, and service_role is never accepted.
  const claimOk = k.length > 0 && isThisProjectAnon(k);
  const ok = exact || claimOk;
  if (!ok) {
    const c = jwtClaims(k);
    // Non-secret diagnostics only (lengths / prefixes / claim values).
    console.error(
      "project key mismatch:",
      JSON.stringify({
        apikey_len: k.length,
        apikey_prefix: k.slice(0, 7),
        apikey_is_jwt: c !== null,
        apikey_role: c?.role ?? null,
        apikey_ref_matches: c ? c.ref === PROJECT_REF : null,
        bearer_len: b.length,
        configured_keys: PROJECT_KEYS.length,
        has_project_ref: PROJECT_REF.length > 0,
      }),
    );
  }
  return ok;
}

type Authz =
  | { ok: true; isSender: boolean }
  | { ok: false; status: number; error: string };

const deny = (): Authz => ({ ok: false, status: 403, error: "Forbidden" });

async function authorize(
  msg: Row,
  viewerRole: string,
  viewerId: number,
): Promise<Authz> {
  const convRes = await fetch(
    rest(
      `chat_conversations?id=eq.${msg.conversation_id}` +
        `&select=id,booking_reference&limit=1`,
    ),
    { headers: restHeaders },
  );
  if (!convRes.ok) return { ok: false, status: 502, error: "Lookup failed" };
  const convs = await convRes.json();
  if (!Array.isArray(convs) || convs.length === 0) return deny();
  const conv = convs[0] as Row;

  // Negative ids are TEST-only identities: valid solely on the TEST booking.
  const isTestConv =
    String(conv.booking_reference ?? "").trim().toUpperCase() ===
      TEST_BOOKING_REFERENCE;
  if (viewerId < 0 && !isTestConv) return deny();
  if (viewerId === 0) return deny();

  const senderRole = String(msg.sender_role ?? "");
  const senderId = Number(msg.odoo_sender_id);

  // The sender may read their own transcript.
  if (viewerRole === senderRole) {
    return viewerId === senderId ? { ok: true, isSender: true } : deny();
  }

  // Opposite role = recipient. They must be a real participant of THIS
  // conversation: a different-role identity that has posted in it, OR (TEST
  // booking only) the fixed negative TEST identity of that role.
  if (isTestConv && viewerId < 0) {
    const expected = viewerRole === "customer" ? -1 : -2;
    return viewerId === expected ? { ok: true, isSender: false } : deny();
  }

  // A recipient does NOT have to have sent a message first. Participation is
  // proven by the first rule that matches (all server-side, service role):
  //   1. DRIVER only: the id appears in chat_driver_changes for this
  //      conversation (current OR previous driver => replacement and
  //      historical access are respected).
  //   2. The id has already posted in this conversation as this role.
  //   3. First contact: no identity of the recipient's role has established
  //      itself in this conversation yet (no posts, and for drivers no
  //      recorded driver assignment). The first recipient to authenticate with
  //      the project key binds that slot; every DIFFERENT id of the same role
  //      is refused from then on, so access is never unrestricted.
  if (viewerRole === "driver") {
    const chgRes = await fetch(
      rest(
        `chat_driver_changes?conversation_id=eq.${msg.conversation_id}` +
          `&or=(new_driver_odoo_id.eq.${viewerId},` +
          `previous_driver_odoo_id.eq.${viewerId})` +
          `&select=id&limit=1`,
      ),
      { headers: restHeaders },
    );
    if (!chgRes.ok) return { ok: false, status: 502, error: "Lookup failed" };
    const chg = await chgRes.json();
    if (Array.isArray(chg) && chg.length > 0) {
      return { ok: true, isSender: false };
    }
  }

  const partRes = await fetch(
    rest(
      `chat_messages?conversation_id=eq.${msg.conversation_id}` +
        `&sender_role=eq.${viewerRole}` +
        `&select=odoo_sender_id&limit=1000`,
    ),
    { headers: restHeaders },
  );
  if (!partRes.ok) return { ok: false, status: 502, error: "Lookup failed" };
  const posted = await partRes.json();
  if (!Array.isArray(posted)) return deny();

  // Rule 2: this exact id has posted as this role.
  if (posted.some((r: Row) => Number(r.odoo_sender_id) === viewerId)) {
    return { ok: true, isSender: false };
  }

  // Rule 3: role slot still unclaimed => first-contact recipient allowed.
  // Any posted id (other than the viewer) means the slot is taken.
  const slotTaken = posted.some(
    (r: Row) => Number(r.odoo_sender_id) !== viewerId,
  );
  if (slotTaken) return deny();

  if (viewerRole === "driver") {
    // A recorded driver assignment also claims the slot.
    const anyChgRes = await fetch(
      rest(
        `chat_driver_changes?conversation_id=eq.${msg.conversation_id}` +
          `&select=id&limit=1`,
      ),
      { headers: restHeaders },
    );
    if (!anyChgRes.ok) {
      return { ok: false, status: 502, error: "Lookup failed" };
    }
    const anyChg = await anyChgRes.json();
    if (Array.isArray(anyChg) && anyChg.length > 0) return deny();
  }

  // TODO(production): replace rules 2-3 with verified Odoo assignment
  // (booking.customer_id / assigned driver) once Odoo token auth exists.
  console.log(
    "recipient first-contact allowed:",
    JSON.stringify({ role: viewerRole, conversation: msg.conversation_id }),
  );
  return { ok: true, isSender: false };
}

// ---------------------------------------------------------------
// DB helpers (every result is checked)
// ---------------------------------------------------------------

// Last PostgREST error (non-secret fields only). Used to log and to tell the
// caller WHICH database operation failed instead of a generic 503.
type DbErr = {
  step: string;
  http: number;
  code: string | null;
  message: string | null;
  details: string | null;
  hint: string | null;
};
let lastDbError: DbErr | null = null;

async function captureDbError(step: string, res: Response): Promise<void> {
  let body: Row = {};
  try {
    body = (await res.json()) as Row;
  } catch {
    body = {};
  }
  lastDbError = {
    step,
    http: res.status,
    code: body?.code != null ? String(body.code) : null,
    message: body?.message != null ? String(body.message) : null,
    details: body?.details != null ? String(body.details) : null,
    hint: body?.hint != null ? String(body.hint) : null,
  };
  console.error("db error:", JSON.stringify(lastDbError));
}

const storageUnavailable = () =>
  json(
    {
      error: "Storage unavailable",
      step: lastDbError?.step ?? "unknown",
      db_http: lastDbError?.http ?? null,
      db_code: lastDbError?.code ?? null,
    },
    503,
  );

async function getTranscription(messageId: string): Promise<Row | null | "error"> {
  const res = await fetch(
    rest(`chat_voice_transcriptions?message_id=eq.${messageId}&select=*&limit=1`),
    { headers: restHeaders },
  );
  if (!res.ok) {
    await captureDbError("get_chat_voice_transcriptions", res);
    return "error";
  }
  const rows = await res.json();
  return Array.isArray(rows) && rows.length > 0 ? rows[0] : null;
}

async function rpc<T = unknown>(name: string, args: Row): Promise<T | null> {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: restHeaders,
    body: JSON.stringify(args),
  });
  if (!res.ok) {
    await captureDbError(`rpc_${name}`, res);
    return null;
  }
  return (await res.json()) as T;
}

async function getCachedTranslation(
  messageId: string,
  target: string,
): Promise<string | null> {
  const res = await fetch(
    rest(
      `chat_translations?message_id=eq.${messageId}` +
        `&target_language=eq.${target}&select=translated_text&limit=1`,
    ),
    { headers: restHeaders },
  );
  if (!res.ok) return null;
  const rows = await res.json();
  const t = Array.isArray(rows) && rows.length > 0
    ? String(rows[0].translated_text ?? "")
    : "";
  return t.length > 0 ? t : null;
}

// Translation failure is NOT a transcription failure: transcript is kept.
// Returns { text, disabled }: `disabled` means the AI switch (server side,
// either here or inside chat-translate) refused a NEW translation.
async function translateAndCache(
  messageId: string,
  text: string,
  source: string,
  target: string,
  internalToken: string,
): Promise<{ text: string | null; disabled: boolean }> {
  try {
    const trRes = await fetch(`${SUPABASE_URL}/functions/v1/chat-translate`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-internal-token": internalToken,
        Authorization: `Bearer ${SERVICE_KEY}`,
      },
      body: JSON.stringify({
        text,
        source_language: source,
        target_language: target,
        service: "voice_text_translation",
      }),
    });
    if (!trRes.ok) {
      console.error("chat-translate failed:", trRes.status);
      return { text: null, disabled: false };
    }
    const tr = await trRes.json();
    if (tr?.status === "service_disabled") {
      return { text: null, disabled: true };
    }
    const translated = String(tr?.translated_text ?? "").trim();
    if (!translated) return { text: null, disabled: false };
    const save = await fetch(
      rest("chat_translations?on_conflict=message_id,target_language"),
      {
        method: "POST",
        headers: {
          ...restHeaders,
          Prefer: "resolution=merge-duplicates,return=minimal",
        },
        body: JSON.stringify({
          message_id: messageId,
          target_language: target,
          translated_text: translated,
        }),
      },
    );
    // Cache write failure is non-fatal: the translated text is still valid.
    if (!save.ok) console.error("store translation failed:", save.status);
    return { text: translated, disabled: false };
  } catch (e) {
    console.error("translate error:", e instanceof Error ? e.message : "unknown");
    return { text: null, disabled: false };
  }
}

async function respondWithTranscript(
  messageId: string,
  transcript: string,
  source: string | null,
  target: string,
  internalToken: string,
  cachedState: string,
) {
  // Uncertain source language: never guess a translation direction.
  if (!source) {
    return json({
      status: "ready",
      transcript_state: cachedState,
      transcript_text: transcript,
      source_language: null,
      language_uncertain: true,
      target_language: target,
      translated_text: "",
      translation_status: "language_uncertain",
    });
  }
  if (source === target) {
    return json({
      status: "ready",
      transcript_state: cachedState,
      transcript_text: transcript,
      source_language: source,
      target_language: target,
      translation_status: "same_language",
    });
  }
  let translated = await getCachedTranslation(messageId, target);
  let trStatus = "cached";
  if (!translated) {
    // Switch OFF => NO new translation. The original transcript stays
    // available and the response says why.
    const flags = await loadAiFlags();
    if (!flags.voice_text_translation_enabled) {
      return json({
        status: "ready",
        transcript_state: cachedState,
        transcript_text: transcript,
        source_language: source,
        target_language: target,
        translated_text: "",
        translation_status: "service_disabled",
        service: "voice_text_translation",
      });
    }
    const tr = await translateAndCache(
      messageId, transcript, source, target, internalToken,
    );
    if (tr.disabled) {
      return json({
        status: "ready",
        transcript_state: cachedState,
        transcript_text: transcript,
        source_language: source,
        target_language: target,
        translated_text: "",
        translation_status: "service_disabled",
        service: "voice_text_translation",
      });
    }
    translated = tr.text;
    trStatus = translated ? "translated" : "failed";
  }
  return json({
    status: "ready",
    transcript_state: cachedState,
    transcript_text: transcript,
    source_language: source,
    target_language: target,
    translated_text: translated ?? "",
    translation_status: trStatus,
  });
}


// ---------------------------------------------------------------
// Handler
// ---------------------------------------------------------------

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return json({ ok: true });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const internalTokenEnv = Deno.env.get("CHAT_INTERNAL_TOKEN") ?? "";
  const internalToken: string = internalTokenEnv;
  const openaiKey = Deno.env.get("OPENAI_API_KEY");
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
  const target = body?.target_language;
  const viewerRole = body?.viewer_role;
  const viewerId = Number(body?.viewer_id);
  const retry = body?.retry === true;
  const action = body?.action === "sign_audio" ? "sign_audio" : "transcribe";

  // Playback signing never calls chat-translate, so it does not need the
  // internal token. Transcription does.
  if (action === "transcribe" && !internalToken) {
    return json({ error: "Function not configured" }, 503);
  }

  if (
    typeof messageId !== "string" || !UUID_RE.test(messageId) ||
    (action === "transcribe" &&
      (typeof target !== "string" || !LANGUAGES.includes(target))) ||
    (viewerRole !== "customer" && viewerRole !== "driver") ||
    !Number.isInteger(viewerId) || viewerId === 0
  ) {
    return json({ error: "Invalid request" }, 400);
  }

  // Set once a claim is taken, so the finally block can always resolve it.
  let claimToken: string | null = null;
  let claimResolved = false;

  try {
    // 1. Load message.
    const msgRes = await fetch(
      rest(
        `chat_messages?id=eq.${messageId}` +
          `&select=id,conversation_id,sender_role,odoo_sender_id,message_type,` +
          `audio_path,audio_duration_seconds`,
      ),
      { headers: restHeaders },
    );
    if (!msgRes.ok) return json({ error: "Message lookup failed" }, 502);
    const rows = await msgRes.json();
    // Not found and not-authorized look identical (no existence oracle).
    if (!Array.isArray(rows) || rows.length === 0) {
      return json({ error: "Forbidden" }, 403);
    }
    const msg = rows[0] as Row;

    // 2. AUTHORIZE before any paid / private operation.
    const authz = await authorize(msg, viewerRole, viewerId);
    if (!authz.ok) {
      console.error(
        "authorize denied:",
        JSON.stringify({
          action,
          http: authz.status,
          viewer_role: viewerRole,
          viewer_id: viewerId,
          sender_role: msg.sender_role,
          conversation: msg.conversation_id,
        }),
      );
      return json({ error: authz.error }, authz.status);
    }

    // 2b. PLAYBACK: the bucket is private and anon has no SELECT policy, so
    //     the client cannot sign URLs itself. After the same authorization
    //     (sender or counterpart in this conversation) the service role
    //     issues a short-lived signed URL. No transcription is involved.
    if (action === "sign_audio") {
      if (msg.message_type !== "voice" || !msg.audio_path) {
        return json({ error: "Not found" }, 404);
      }
      const objectPath = String(msg.audio_path)
        .split("/")
        .map(encodeURIComponent)
        .join("/");
      const signRes = await fetch(
        `${SUPABASE_URL}/storage/v1/object/sign/${BUCKET}/${objectPath}`,
        {
          method: "POST",
          headers: restHeaders,
          body: JSON.stringify({ expiresIn: 3600 }),
        },
      );
      if (!signRes.ok) {
        console.error("sign audio failed:", signRes.status);
        return json({ error: "Audio unavailable" }, 404);
      }
      const signed = await signRes.json();
      const rel = String(signed?.signedURL ?? signed?.signedUrl ?? "");
      if (!rel) return json({ error: "Audio unavailable" }, 404);
      // signedURL is relative to /storage/v1 (e.g. /object/sign/...?token=)
      const url = rel.startsWith("http")
        ? rel
        : `${SUPABASE_URL}/storage/v1${rel.startsWith("/") ? "" : "/"}${rel}`;
      return json({ status: "ok", url });
    }

    if (msg.message_type !== "voice" || !msg.audio_path) {
      return json({ status: "skipped", reason: "not_voice" });
    }
    const duration = Number(msg.audio_duration_seconds ?? 0);
    if (!(duration > 0) || duration > MAX_SECONDS + 1) {
      return json({ status: "skipped", reason: "duration_not_allowed" });
    }

    // 3. Reuse a stored transcription: no OpenAI call.
    const existing = await getTranscription(messageId);
    if (existing === "error") return storageUnavailable();

    const readyText = existing
      ? String(existing.transcript_text ?? "").trim()
      : "";
    if (existing && existing.status === "ready" && readyText.length > 0) {
      const stored = normalizeLang(existing.detected_language);
      // Re-resolve from the text if the stored value is missing.
      const source = stored ?? resolveLanguage(readyText, null).language;
      // Heal rows saved earlier with a NULL language (old detection never
      // had OpenAI metadata) so TTS and the app list see a usable language.
      // Only a NULL value is ever updated; real values are never overwritten.
      if (!stored && source) {
        try {
          await fetch(
            rest(
              `chat_voice_transcriptions?message_id=eq.${messageId}` +
                `&detected_language=is.null`,
            ),
            {
              method: "PATCH",
              headers: { ...restHeaders, Prefer: "return=minimal" },
              body: JSON.stringify({ detected_language: source }),
            },
          );
        } catch (_) {
          console.error("language heal failed");
        }
      }
      return await respondWithTranscript(
        messageId, readyText, source, target, internalToken, "cached",
      );
    }

    if (!openaiKey) return json({ error: "OpenAI not configured" }, 503);

    // 3b. Server-side AI switch for NEW speech-to-text. Existing ready
    //     transcripts were already served above. The original recording and
    //     its playback (sign_audio) are not affected. No claim row is created
    //     and OpenAI is not called while the service is disabled.
    const aiFlags = await loadAiFlags();
    if (!aiFlags.voice_transcription_enabled) {
      return json({
        status: "service_disabled",
        service: "voice_transcription",
      });
    }

    // 4. Atomic claim (SQL). Only one request wins; stale pending rows and
    //    explicitly retried failures are taken over with bounded attempts.
    const claim = await rpc<Row[]>("chat_voice_claim_transcription", {
      p_message_id: messageId,
      p_duration: Math.round(duration),
      p_model: MODEL,
      p_allow_retry: retry,
      p_stale_seconds: STALE_SECONDS,
      p_max_attempts: MAX_ATTEMPTS,
    });
    if (!Array.isArray(claim) || claim.length === 0) {
      return storageUnavailable();
    }
    const c = claim[0];
    if (c.claimed !== true || typeof c.claim_token !== "string") {
      const st = String(c.status ?? "pending");
      if (st === "failed") {
        const exhausted = Number(c.attempts ?? 0) >= MAX_ATTEMPTS;
        return json({
          status: "failed",
          error_code: exhausted ? "max_attempts" : "failed",
          retryable: !exhausted,
        });
      }
      return json({ status: "pending" });
    }
    claimToken = c.claim_token;
    // Attempts used including this one (claim increments it atomically).
    // When the budget is spent, a failure is reported as non-retryable so the
    // app stops offering/performing retries (no infinite loop).
    const attemptsUsed = Number(c.attempts ?? 1);
    const budgetLeft = attemptsUsed < MAX_ATTEMPTS;

    // Resolves the claim exactly once (ready | failed).
    const resolveClaim = async (
      status: "ready" | "failed",
      text: string | null,
      lang: string | null,
      errorCode: string | null,
    ): Promise<boolean> => {
      const ok = await rpc<boolean>("chat_voice_save_transcription", {
        p_message_id: messageId,
        p_claim_token: claimToken,
        p_status: status,
        p_text: text,
        p_language: lang,
        p_error_code: errorCode,
      });
      if (ok === true) claimResolved = true;
      return ok === true;
    };
    const fail = async (code: string, retryable = true) => {
      await resolveClaim("failed", null, null, code);
      return json({
        status: "failed",
        error_code: code,
        retryable: retryable && budgetLeft,
        attempts: attemptsUsed,
        max_attempts: MAX_ATTEMPTS,
      });
    };

    // 5. Download ORIGINAL audio (private bucket, read-only).
    const path = String(msg.audio_path)
      .split("/")
      .map(encodeURIComponent)
      .join("/");
    const audioRes = await fetch(
      `${SUPABASE_URL}/storage/v1/object/${BUCKET}/${path}`,
      { headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` } },
    );
    if (!audioRes.ok) return await fail("audio_unavailable");
    const audioBlob = await audioRes.blob();
    if (audioBlob.size === 0) return await fail("audio_empty", false);
    if (audioBlob.size > 10 * 1024 * 1024) return await fail("audio_too_large", false);

    // Detect the REAL container from the bytes. Files already stored may be
    // named .webm while actually holding MP4/AAC or WAV; OpenAI validates the
    // content against the file name/type and answers HTTP 400 on a mismatch.
    const head = new Uint8Array(await audioBlob.slice(0, 16).arrayBuffer());
    const detected = sniffAudio(head);
    const pathExt = String(msg.audio_path).split(".").pop()?.toLowerCase() ?? "";
    const knownExt = ["m4a", "mp4", "aac", "mp3", "mpeg", "ogg", "webm", "wav"];
    const useExt = detected
      ? detected.ext
      : (knownExt.includes(pathExt) ? pathExt : "m4a");
    const useMime = detected
      ? detected.mime
      : (useExt === "webm" ? "audio/webm" : useExt === "wav" ? "audio/wav"
        : useExt === "ogg" ? "audio/ogg" : useExt === "mp3" ? "audio/mpeg"
        : "audio/mp4");
    const fileName = `voice.${useExt}`;
    // Metadata only: never audio content, never keys.
    console.log(
      "stt upload:",
      JSON.stringify({
        stored_ext: pathExt,
        detected: detected?.ext ?? null,
        sent_name: fileName,
        sent_type: useMime,
        bytes: audioBlob.size,
        stored_type: audioBlob.type || null,
        head_hex: Array.from(head.slice(0, 12))
          .map((x) => x.toString(16).padStart(2, "0")).join(""),
      }),
    );
    const audioFile = new Blob([await audioBlob.arrayBuffer()], {
      type: useMime,
    });

    // 6. Speech-to-text (auto language detection, bounded by a timeout).
    const form = new FormData();
    form.append("file", audioFile, fileName);
    form.append("model", MODEL);
    // gpt-4o-mini-transcribe supports only response_format=json. The json
    // response has no `language` field, so language is resolved from the
    // transcript (script + evidence, then a language-ID fallback).
    form.append("response_format", "json");
    form.append("temperature", "0");
    form.append(
      "prompt",
      "Transcribe exactly what is spoken. Keep names, hotel names, booking " +
        "references (e.g. RQ.14596), flight numbers, dates, times and numbers " +
        "unchanged. Do not add words that were not spoken.",
    );
    const ctl = new AbortController();
    const timer = setTimeout(() => ctl.abort(), OPENAI_TIMEOUT_MS);
    let sttRes: Response;
    try {
      sttRes = await fetch("https://api.openai.com/v1/audio/transcriptions", {
        method: "POST",
        headers: { Authorization: `Bearer ${openaiKey}` },
        body: form,
        signal: ctl.signal,
      });
    } catch {
      await logUsage({
        service: "voice_transcription",
        success: false,
        model: MODEL,
        audioSeconds: duration,
        errorCode: "stt_timeout",
      });
      return await fail("stt_timeout");
    } finally {
      clearTimeout(timer);
    }
    if (!sttRes.ok) {
      // Safe diagnostics: OpenAI's error object (type/code/message/param) only.
      // The request body (audio) and the Authorization header are never logged.
      let oaErr: Row = {};
      try {
        const raw = (await sttRes.json()) as Row;
        const e = (raw?.error ?? raw) as Row;
        oaErr = {
          type: e?.type ?? null,
          code: e?.code ?? null,
          param: e?.param ?? null,
          message: String(e?.message ?? "").slice(0, 300),
        };
      } catch {
        oaErr = { message: "unparseable error body" };
      }
      console.error(
        "openai transcription failed:",
        JSON.stringify({
          http: sttRes.status,
          error: oaErr,
          sent_name: fileName,
          sent_type: useMime,
          bytes: audioBlob.size,
        }),
      );
      await logUsage({
        service: "voice_transcription",
        success: false,
        model: MODEL,
        audioSeconds: duration,
        errorCode: `stt_${sttRes.status}`,
      });
      // Only 429 and 5xx can succeed on retry. Every other 4xx (including
      // 400) is permanent: report retryable=false so the app stops retrying.
      const transient = sttRes.status === 429 || sttRes.status >= 500;
      return await fail(`stt_${sttRes.status}`, transient);
    }
    const stt = await sttRes.json();
    const transcript = String(stt?.text ?? "").trim();
    await logUsage({
      service: "voice_transcription",
      success: transcript.length > 0,
      model: MODEL,
      audioSeconds: duration,
      errorCode: transcript.length > 0 ? null : "empty_transcript",
    });
    if (!transcript) return await fail("empty_transcript", false);

    // 7. Resolve language by evidence. json responses carry no language
    // metadata, so ambiguous Latin text goes to a language-ID fallback.
    // Uncertain => stored as NULL.
    let resolved = resolveLanguage(transcript, stt?.language);
    if (resolved.needsLangId) {
      const identified = await identifyLatinLanguage(transcript, openaiKey);
      resolved = identified
        ? { language: identified, uncertain: false, needsLangId: false }
        : { language: null, uncertain: true, needsLangId: false };
    }

    // 8. Persist. A failed save is NEVER reported as success.
    const saved = await resolveClaim(
      "ready", transcript, resolved.language, null,
    );
    if (!saved) {
      // One more attempt at the write (transient DB error). If it still
      // fails we return a FAILURE (never "ready"). The finally block then
      // releases the claim as 'failed' so the message cannot stay pending.
      // Note: the transcript is not persisted in this case, so an explicit
      // retry will call OpenAI once more (bounded by MAX_ATTEMPTS).
      const retried = await resolveClaim(
        "ready", transcript, resolved.language, null,
      );
      if (!retried) {
        console.error("store transcript failed for", messageId);
        return json(
          { status: "failed", error_code: "save_failed", retryable: true },
          503,
        );
      }
    }

    return await respondWithTranscript(
      messageId, transcript, resolved.language, target, internalToken, "new",
    );
  } catch (e) {
    // Safe diagnostics only: error name, truncated message and the first
    // stack frame. Never the audio, request body, headers or API keys.
    const err = e instanceof Error ? e : null;
    console.error(
      "chat-transcribe-message error:",
      JSON.stringify({
        name: err?.name ?? typeof e,
        message: String(err?.message ?? "unknown").slice(0, 300),
        frame: String(err?.stack ?? "").split("\n")[1]?.trim().slice(0, 200) ?? null,
      }),
    );
    if (claimToken && !claimResolved) {
      try {
        const ok = await rpc<boolean>("chat_voice_save_transcription", {
          p_message_id: messageId,
          p_claim_token: claimToken,
          p_status: "failed",
          p_text: null,
          p_language: null,
          p_error_code: "internal_error",
        });
        if (ok === true) claimResolved = true;
      } catch (_) {
        // finally block / stale takeover recovers the claim.
      }
    }
    return json(
      {
        status: "failed",
        error_code: "internal_error",
        retryable: !claimToken ? true : false,
      },
      500,
    );
  } finally {
    // Any exit path that still owns the claim (exception, early return,
    // save failure) flips it to 'failed' so it cannot stay 'pending'.
    if (claimToken && !claimResolved) {
      try {
        await rpc<boolean>("chat_voice_save_transcription", {
          p_message_id: messageId,
          p_claim_token: claimToken,
          p_status: "failed",
          p_text: null,
          p_language: null,
          p_error_code: "interrupted",
        });
      } catch (_) {
        // Last resort: chat_voice_release_stale() / stale takeover recovers it.
      }
    }
  }
});

// ======================================================
// TourOps Smart Chat
// Edge Function: chat-tts-message  (PHASE 3.2, TEST, simplified)
//
// Called by the Flutter app with:
//   { message_id, target_language, viewer_role, viewer_id, retry? }
//
// Returns a short-lived signed URL to a TRANSLATED audio rendition of a
// received voice message, generated ON DEMAND with ElevenLabs
// text-to-speech and cached privately in Storage (bucket chat-tts).
// Original audio untouched. ElevenLabs is the ONLY TTS provider.
//
// Secrets stay server-side (Supabase Edge Function secrets):
//   * SUPABASE_SERVICE_ROLE_KEY (writes DB/Storage)
//   * ELEVENLABS_API_KEY        (ElevenLabs text-to-speech)
// Nothing here is ever sent to Flutter.
//
// Authorization is IDENTICAL to Phase 3.1 (chat-transcribe-message):
// project key + viewer identity, sender / recipient of the conversation,
// chat_driver_changes for current AND previous drivers, TEST negative ids
// only on the TEST booking, generic 403 (no existence leak).
//
// Voice selection: ONE fixed ElevenLabs Voice ID per target language.
// No audio is downloaded or analysed, and no gender is inferred.
//
// Cache identity: provider | model | voice_id (+ Arabic spoken-text
// version). A cached row is only served when ALL of these match.
//
// Also supports { action: "check_voices" } (project key required): a
// read-only call that reports whether the ElevenLabs key is configured
// and lists the provider / model / Voice ID per language. No synthesis,
// no cost, no data returned except configuration.
// ======================================================

const LANGUAGES = ["ar", "en", "ru", "ka", "az"];

// ---- Inlined booking-scoped Odoo JWT guard (no external module import) ----
type GuardResult = { ok: true } | { ok: false; status: number; error: string };

function jwtAuthEnabled(): boolean {
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

async function guardConversation(
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
// ---- end inlined guard ----

const TTS_BUCKET = "chat-tts";
const STALE_SECONDS = 120;
const MAX_ATTEMPTS = 3;
const TTS_TIMEOUT_MS = 30_000;
const SIGN_SECONDS = 300;
const MAX_TTS_CHARS = 1500;
const OUTPUT_FORMAT = "mp3_44100_64";
const TEST_BOOKING_REFERENCE = "RQ.TEST14596";
const UUID_RE = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;

// Bump when the voice mapping / provider config changes. Reported by
// check_voices so the deployed version can be verified from the Dashboard.
const VOICE_CONFIG_VERSION = "elevenlabs-v1";

// Single TTS provider. Stored in the cache identity.
const TTS_PROVIDER = "elevenlabs";

// ONE model for all five languages. eleven_v3 is the only ElevenLabs model
// that covers Azerbaijani AND Georgian (multilingual_v2 / flash_v2_5 do not).
const TTS_MODEL = "eleven_v3";

// Arabic spoken text is converted to Saudi/Gulf conversational dialect
// before synthesis. Bump this to invalidate all cached Arabic audio.
// Other languages are unaffected.
const AR_SPOKEN_VERSION = "gulf-v1";

// Approved ElevenLabs Voice IDs: exactly one voice per language.
// `lang` is the ISO 639-1 code sent to ElevenLabs as language_code.
const VOICES: Record<string, { lang: string; voiceId: string }> = {
  ar: { lang: "ar", voiceId: "rpGHcNQJvO8dFNNFNj1v" },
  en: { lang: "en", voiceId: "As26suQ3OEBZ7qyRj8K1" },
  ru: { lang: "ru", voiceId: "XuEV9VY3VUASYgJVNBh0" },
  ka: { lang: "ka", voiceId: "pNInz6obpgDQGcFmaJgB" },
  az: { lang: "az", voiceId: "IVMbfLv3KqUc4qDj6Yif" },
};

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Cache key stored in chat_voice_tts.voice_name:
//   provider|model|voice_id            (en, ru, ka, az)
//   provider|model|voice_id|gulf-v1    (ar)
// Any change of provider, model or Voice ID (or the Arabic spoken version)
// no longer matches old rows, so that audio is regenerated once. Legacy
// Azure rows (plain Azure voice names) never match and are never served.
function voiceCacheKey(target: string): string {
  const v = VOICES[target];
  const base = `${TTS_PROVIDER}|${TTS_MODEL}|${v.voiceId}`;
  return target === "ar" ? `${base}|${AR_SPOKEN_VERSION}` : base;
}

// Storage-path-safe form of the cache identity (no "|").
function voicePathKey(target: string): string {
  const v = VOICES[target];
  const base = `${TTS_PROVIDER}.${TTS_MODEL}.${v.voiceId}`;
  return target === "ar" ? `${base}.${AR_SPOKEN_VERSION}` : base;
}

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

const restHeaders = {
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  "Content-Type": "application/json",
};

const rest = (path: string) => `${SUPABASE_URL}/rest/v1/${path}`;
type Row = Record<string, unknown>;

// ---------------------------------------------------------------
// AI switches (public.chat_ai_settings), read per request.
// Fails CLOSED for TTS (paid + off by default): unreadable => disabled.
// ---------------------------------------------------------------

type TtsFlags = { generation: boolean; playback: boolean };

async function loadTtsFlags(): Promise<TtsFlags> {
  const closed: TtsFlags = { generation: false, playback: false };
  try {
    const res = await fetch(
      rest(
        "chat_ai_settings?id=eq.1" +
          "&select=voice_tts_generation_enabled,voice_tts_playback_enabled" +
          "&limit=1",
      ),
      { headers: restHeaders },
    );
    if (!res.ok) {
      console.error("ai settings read failed:", res.status);
      return closed;
    }
    const rows = await res.json();
    if (!Array.isArray(rows) || rows.length === 0) return closed;
    return {
      generation: rows[0].voice_tts_generation_enabled === true,
      playback: rows[0].voice_tts_playback_enabled === true,
    };
  } catch (_) {
    console.error("ai settings read error");
    return closed;
  }
}

// Metadata-only usage record (no text, no URLs, no keys).
async function logUsage(entry: {
  success: boolean;
  model?: string | null;
  errorCode?: string | null;
}): Promise<void> {
  try {
    const res = await fetch(rest("chat_ai_usage_log"), {
      method: "POST",
      headers: { ...restHeaders, Prefer: "return=minimal" },
      body: JSON.stringify({
        service_type: "voice_tts",
        success: entry.success,
        model: entry.model ?? null,
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
// Authorization (copied unchanged from Phase 3.1)
// ---------------------------------------------------------------

function bearer(req: Request): string {
  const h = req.headers.get("authorization") ?? "";
  return h.toLowerCase().startsWith("bearer ") ? h.slice(7).trim() : "";
}

function hasProjectKey(req: Request): boolean {
  if (PROJECT_KEYS.length === 0 && !PROJECT_REF) return false;
  const k = req.headers.get("apikey") ?? "";
  const b = bearer(req);
  const exact = PROJECT_KEYS.some((p) => p === k || p === b);
  const claimOk = k.length > 0 && isThisProjectAnon(k);
  return exact || claimOk;
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

  const isTestConv =
    String(conv.booking_reference ?? "").trim().toUpperCase() ===
      TEST_BOOKING_REFERENCE;
  if (viewerId < 0 && !isTestConv) return deny();
  if (viewerId === 0) return deny();

  const senderRole = String(msg.sender_role ?? "");
  const senderId = Number(msg.odoo_sender_id);

  if (viewerRole === senderRole) {
    return viewerId === senderId ? { ok: true, isSender: true } : deny();
  }

  if (isTestConv && viewerId < 0) {
    const expected = viewerRole === "customer" ? -1 : -2;
    return viewerId === expected ? { ok: true, isSender: false } : deny();
  }

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

  if (posted.some((r: Row) => Number(r.odoo_sender_id) === viewerId)) {
    return { ok: true, isSender: false };
  }

  const slotTaken = posted.some(
    (r: Row) => Number(r.odoo_sender_id) !== viewerId,
  );
  if (slotTaken) return deny();

  if (viewerRole === "driver") {
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

  // TODO(production): replace with verified Odoo assignment.
  return { ok: true, isSender: false };
}

// ---------------------------------------------------------------
// DB helpers
// ---------------------------------------------------------------

async function rpc<T = unknown>(name: string, args: Row): Promise<T | null> {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: restHeaders,
    body: JSON.stringify(args),
  });
  if (!res.ok) {
    console.error("rpc failed:", name, res.status);
    return null;
  }
  return (await res.json()) as T;
}

async function getTranscript(messageId: string): Promise<
  { text: string; lang: string | null } | null
> {
  const res = await fetch(
    rest(
      `chat_voice_transcriptions?message_id=eq.${messageId}` +
        `&select=transcript_text,detected_language,status&limit=1`,
    ),
    { headers: restHeaders },
  );
  if (!res.ok) return null;
  const rows = await res.json();
  if (!Array.isArray(rows) || rows.length === 0) return null;
  const r = rows[0] as Row;
  const text = String(r.transcript_text ?? "").trim();
  if (r.status !== "ready" || !text) return null;
  let lang: string | null = LANGUAGES.includes(String(r.detected_language))
    ? String(r.detected_language)
    : null;
  // Legacy rows saved without a language: infer it from the script so
  // "Listen Translated" is not blocked solely by missing metadata.
  if (!lang) lang = inferLangFromScript(text);
  return { text, lang };
}

function inferLangFromScript(text: string): string | null {
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
  // Latin: Azerbaijani-specific letters => ambiguous (leave uncertain);
  // otherwise English.
  return /[əƏğĞıİöÖüÜçÇşŞ]/.test(text) ? null : "en";
}

async function getTranslation(
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
    ? String(rows[0].translated_text ?? "").trim()
    : "";
  return t.length > 0 ? t : null;
}

// Produces natural Saudi/Gulf conversational Arabic from the ORIGINAL
// transcript (not from the stored written Arabic), so the spoken meaning
// stays faithful. Server-side only. Returns null on any failure; the caller
// then falls back to the stored translation so audio is never blocked.
async function toGulfSpokenArabic(
  transcript: string,
  sourceLang: string,
): Promise<string | null> {
  const internalToken = Deno.env.get("CHAT_INTERNAL_TOKEN") ?? "";
  if (!internalToken) return null;
  try {
    const res = await fetch(`${SUPABASE_URL}/functions/v1/chat-translate`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-internal-token": internalToken,
        Authorization: `Bearer ${SERVICE_KEY}`,
      },
      body: JSON.stringify({
        text: transcript,
        source_language: sourceLang,
        target_language: "ar",
        service: "voice_text_translation",
        spoken_style: "gulf",
      }),
    });
    if (!res.ok) {
      console.error("gulf spoken conversion failed:", res.status);
      return null;
    }
    const tr = await res.json();
    if (tr?.status === "service_disabled") return null;
    const out = String(tr?.translated_text ?? "").trim();
    return out.length > 0 ? out : null;
  } catch (_) {
    console.error("gulf spoken conversion error");
    return null;
  }
}

async function getTtsRow(
  messageId: string,
  target: string,
): Promise<Row | null | "error"> {
  const res = await fetch(
    rest(
      `chat_voice_tts?message_id=eq.${messageId}` +
        `&target_language=eq.${target}&select=*&limit=1`,
    ),
    { headers: restHeaders },
  );
  if (!res.ok) return "error";
  const rows = await res.json();
  return Array.isArray(rows) && rows.length > 0 ? rows[0] : null;
}

// ---------------------------------------------------------------
// Storage helpers
// ---------------------------------------------------------------

const encodePath = (p: string) =>
  p.split("/").map(encodeURIComponent).join("/");

async function signTts(path: string): Promise<string | null> {
  const res = await fetch(
    `${SUPABASE_URL}/storage/v1/object/sign/${TTS_BUCKET}/${encodePath(path)}`,
    {
      method: "POST",
      headers: restHeaders,
      body: JSON.stringify({ expiresIn: SIGN_SECONDS }),
    },
  );
  if (!res.ok) return null;
  const signed = await res.json();
  const rel = String(signed?.signedURL ?? signed?.signedUrl ?? "");
  if (!rel) return null;
  return rel.startsWith("http")
    ? rel
    : `${SUPABASE_URL}/storage/v1${rel.startsWith("/") ? "" : "/"}${rel}`;
}

async function uploadTts(path: string, bytes: Uint8Array): Promise<boolean> {
  const res = await fetch(
    `${SUPABASE_URL}/storage/v1/object/${TTS_BUCKET}/${encodePath(path)}`,
    {
      method: "POST",
      headers: {
        apikey: SERVICE_KEY,
        Authorization: `Bearer ${SERVICE_KEY}`,
        "Content-Type": "audio/mpeg",
        "x-upsert": "true",
      },
      body: bytes,
    },
  );
  if (!res.ok) console.error("tts upload failed:", res.status);
  return res.ok;
}

// ---------------------------------------------------------------
// ElevenLabs text-to-speech (the only TTS provider)
// ---------------------------------------------------------------

async function synthesize(
  text: string,
  voice: { lang: string; voiceId: string },
  apiKey: string,
): Promise<{ bytes: Uint8Array | null; status: number }> {
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), TTS_TIMEOUT_MS);
  try {
    const res = await fetch(
      `https://api.elevenlabs.io/v1/text-to-speech/${
        encodeURIComponent(voice.voiceId)
      }?output_format=${OUTPUT_FORMAT}`,
      {
        method: "POST",
        headers: {
          "xi-api-key": apiKey,
          "Content-Type": "application/json",
          Accept: "audio/mpeg",
        },
        body: JSON.stringify({
          text,
          model_id: TTS_MODEL,
          language_code: voice.lang,
        }),
        signal: ctl.signal,
      },
    );
    if (!res.ok) {
      // Status only. Never log the body, text or key.
      console.error("elevenlabs tts failed:", res.status);
      return { bytes: null, status: res.status };
    }
    const buf = new Uint8Array(await res.arrayBuffer());
    return { bytes: buf.length > 0 ? buf : null, status: res.status };
  } catch (_) {
    return { bytes: null, status: 0 };
  } finally {
    clearTimeout(timer);
  }
}

// Read-only configuration report. Makes NO ElevenLabs call (no cost) and
// returns no secret: only whether the key is set and the voice mapping.
function checkVoices(apiKeySet: boolean): Response {
  const voices = Object.entries(VOICES).map(([lang, v]) => ({
    language: lang,
    provider: TTS_PROVIDER,
    model: TTS_MODEL,
    voice_id: v.voiceId,
    cache_key: voiceCacheKey(lang),
  }));
  return json({
    status: "ok",
    provider: TTS_PROVIDER,
    model: TTS_MODEL,
    voice_config_version: VOICE_CONFIG_VERSION,
    api_key_configured: apiKeySet,
    voices,
  });
}

// ---------------------------------------------------------------
// Handler
// ---------------------------------------------------------------

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return json({ ok: true });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const elevenKey = Deno.env.get("ELEVENLABS_API_KEY") ?? "";
  if (!SUPABASE_URL || !SERVICE_KEY || PROJECT_KEYS.length === 0) {
    return json({ error: "Function not configured" }, 503);
  }
  if (!jwtAuthEnabled() && !hasProjectKey(req)) {
    return json({ error: "Unauthorized" }, 401);
  }

  let body: Row;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid request" }, 400);
  }

  if (body?.action === "check_voices") {
    return checkVoices(!!elevenKey);
  }

  const messageId = body?.message_id;
  const target = body?.target_language;
  const viewerRole = body?.viewer_role;
  const viewerId = Number(body?.viewer_id);
  const retry = body?.retry === true;

  if (
    typeof messageId !== "string" || !UUID_RE.test(messageId) ||
    typeof target !== "string" || !LANGUAGES.includes(target) ||
    (!jwtAuthEnabled() &&
      ((viewerRole !== "customer" && viewerRole !== "driver") ||
        !Number.isInteger(viewerId) || viewerId === 0))
  ) {
    return json({ error: "Invalid request" }, 400);
  }

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
    if (!Array.isArray(rows) || rows.length === 0) {
      return json({ error: "Forbidden" }, 403);
    }
    const msg = rows[0] as Row;

    // 2. AUTHORIZE (Phase 3.1 rules) before any paid / private operation.
    // JWT mode: the database decides from the booking token. Paid TTS
    // generation requires can_send, so a replaced driver is refused.
    const jwtMode = jwtAuthEnabled();
    const authz: Authz = jwtMode
      ? await (async (): Promise<Authz> => {
        const g = await guardConversation(req, String(msg.conversation_id), true);
        if (!g.ok) return { ok: false, status: g.status, error: g.error };
        // Own-message detection needs the verified id, which only the
        // database knows; a sender never needs translated audio of their
        // own voice, so compare against the message sender via the DB-checked
        // conversation: the caller cannot supply an id on this path.
        return { ok: true, isSender: false };
      })()
      : await authorize(msg, viewerRole as string, viewerId);
    if (!authz.ok) {
      console.error(
        "authorize denied:",
        JSON.stringify({
          http: authz.status,
          viewer_role: viewerRole,
          sender_role: msg.sender_role,
          conversation: msg.conversation_id,
        }),
      );
      return json({ error: authz.error }, authz.status);
    }

    // Translated audio is for RECEIVED messages only.
    if (authz.isSender) {
      return json({ status: "skipped", reason: "own_message" });
    }
    if (msg.message_type !== "voice" || !msg.audio_path) {
      return json({ status: "skipped", reason: "not_voice" });
    }

    // 3. Switches (fail closed).
    const flags = await loadTtsFlags();

    // 4. Cache hit => no ElevenLabs call, no claim. Serving it needs PLAYBACK on.
    //    The cache is PROVIDER + MODEL + VOICE-ID aware: a 'ready' row whose
    //    stored key (provider|model|voice_id[|ar version]) differs from the
    //    wanted key (e.g. legacy Azure audio) is NOT served; it is
    //    regenerated below. For Arabic the key also carries the Gulf
    //    spoken-text version.
    const wantedVoice = VOICES[target];
    const wantedKey = voiceCacheKey(target);
    const existing = await getTtsRow(messageId, target);
    if (existing === "error") {
      return json({ error: "Storage unavailable" }, 503);
    }
    if (
      existing && existing.status === "ready" &&
      typeof existing.audio_path === "string" && existing.audio_path &&
      existing.voice_name === wantedKey
    ) {
      if (!flags.playback) {
        return json({
          status: "service_disabled",
          service: "voice_tts_playback",
        });
      }
      const url = await signTts(String(existing.audio_path));
      if (!url) return json({ error: "Audio unavailable" }, 404);
      return json({
        status: "ready",
        url,
        cached: true,
        provider: TTS_PROVIDER,
        model: TTS_MODEL,
        voice: wantedVoice.voiceId,
        target_language: target,
      });
    }

    // 5. NEW generation needs the generation switch (and playback to serve).
    if (!flags.generation) {
      return json({
        status: "service_disabled",
        service: "voice_tts_generation",
      });
    }
    if (!flags.playback) {
      return json({
        status: "service_disabled",
        service: "voice_tts_playback",
      });
    }
    if (!elevenKey) {
      return json({ error: "ElevenLabs not configured" }, 503);
    }

    // 6. Need a transcript, and its translation in the target language.
    //    Same-language messages need no translated audio.
    const transcript = await getTranscript(messageId);
    if (!transcript) {
      return json({ status: "needs_transcript" });
    }
    if (!transcript.lang) {
      return json({ status: "skipped", reason: "language_uncertain" });
    }
    if (transcript.lang === target) {
      return json({ status: "skipped", reason: "same_language" });
    }
    let speakText = await getTranslation(messageId, target);
    if (!speakText) {
      return json({ status: "needs_translation" });
    }
    // Arabic: speak natural Saudi/Gulf dialect, never formal Fusha. Built
    // from the original transcript. If conversion fails, fall back to the
    // stored translation so the user still gets (male) audio.
    if (target === "ar") {
      const gulf = await toGulfSpokenArabic(transcript.text, transcript.lang);
      if (gulf) speakText = gulf;
    }
    if (speakText.length > MAX_TTS_CHARS) {
      speakText = speakText.slice(0, MAX_TTS_CHARS);
    }

    // 7. Atomic claim (only one request generates; the rest see pending).
    //    Voice-aware: also takes over a 'ready' row with a different voice.
    const claim = await rpc<Row[]>("chat_tts_claim_voice", {
      p_message_id: messageId,
      p_target_language: target,
      p_voice_name: wantedKey,
      p_allow_retry: retry,
      p_stale_seconds: STALE_SECONDS,
      p_max_attempts: MAX_ATTEMPTS,
    });
    if (!Array.isArray(claim) || claim.length === 0) {
      return json({ error: "Storage unavailable" }, 503);
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
      if (
        st === "ready" && typeof c.audio_path === "string" && c.audio_path &&
        c.voice_name === wantedKey
      ) {
        const url = await signTts(String(c.audio_path));
        if (url) {
          return json({
            status: "ready",
            url,
            cached: true,
            provider: TTS_PROVIDER,
            model: TTS_MODEL,
            voice: wantedVoice.voiceId,
            target_language: target,
          });
        }
      }
      return json({ status: "pending" });
    }
    claimToken = c.claim_token;

    const save = async (
      status: "ready" | "failed",
      path: string | null,
      voiceName: string | null,
      chars: number | null,
      errorCode: string | null,
    ): Promise<boolean> => {
      const ok = await rpc<boolean>("chat_tts_save", {
        p_message_id: messageId,
        p_target_language: target,
        p_claim_token: claimToken,
        p_status: status,
        p_audio_path: path,
        p_voice_name: voiceName,
        p_gender_class: null,
        p_char_count: chars,
        p_error_code: errorCode,
      });
      if (ok === true) claimResolved = true;
      return ok === true;
    };
    const fail = async (code: string, retryable = true) => {
      await save("failed", null, null, null, code);
      return json({ status: "failed", error_code: code, retryable });
    };

    // 8. ElevenLabs synthesis with the fixed Voice ID for the target language.
    const voice = wantedVoice;
    const synth = await synthesize(speakText, voice, elevenKey);
    await logUsage({
      success: synth.bytes !== null,
      model: `${TTS_PROVIDER}:${TTS_MODEL}`,
      errorCode: synth.bytes ? null : `tts_${synth.status}`,
    });
    if (!synth.bytes) {
      const transient = synth.status === 0 || synth.status === 429 ||
        synth.status >= 500;
      return await fail(`tts_${synth.status}`, transient);
    }

    // 9. Upload to the PRIVATE bucket and persist (never "ready" on failure).
    //    The path carries provider + model + Voice ID (+ Arabic spoken
    //    version), so audio from a different provider/model/voice never
    //    overwrites or is confused with this file. Old objects (including
    //    legacy Azure audio) are left untouched.
    const path =
      `${msg.conversation_id}/${messageId}/${target}.${voicePathKey(target)}.mp3`;
    const uploaded = await uploadTts(path, synth.bytes);
    if (!uploaded) return await fail("upload_failed");

    const saved = await save("ready", path, wantedKey, speakText.length, null);
    if (!saved) {
      return json(
        { status: "failed", error_code: "save_failed", retryable: true },
        503,
      );
    }

    const url = await signTts(path);
    if (!url) return json({ error: "Audio unavailable" }, 404);
    return json({
      status: "ready",
      url,
      cached: false,
      provider: TTS_PROVIDER,
      model: TTS_MODEL,
      voice: voice.voiceId,
      target_language: target,
    });
  } catch (e) {
    console.error(
      "chat-tts-message error:",
      e instanceof Error ? e.message : "unknown",
    );
    return json(
      { status: "failed", error_code: "internal_error", retryable: true },
      500,
    );
  } finally {
    if (claimToken && !claimResolved) {
      try {
        await rpc<boolean>("chat_tts_save", {
          p_message_id: messageId,
          p_target_language: target,
          p_claim_token: claimToken,
          p_status: "failed",
          p_audio_path: null,
          p_voice_name: null,
          p_gender_class: null,
          p_char_count: null,
          p_error_code: "interrupted",
        });
      } catch (_) {
        // Stale takeover recovers it.
      }
    }
  }
});

// ======================================================
// TourOps Smart Chat
// Edge Function: chat-translate-message  (TEST PHASE, v2: + Azerbaijani)
//
// Called by the Flutter app with ONLY { message_id, target_language }.
// All secrets stay server-side:
//   * SUPABASE_SERVICE_ROLE_KEY  (reads message, writes chat_translations)
//   * CHAT_INTERNAL_TOKEN        (authenticates to chat-translate)
//   * OPENAI_API_KEY             (only for ambiguous Latin-script detection)
//
// Flow:
//   1. Validate request + supported language (ar, en, ru, ka, az).
//   2. Load the stored message (original text is never modified).
//   3. Text messages only.
//   4. Reuse a cached chat_translations row (message_id, target_language)
//      BEFORE any detection / OpenAI call.
//   5. Detect the real language:
//        - Arabic / Georgian / Cyrillic(Russian): Unicode script (free).
//        - Latin script: free heuristic (Azerbaijani letters / English
//          function words); only if still ambiguous, ONE tiny OpenAI
//          classification call.
//   6. Same language as recipient -> no translation row, return original.
//   7. Otherwise call chat-translate server-side, store, return.
// ======================================================

const LANGUAGES = ["ar", "en", "ru", "ka", "az"];

const json = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
    },
  });

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const restHeaders = {
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  "Content-Type": "application/json",
};

// AI service switch (public.chat_ai_settings), read per request so an
// administrator change takes effect immediately, without redeploying.
// Fails OPEN if the row cannot be read (chat must keep working).
async function isTextTranslationEnabled(): Promise<boolean> {
  try {
    const res = await fetch(
      `${SUPABASE_URL}/rest/v1/chat_ai_settings` +
        `?id=eq.1&select=text_translation_enabled&limit=1`,
      { headers: restHeaders },
    );
    if (!res.ok) {
      console.error("ai settings read failed:", res.status);
      return true;
    }
    const rows = await res.json();
    if (!Array.isArray(rows) || rows.length === 0) return true;
    return rows[0].text_translation_enabled !== false;
  } catch (_) {
    console.error("ai settings read error");
    return true;
  }
}

// Script-based detection. Returns "ar" | "ka" | "ru" | "latin" | null.
// Latin is NOT assumed to be English any more (Azerbaijani is Latin too).
function detectScript(text: string): "ar" | "ka" | "ru" | "latin" | null {
  let ar = 0, ka = 0, ru = 0, la = 0;
  for (const ch of text) {
    const c = ch.codePointAt(0)!;
    if ((c >= 0x0600 && c <= 0x06ff) || (c >= 0x0750 && c <= 0x077f) ||
        (c >= 0xfb50 && c <= 0xfdff) || (c >= 0xfe70 && c <= 0xfeff)) ar++;
    else if ((c >= 0x10a0 && c <= 0x10ff) || (c >= 0x1c90 && c <= 0x1cbf)) ka++;
    else if (c >= 0x0400 && c <= 0x04ff) ru++;
    else if ((c >= 0x41 && c <= 0x5a) || (c >= 0x61 && c <= 0x7a) ||
             (c >= 0xc0 && c <= 0x24f)) la++; // Latin + Latin Extended
  }
  const max = Math.max(ar, ka, ru, la);
  if (max === 0) return null; // digits / symbols only
  if (max === ar) return "ar";
  if (max === ka) return "ka";
  if (max === ru) return "ru";
  return "latin";
}

const EN_WORDS = new Set([
  "the", "and", "is", "are", "was", "were", "you", "your", "i", "we", "me",
  "my", "to", "of", "in", "on", "at", "for", "with", "please", "hello", "hi",
  "thanks", "thank", "will", "be", "am", "it", "this", "that", "here",
  "there", "where", "when", "what", "how", "ok", "okay", "yes", "no", "not",
  "have", "has", "can", "arrived", "waiting", "outside", "minutes", "pickup",
  "driver", "hotel", "airport", "ready", "location", "share", "on", "way",
]);

const AZ_WORDS = new Set([
  "salam", "sağ", "olun", "təşəkkür", "təşəkkürlər", "var", "yox", "bəli",
  "xahiş", "edirəm", "mən", "sən", "biz", "siz", "necə", "harada", "nə",
  "zaman", "gəlirəm", "gəldim", "gözləyirəm", "otel", "hava", "limanı",
  "dəqiqə", "dəqiqəyə", "yoldayam", "çatdım", "hazıram", "salamlar",
  "sabah", "bu", "və", "ilə", "üçün", "da", "də", "bir", "çox", "yaxşı",
  "buyurun", "zəhmət", "olmasa", "ünvan", "sürücü", "müştəri",
]);

// Letters that exist in Azerbaijani Latin but not in English text.
const AZ_LETTERS = /[əƏğĞıİöÖüÜçÇşŞ]/;

type LatinGuess = "en" | "az" | "unknown";

function guessLatin(text: string): LatinGuess {
  const words = text.toLowerCase().match(/[\p{L}]+/gu) ?? [];
  if (words.length === 0) return "unknown";

  const hasAzLetter = AZ_LETTERS.test(text);
  let az = 0, en = 0;
  for (const w of words) {
    if (AZ_WORDS.has(w)) az++;
    if (EN_WORDS.has(w)) en++;
  }
  // 'ə' (and the Azerbaijani-only dotless ı) never appear in English.
  if (/[əƏ]/.test(text)) return "az";
  if (hasAzLetter && az > en) return "az";
  if (az > 0 && az > en) return "az";
  if (en > 0 && en >= az && !hasAzLetter) return "en";
  if (en > az) return "en";
  return "unknown";
}

// One tiny classification call, only for genuinely ambiguous Latin text.
async function classifyLatinWithOpenAI(text: string): Promise<"en" | "az" | null> {
  const key = Deno.env.get("OPENAI_API_KEY");
  if (!key) return null;
  try {
    const res = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${key}`,
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        temperature: 0,
        max_tokens: 3,
        messages: [
          {
            role: "system",
            content:
              "Classify the language of the user's text. Answer with exactly " +
              "one code: en (English) or az (Azerbaijani). No other output.",
          },
          { role: "user", content: text.slice(0, 400) },
        ],
      }),
    });
    if (!res.ok) return null;
    const data = await res.json();
    const out = String(data?.choices?.[0]?.message?.content ?? "")
      .trim()
      .toLowerCase();
    if (out.startsWith("az")) return "az";
    if (out.startsWith("en")) return "en";
    return null;
  } catch {
    return null;
  }
}

async function detectLanguage(
  text: string,
  storedHint: string | null,
): Promise<string> {
  const script = detectScript(text);
  if (script === "ar" || script === "ka" || script === "ru") return script;
  if (script === null) {
    return storedHint && LANGUAGES.includes(storedHint) ? storedHint : "en";
  }
  // Latin script: English or Azerbaijani.
  const guess = guessLatin(text);
  if (guess !== "unknown") return guess;
  const ai = await classifyLatinWithOpenAI(text);
  if (ai) return ai;
  // Fall back to the sender's stored hint only if it is a Latin language.
  return storedHint === "az" ? "az" : "en";
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return json({ ok: true });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const internalToken = Deno.env.get("CHAT_INTERNAL_TOKEN");
  if (!SUPABASE_URL || !SERVICE_KEY || !internalToken) {
    return json({ error: "Function not configured" }, 503);
  }

  try {
    const body = await req.json();
    const messageId = body?.message_id;
    const target = body?.target_language;

    if (
      typeof messageId !== "string" ||
      !/^[0-9a-fA-F-]{36}$/.test(messageId) ||
      typeof target !== "string" ||
      !LANGUAGES.includes(target)
    ) {
      return json({ error: "Invalid request" }, 400);
    }

    // 1. Load the stored message.
    const msgRes = await fetch(
      `${SUPABASE_URL}/rest/v1/chat_messages?id=eq.${messageId}` +
        `&select=id,message_type,original_text,original_language`,
      { headers: restHeaders },
    );
    if (!msgRes.ok) return json({ error: "Message lookup failed" }, 502);
    const rows = await msgRes.json();
    if (!Array.isArray(rows) || rows.length === 0) {
      return json({ error: "Message not found" }, 404);
    }
    const msg = rows[0];

    // 2. Text only (voice translation is a separate phase).
    if (msg.message_type !== "text" || !(msg.original_text ?? "").trim()) {
      return json({ status: "skipped", reason: "not_text" });
    }
    const text: string = msg.original_text;
    const hint: string | null = msg.original_language ?? null;

    // 2b. Server-side AI switch. When OFF no NEW translation is generated and
    //     no OpenAI call is made. The original message is untouched and chat
    //     keeps working. (Cached translations are not served either, so the
    //     behaviour is uniform and clearly "disabled".)
    if (!(await isTextTranslationEnabled())) {
      return json({
        status: "service_disabled",
        service: "text_translation",
      });
    }

    // 3. Reuse a stored translation FIRST: no detection, no OpenAI.
    const cacheRes = await fetch(
      `${SUPABASE_URL}/rest/v1/chat_translations?message_id=eq.${messageId}` +
        `&target_language=eq.${target}&select=translated_text&limit=1`,
      { headers: restHeaders },
    );
    if (cacheRes.ok) {
      const cached = await cacheRes.json();
      if (Array.isArray(cached) && cached.length > 0 &&
          (cached[0].translated_text ?? "").length > 0) {
        // Source language is free to compute for non-Latin scripts and uses
        // only the free heuristic for Latin (no OpenAI on the cached path).
        const script = detectScript(text);
        const source = script === "latin"
          ? (guessLatin(text) === "az" ? "az" : "en")
          : (script ?? hint ?? "en");
        return json({
          status: "cached",
          translated_text: cached[0].translated_text,
          source_language: source,
          target_language: target,
        });
      }
    }

    // 4. Detect the real language (not the sender's interface language).
    const source = await detectLanguage(text, hint);

    // 5. Already in the recipient's language -> show original.
    if (source === target) {
      return json({
        status: "same_language",
        source_language: source,
        target_language: target,
      });
    }

    // 6. Translate server-side through the existing protected function.
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
        service: "text_translation",
      }),
    });
    if (!trRes.ok) {
      console.error("chat-translate failed:", trRes.status);
      return json({ error: "Translation service unavailable" }, 502);
    }
    const tr = await trRes.json();
    if (tr?.status === "service_disabled") {
      return json({
        status: "service_disabled",
        service: "text_translation",
      });
    }
    const translated: string = (tr?.translated_text ?? "").trim();
    if (!translated) return json({ error: "Empty translation" }, 502);

    // 7. Store (idempotent on message_id + target_language).
    const saveRes = await fetch(
      `${SUPABASE_URL}/rest/v1/chat_translations` +
        `?on_conflict=message_id,target_language`,
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
    if (!saveRes.ok) {
      console.error("store translation failed:", saveRes.status);
      // Still return the translation so the chat can show it now.
    }

    return json({
      status: "translated",
      translated_text: translated,
      source_language: source,
      target_language: target,
    });
  } catch (e) {
    console.error(
      "chat-translate-message error:",
      e instanceof Error ? e.message : "unknown",
    );
    return json({ error: "Invalid request or translation failed" }, 400);
  }
});

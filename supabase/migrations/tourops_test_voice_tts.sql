-- =====================================================================
-- TourOps Smart Chat - PHASE 3.2: AI TRANSLATED VOICE (Azure AI Speech)
-- File: supabase/migrations/tourops_test_voice_tts.sql
--
-- STATUS: APPLIED (tables, functions, usage-log constraint and private
-- 'chat-tts' bucket verified present in the project). Do not re-run
-- unless the file changes; it is idempotent either way.
-- The chat-tts-message Edge Function must be deployed AFTER this migration.
--
-- SIMPLIFIED DESIGN: one fixed Azure voice per language (no male/female
-- classification). The legacy table chat_voice_tts_meta and the nullable
-- gender_class column are kept ONLY so the already-applied schema stays
-- unchanged (no DROP, no data loss). The Edge Function no longer reads or
-- writes them.
--
-- Idempotent. Adds:
--   1. public.chat_voice_tts_meta : LEGACY, unused
--   2. public.chat_voice_tts      : one generated audio per (message, language)
--   3. chat_tts_claim() / chat_tts_save() : ATOMIC claim + compare-and-set
--   4. chat_ai_usage_log.service_type : adds 'voice_tts'
--   5. private Storage bucket 'chat-tts' (no public access, no anon policy)
--
-- chat_messages, chat_translations, chat_voice_transcriptions, read
-- receipts, presence, driver changes and the chat-voice bucket are NOT
-- modified. The existing switches voice_tts_generation_enabled and
-- voice_tts_playback_enabled are reused (both default FALSE and this
-- migration does NOT change them).
--
-- SECURITY
--   * RLS enabled and NO policy for anon / authenticated (default deny).
--   * All privileges revoked from anon / authenticated.
--   * Only service_role (Edge Function) can read / write / execute.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. LEGACY (unused): classification cache from the cancelled design
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.chat_voice_tts_meta (
  message_id     uuid PRIMARY KEY
                   REFERENCES public.chat_messages(id) ON DELETE CASCADE,
  gender_class   text NOT NULL,
  f0_median_hz   numeric(7,2),
  voiced_ratio   numeric(5,4),
  confidence     numeric(5,4),
  method         text NOT NULL DEFAULT 'f0_autocorr_v1',
  created_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chat_voice_tts_meta_gender_chk
    CHECK (gender_class IN ('male', 'female', 'uncertain'))
);

-- ---------------------------------------------------------------------
-- 2. Generated translated audio (one per message + target language)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.chat_voice_tts (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id       uuid NOT NULL
                     REFERENCES public.chat_messages(id) ON DELETE CASCADE,
  target_language  text NOT NULL,
  voice_name       text,
  gender_class     text,
  status           text NOT NULL DEFAULT 'pending',
  audio_path       text,
  char_count       integer,
  attempts         integer NOT NULL DEFAULT 0,
  claim_token      uuid,
  error_code       text,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chat_voice_tts_status_chk
    CHECK (status IN ('pending', 'ready', 'failed')),
  CONSTRAINT chat_voice_tts_lang_chk
    CHECK (target_language IN ('ar', 'en', 'ru', 'ka', 'az')),
  CONSTRAINT chat_voice_tts_unique UNIQUE (message_id, target_language)
);

CREATE INDEX IF NOT EXISTS chat_voice_tts_pending_idx
  ON public.chat_voice_tts (updated_at)
  WHERE status = 'pending';

-- ---------------------------------------------------------------------
-- 3a. ATOMIC claim. Returns one row {claimed, claim_token, status,
--     attempts, audio_path, voice_name}.
--       - no row                        -> inserts 'pending' (claimed)
--       - failed (explicit retry)       -> takes over (attempts < max)
--       - stale 'pending' (worker died) -> takes over (attempts < max)
--       - ready / fresh pending         -> not claimed
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.chat_tts_claim(
  p_message_id      uuid,
  p_target_language text,
  p_allow_retry     boolean DEFAULT false,
  p_stale_seconds   integer DEFAULT 120,
  p_max_attempts    integer DEFAULT 3
)
RETURNS TABLE (
  claimed     boolean,
  claim_token uuid,
  status      text,
  attempts    integer,
  audio_path  text,
  voice_name  text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_token uuid := gen_random_uuid();
  v_row   public.chat_voice_tts%ROWTYPE;
BEGIN
  -- 1) First writer wins (no row yet).
  INSERT INTO public.chat_voice_tts AS t
    (message_id, target_language, status, attempts, claim_token)
  VALUES
    (p_message_id, p_target_language, 'pending', 1, v_token)
  ON CONFLICT (message_id, target_language) DO NOTHING
  RETURNING * INTO v_row;

  IF FOUND THEN
    RETURN QUERY SELECT true, v_token, v_row.status, v_row.attempts,
                        v_row.audio_path, v_row.voice_name;
    RETURN;
  END IF;

  -- 2) Take over a failed row (explicit retry) or an abandoned 'pending'
  --    row in ONE atomic UPDATE. Concurrent callers: only one matches.
  UPDATE public.chat_voice_tts t
     SET status      = 'pending',
         error_code  = NULL,
         attempts    = t.attempts + 1,
         claim_token = v_token,
         updated_at  = now()
   WHERE t.message_id      = p_message_id
     AND t.target_language = p_target_language
     AND t.attempts < p_max_attempts
     AND (
           (t.status = 'failed' AND p_allow_retry)
        OR (t.status = 'pending'
            AND t.updated_at < now() - make_interval(secs => p_stale_seconds))
         )
  RETURNING * INTO v_row;

  IF FOUND THEN
    RETURN QUERY SELECT true, v_token, v_row.status, v_row.attempts,
                        v_row.audio_path, v_row.voice_name;
    RETURN;
  END IF;

  -- 3) Not claimed: report the current state.
  SELECT * INTO v_row
    FROM public.chat_voice_tts t
   WHERE t.message_id      = p_message_id
     AND t.target_language = p_target_language;
  RETURN QUERY SELECT false, NULL::uuid, v_row.status, v_row.attempts,
                      v_row.audio_path, v_row.voice_name;
END;
$$;

-- ---------------------------------------------------------------------
-- 3b. Compare-and-set result write. Returns true only if the caller still
--     owns the claim. p_status: 'ready' | 'failed'.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.chat_tts_save(
  p_message_id      uuid,
  p_target_language text,
  p_claim_token     uuid,
  p_status          text,
  p_audio_path      text,
  p_voice_name      text,
  p_gender_class    text,
  p_char_count      integer,
  p_error_code      text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_n integer;
BEGIN
  IF p_status NOT IN ('ready', 'failed') THEN
    RETURN false;
  END IF;

  UPDATE public.chat_voice_tts t
     SET status       = p_status,
         audio_path   = CASE WHEN p_status = 'ready' THEN p_audio_path ELSE t.audio_path END,
         voice_name   = CASE WHEN p_status = 'ready' THEN p_voice_name ELSE t.voice_name END,
         gender_class = CASE WHEN p_status = 'ready' THEN p_gender_class ELSE t.gender_class END,
         char_count   = CASE WHEN p_status = 'ready' THEN p_char_count ELSE t.char_count END,
         error_code   = CASE WHEN p_status = 'failed' THEN p_error_code ELSE NULL END,
         updated_at   = now()
   WHERE t.message_id      = p_message_id
     AND t.target_language = p_target_language
     AND t.claim_token     = p_claim_token
     AND t.status          = 'pending';

  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n = 1;
END;
$$;

-- ---------------------------------------------------------------------
-- 4. Usage log: allow the new service type 'voice_tts'
-- ---------------------------------------------------------------------
ALTER TABLE public.chat_ai_usage_log
  DROP CONSTRAINT IF EXISTS chat_ai_usage_log_service_chk;
ALTER TABLE public.chat_ai_usage_log
  ADD CONSTRAINT chat_ai_usage_log_service_chk CHECK (
    service_type IN (
      'text_translation',
      'voice_transcription',
      'voice_text_translation',
      'voice_tts'
    )
  );

-- ---------------------------------------------------------------------
-- 5. RLS + privileges: server-side roles only
-- ---------------------------------------------------------------------
ALTER TABLE public.chat_voice_tts_meta ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_voice_tts      ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.chat_voice_tts_meta FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.chat_voice_tts      FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.chat_voice_tts_meta TO service_role;
GRANT SELECT, INSERT, UPDATE ON public.chat_voice_tts      TO service_role;

REVOKE ALL ON FUNCTION public.chat_tts_claim(uuid, text, boolean, integer, integer)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.chat_tts_save(uuid, text, uuid, text, text, text, text, integer, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.chat_tts_claim(uuid, text, boolean, integer, integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.chat_tts_save(uuid, text, uuid, text, text, text, text, integer, text) TO service_role;

-- ---------------------------------------------------------------------
-- 6. Private Storage bucket 'chat-tts'
--    public = false, no storage.objects policy for anon / authenticated.
--    Only the service role (Edge Function) writes and signs.
-- ---------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('chat-tts', 'chat-tts', false, 5242880, ARRAY['audio/mpeg'])
ON CONFLICT (id) DO UPDATE
  SET public = false,
      file_size_limit = 5242880,
      allowed_mime_types = ARRAY['audio/mpeg'];

NOTIFY pgrst, 'reload schema';

-- ---------------------------------------------------------------------
-- VERIFY (run manually)
--   SELECT relname, relrowsecurity FROM pg_class
--     WHERE relname IN ('chat_voice_tts','chat_voice_tts_meta');
--   SELECT * FROM pg_policies
--     WHERE tablename IN ('chat_voice_tts','chat_voice_tts_meta');   -- 0 rows
--   SELECT id, public FROM storage.buckets WHERE id = 'chat-tts';    -- false
--   SELECT proname FROM pg_proc WHERE proname LIKE 'chat_tts_%';
--
-- SWITCHES (NOT changed by this migration; enable only after deployment)
--   UPDATE public.chat_ai_settings
--      SET voice_tts_generation_enabled = true,
--          voice_tts_playback_enabled   = true
--    WHERE id = 1;
-- ---------------------------------------------------------------------

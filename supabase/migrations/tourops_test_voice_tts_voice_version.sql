-- =====================================================================
-- TourOps Smart Chat - PHASE 3.2: VOICE-AWARE TTS CACHE (TEST)
-- File: supabase/migrations/tourops_test_voice_tts_voice_version.sql
--
-- WHY: the TTS cache is keyed on (message_id, target_language). Audio that
-- was generated earlier with a FEMALE voice stayed 'ready' and was served
-- forever, even after the Edge Function voice mapping changed to male.
--
-- WHAT: adds ONE function, chat_tts_claim_voice(), that behaves like
-- chat_tts_claim() but ALSO takes over a 'ready' row whose stored
-- voice_name differs from the voice the function now wants (p_voice_name).
-- The row is flipped back to 'pending' so it is regenerated ONCE with the
-- correct voice and then cached again under the new voice.
--
-- NOTHING is deleted: no rows, no Storage objects, no original recordings,
-- no messages, no translations. Old female audio files stay in the private
-- 'chat-tts' bucket (the new audio is written to a NEW, voice-versioned
-- path), they are just no longer referenced.
--
-- Idempotent. Service role only. Run in the TEST project only.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.chat_tts_claim_voice(
  p_message_id      uuid,
  p_target_language text,
  p_voice_name      text,
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

  -- 2) Stale voice: a 'ready' row generated with a DIFFERENT voice is
  --    regenerated once. Attempts are reset because this is not a failure.
  UPDATE public.chat_voice_tts t
     SET status      = 'pending',
         error_code  = NULL,
         attempts    = 1,
         claim_token = v_token,
         updated_at  = now()
   WHERE t.message_id      = p_message_id
     AND t.target_language = p_target_language
     AND t.status          = 'ready'
     AND t.voice_name IS DISTINCT FROM p_voice_name
  RETURNING * INTO v_row;

  IF FOUND THEN
    RETURN QUERY SELECT true, v_token, v_row.status, v_row.attempts,
                        v_row.audio_path, v_row.voice_name;
    RETURN;
  END IF;

  -- 3) Failed (explicit retry) or abandoned 'pending' row.
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

  -- 4) Not claimed: report the current state.
  SELECT * INTO v_row
    FROM public.chat_voice_tts t
   WHERE t.message_id      = p_message_id
     AND t.target_language = p_target_language;
  RETURN QUERY SELECT false, NULL::uuid, v_row.status, v_row.attempts,
                      v_row.audio_path, v_row.voice_name;
END;
$$;

REVOKE ALL ON FUNCTION public.chat_tts_claim_voice(uuid, text, text, boolean, integer, integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.chat_tts_claim_voice(uuid, text, text, boolean, integer, integer)
  TO service_role;

NOTIFY pgrst, 'reload schema';

-- ---------------------------------------------------------------------
-- VERIFY (run manually, read-only)
--   SELECT proname FROM pg_proc WHERE proname = 'chat_tts_claim_voice';
--   -- Rows that will be regenerated on next "Listen Translated":
--   SELECT message_id, target_language, voice_name, status
--     FROM public.chat_voice_tts
--    WHERE status = 'ready'
--      AND voice_name NOT IN ('ar-SA-HamedNeural','en-US-GuyNeural',
--          'ru-RU-DmitryNeural','az-AZ-BabekNeural','ka-GE-GiorgiNeural');
-- ---------------------------------------------------------------------

-- =====================================================================
-- TourOps Smart Chat - PHASE 3.1 FIXES: transcription reliability
-- File: supabase/migrations/tourops_test_voice_transcriptions_v2.sql
--
-- STATUS: NOT APPLIED. Review, then run manually in the SQL Editor.
-- Apply BEFORE deploying the updated chat-transcribe-message function.
--
-- Idempotent. Touches ONLY public.chat_voice_transcriptions and adds two
-- service-role-only functions. chat_messages, chat_translations, read
-- receipts, presence and storage are NOT modified.
--
-- What it adds
--   * attempts        : bounded number of OpenAI attempts per message.
--   * claim_token     : identifies the request that owns the 'pending' claim,
--                       so a slow/dead worker can never overwrite a newer one.
--   * chat_voice_claim_transcription(): ATOMIC claim in one statement.
--       - no row                      -> inserts 'pending' (claimed)
--       - failed + explicit retry     -> takes over (attempts < max)
--       - stale 'pending' (worker died)-> takes over (attempts < max)
--       - ready / fresh pending       -> not claimed
--   * chat_voice_save_transcription(): writes the result only if the caller
--     still holds the claim_token (compare-and-set).
--   * chat_voice_release_stale(): optional housekeeping, flips abandoned
--     'pending' rows to 'failed' so nothing stays pending forever.
-- =====================================================================

ALTER TABLE public.chat_voice_transcriptions
  ADD COLUMN IF NOT EXISTS attempts    integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS claim_token uuid;

CREATE INDEX IF NOT EXISTS chat_voice_transcriptions_pending_idx
  ON public.chat_voice_transcriptions (updated_at)
  WHERE status = 'pending';

-- ---------------------------------------------------------------------
-- Atomic claim. Returns one row {claimed, claim_token, status, attempts}.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.chat_voice_claim_transcription(
  p_message_id      uuid,
  p_duration        integer,
  p_model           text,
  p_allow_retry     boolean DEFAULT false,
  p_stale_seconds   integer DEFAULT 120,
  p_max_attempts    integer DEFAULT 3
)
RETURNS TABLE (
  claimed     boolean,
  claim_token uuid,
  status      text,
  attempts    integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_token uuid := gen_random_uuid();
  v_row   public.chat_voice_transcriptions%ROWTYPE;
BEGIN
  -- 1) First writer wins (no row yet).
  INSERT INTO public.chat_voice_transcriptions AS t
    (message_id, status, model, audio_duration_seconds, attempts, claim_token)
  VALUES
    (p_message_id, 'pending', p_model, p_duration, 1, v_token)
  ON CONFLICT (message_id) DO NOTHING
  RETURNING * INTO v_row;

  IF FOUND THEN
    RETURN QUERY SELECT true, v_token, v_row.status, v_row.attempts;
    RETURN;
  END IF;

  -- 2) Take over a failed row (explicit retry) or an abandoned 'pending'
  --    row, in ONE atomic UPDATE. Concurrent callers: only one matches.
  UPDATE public.chat_voice_transcriptions t
     SET status      = 'pending',
         error_code  = NULL,
         attempts    = t.attempts + 1,
         claim_token = v_token,
         model       = p_model,
         updated_at  = now()
   WHERE t.message_id = p_message_id
     AND t.attempts < p_max_attempts
     AND (
           (t.status = 'failed' AND p_allow_retry)
        OR (t.status = 'pending'
            AND t.updated_at < now() - make_interval(secs => p_stale_seconds))
         )
  RETURNING * INTO v_row;

  IF FOUND THEN
    RETURN QUERY SELECT true, v_token, v_row.status, v_row.attempts;
    RETURN;
  END IF;

  -- 3) Not claimed: report the current state.
  SELECT * INTO v_row
    FROM public.chat_voice_transcriptions t
   WHERE t.message_id = p_message_id;
  RETURN QUERY SELECT false, NULL::uuid, v_row.status, v_row.attempts;
END;
$$;

-- ---------------------------------------------------------------------
-- Compare-and-set result write. Returns true only if the caller still owns
-- the claim. p_status: 'ready' | 'failed'.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.chat_voice_save_transcription(
  p_message_id  uuid,
  p_claim_token uuid,
  p_status      text,
  p_text        text,
  p_language    text,
  p_error_code  text
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

  UPDATE public.chat_voice_transcriptions t
     SET status            = p_status,
         transcript_text   = CASE WHEN p_status = 'ready' THEN p_text ELSE t.transcript_text END,
         detected_language = CASE WHEN p_status = 'ready' THEN p_language ELSE t.detected_language END,
         error_code        = CASE WHEN p_status = 'failed' THEN p_error_code ELSE NULL END,
         updated_at        = now()
   WHERE t.message_id  = p_message_id
     AND t.claim_token = p_claim_token
     AND t.status      = 'pending';

  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n = 1;
END;
$$;

-- ---------------------------------------------------------------------
-- Housekeeping: abandoned 'pending' rows become 'failed' (retryable).
-- Safe to call from a cron / manually.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.chat_voice_release_stale(
  p_stale_seconds integer DEFAULT 300
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_n integer;
BEGIN
  UPDATE public.chat_voice_transcriptions t
     SET status = 'failed', error_code = 'stale_pending', updated_at = now()
   WHERE t.status = 'pending'
     AND t.updated_at < now() - make_interval(secs => p_stale_seconds);
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END;
$$;

-- ---------------------------------------------------------------------
-- Grants: service_role ONLY. anon / authenticated can never call these.
-- ---------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.chat_voice_claim_transcription(uuid, integer, text, boolean, integer, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.chat_voice_save_transcription(uuid, uuid, text, text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.chat_voice_release_stale(integer) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.chat_voice_claim_transcription(uuid, integer, text, boolean, integer, integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.chat_voice_save_transcription(uuid, uuid, text, text, text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.chat_voice_release_stale(integer) TO service_role;

-- Verification (run manually)
-- SELECT proname FROM pg_proc WHERE proname LIKE 'chat_voice_%';
-- SELECT message_id, status, attempts, error_code, updated_at
--   FROM public.chat_voice_transcriptions ORDER BY updated_at DESC LIMIT 10;

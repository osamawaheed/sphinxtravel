-- =====================================================================
-- TourOps Smart Chat - AI SERVICES CONTROL (TEST)
-- File: supabase/migrations/tourops_test_ai_settings.sql
--
-- STATUS: NOT APPLIED. Review, then run manually in the SQL Editor.
-- Idempotent. Adds two NEW tables only. chat_messages, chat_translations,
-- chat_voice_transcriptions, read receipts, presence, driver changes and
-- Storage are NOT modified.
--
-- 1. public.chat_ai_settings   : single-row feature switches (booleans).
-- 2. public.chat_ai_usage_log  : lightweight, metadata-only usage records.
--
-- SECURITY (TEST environment, not a production-grade claim)
--   * RLS is enabled on both tables and NO policy is created for anon or
--     authenticated, so the app (anon key) can neither read nor write them.
--   * All table privileges are revoked from anon / authenticated.
--   * Only service_role (Edge Functions) and the dashboard (SQL Editor /
--     Table Editor, which use the postgres role) can read and write.
--
-- No daily limits, quotas or automatic shutdowns exist anywhere here.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Settings (exactly one row, id = 1)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.chat_ai_settings (
  id                              integer PRIMARY KEY DEFAULT 1,
  text_translation_enabled        boolean NOT NULL DEFAULT true,
  voice_transcription_enabled     boolean NOT NULL DEFAULT true,
  voice_text_translation_enabled  boolean NOT NULL DEFAULT true,
  voice_tts_generation_enabled    boolean NOT NULL DEFAULT false,
  voice_tts_playback_enabled      boolean NOT NULL DEFAULT false,
  updated_at                      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chat_ai_settings_single_row CHECK (id = 1)
);

-- Seed the single row (does not overwrite an existing configuration).
INSERT INTO public.chat_ai_settings (
  id,
  text_translation_enabled,
  voice_transcription_enabled,
  voice_text_translation_enabled,
  voice_tts_generation_enabled,
  voice_tts_playback_enabled
)
VALUES (1, true, true, true, false, false)
ON CONFLICT (id) DO NOTHING;

-- Keep updated_at fresh when the administrator edits a flag.
CREATE OR REPLACE FUNCTION public.chat_ai_settings_touch()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $func$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$func$;

DROP TRIGGER IF EXISTS chat_ai_settings_touch_trg ON public.chat_ai_settings;
CREATE TRIGGER chat_ai_settings_touch_trg
  BEFORE UPDATE ON public.chat_ai_settings
  FOR EACH ROW EXECUTE FUNCTION public.chat_ai_settings_touch();

-- ---------------------------------------------------------------------
-- 2. Usage log (metadata only: NO message text, transcripts, URLs, keys)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.chat_ai_usage_log (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  service_type    text NOT NULL,
  success         boolean NOT NULL,
  model           text,
  -- Provider-reported metrics, only when available (otherwise NULL).
  input_tokens    integer,
  output_tokens   integer,
  audio_seconds   numeric(10,2),
  -- NULL unless reliable pricing + usage are both known. Never invented.
  estimated_cost_usd numeric(12,6),
  -- Short machine code such as 'stt_429' or 'service_disabled'. Never text.
  error_code      text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chat_ai_usage_log_service_chk CHECK (
    service_type IN (
      'text_translation',
      'voice_transcription',
      'voice_text_translation'
    )
  )
);

CREATE INDEX IF NOT EXISTS chat_ai_usage_log_created_idx
  ON public.chat_ai_usage_log (created_at DESC);
CREATE INDEX IF NOT EXISTS chat_ai_usage_log_service_idx
  ON public.chat_ai_usage_log (service_type, created_at DESC);

-- ---------------------------------------------------------------------
-- 3. RLS + privileges: locked to server-side roles only
-- ---------------------------------------------------------------------
ALTER TABLE public.chat_ai_settings  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_ai_usage_log ENABLE ROW LEVEL SECURITY;

-- Intentionally NO policies for anon / authenticated (default deny).
-- Remove any policy a previous attempt may have left behind.
DROP POLICY IF EXISTS "chat_ai_settings_anon_read"  ON public.chat_ai_settings;
DROP POLICY IF EXISTS "chat_ai_settings_app_read"   ON public.chat_ai_settings;
DROP POLICY IF EXISTS "chat_ai_usage_log_app_write" ON public.chat_ai_usage_log;

REVOKE ALL ON public.chat_ai_settings  FROM PUBLIC;
REVOKE ALL ON public.chat_ai_settings  FROM anon;
REVOKE ALL ON public.chat_ai_settings  FROM authenticated;
REVOKE ALL ON public.chat_ai_usage_log FROM PUBLIC;
REVOKE ALL ON public.chat_ai_usage_log FROM anon;
REVOKE ALL ON public.chat_ai_usage_log FROM authenticated;

-- Edge Functions use the service role.
GRANT SELECT, UPDATE ON public.chat_ai_settings  TO service_role;
GRANT SELECT, INSERT ON public.chat_ai_usage_log TO service_role;

-- Make PostgREST pick up the new tables immediately.
NOTIFY pgrst, 'reload schema';

-- ---------------------------------------------------------------------
-- HOW TO CHANGE A SETTING (SQL Editor)
--   UPDATE public.chat_ai_settings SET text_translation_enabled = false WHERE id = 1;
--   UPDATE public.chat_ai_settings SET voice_transcription_enabled = false WHERE id = 1;
--   UPDATE public.chat_ai_settings SET voice_text_translation_enabled = false WHERE id = 1;
--   -- re-enable
--   UPDATE public.chat_ai_settings SET text_translation_enabled = true,
--     voice_transcription_enabled = true,
--     voice_text_translation_enabled = true WHERE id = 1;
-- Or edit the row in Table Editor -> chat_ai_settings.
--
-- VERIFY (should be: RLS on, zero policies, no anon/authenticated grants)
--   SELECT relname, relrowsecurity FROM pg_class
--     WHERE relname IN ('chat_ai_settings','chat_ai_usage_log');
--   SELECT * FROM pg_policies WHERE tablename IN ('chat_ai_settings','chat_ai_usage_log');
--   SELECT grantee, privilege_type FROM information_schema.role_table_grants
--     WHERE table_name IN ('chat_ai_settings','chat_ai_usage_log');
-- ---------------------------------------------------------------------

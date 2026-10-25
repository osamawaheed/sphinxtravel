-- =====================================================================
-- TourOps Smart Chat - PHASE 3.1 VOICE TRANSCRIPTIONS (TEST PHASE ONLY)
-- File: supabase/migrations/tourops_test_voice_transcriptions.sql
--
-- STATUS: NOT APPLIED. Review, then run manually in the SQL Editor.
--
-- Idempotent. Adds ONE table. Does not touch chat_messages,
-- chat_translations, read receipts, RLS of existing tables or the
-- chat-voice bucket. chat_messages.original_text is NOT modified for voice.
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.chat_voice_transcriptions (
  message_id        uuid PRIMARY KEY
                      REFERENCES public.chat_messages(id) ON DELETE CASCADE,
  status            text NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending', 'ready', 'failed')),
  transcript_text   text,
  detected_language text
                      CHECK (detected_language IS NULL OR detected_language
                             IN ('ar', 'en', 'ru', 'ka', 'az')),
  model             text,
  audio_duration_seconds integer,
  error_code        text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

-- Private by default: RLS on, NO policy for anon/authenticated.
-- Only Edge Functions (service role) read/write this table. The app gets
-- the transcript from the Edge Function response, never directly.
ALTER TABLE public.chat_voice_transcriptions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.chat_voice_transcriptions FROM anon, authenticated;

-- Verification (run manually)
-- SELECT message_id, status, detected_language, model
--   FROM public.chat_voice_transcriptions ORDER BY created_at DESC LIMIT 10;

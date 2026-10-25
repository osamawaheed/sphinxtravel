-- =====================================================================
-- TourOps Smart Chat - PHASE 3.1 : verify + repair voice transcription DB
-- File: supabase/migrations/tourops_test_voice_transcriptions_verify.sql
--
-- STATUS: NOT APPLIED. Run manually in the TEST project SQL Editor.
--
-- Purpose: "Storage unavailable" (HTTP 503) from chat-transcribe-message is
-- returned ONLY when one of these PostgREST calls fails:
--   A. GET  /rest/v1/chat_voice_transcriptions?message_id=eq.<id>&select=*
--   B. POST /rest/v1/rpc/chat_voice_claim_transcription
-- This script (1) reports what exists, (2) re-grants service_role access
-- (idempotent, service_role only), and (3) reloads the PostgREST schema
-- cache so newly created functions/columns are visible to the REST API.
--
-- It does NOT touch RLS, anon/authenticated privileges, chat_messages,
-- chat_translations, Storage or any policy. RLS stays enabled.
-- =====================================================================

-- 1) REPORT (read-only) -------------------------------------------------
-- Expect 3 rows: claim (6 args), save (6 args), release_stale (1 arg).
SELECT p.proname,
       pg_get_function_identity_arguments(p.oid) AS args,
       p.prosecdef                               AS security_definer
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public'
   AND p.proname IN ('chat_voice_claim_transcription',
                     'chat_voice_save_transcription',
                     'chat_voice_release_stale')
 ORDER BY p.proname;

-- Expect: message_id,status,transcript_text,detected_language,model,
--         audio_duration_seconds,error_code,created_at,updated_at,
--         attempts,claim_token
SELECT column_name, data_type
  FROM information_schema.columns
 WHERE table_schema = 'public' AND table_name = 'chat_voice_transcriptions'
 ORDER BY ordinal_position;

-- 2) service_role access (idempotent, server-side role only) ------------
GRANT USAGE ON SCHEMA public TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.chat_voice_transcriptions TO service_role;

DO $$
BEGIN
  IF to_regprocedure('public.chat_voice_claim_transcription(uuid,integer,text,boolean,integer,integer)') IS NOT NULL THEN
    GRANT EXECUTE ON FUNCTION public.chat_voice_claim_transcription(uuid, integer, text, boolean, integer, integer) TO service_role;
  END IF;
  IF to_regprocedure('public.chat_voice_save_transcription(uuid,uuid,text,text,text,text)') IS NOT NULL THEN
    GRANT EXECUTE ON FUNCTION public.chat_voice_save_transcription(uuid, uuid, text, text, text, text) TO service_role;
  END IF;
  IF to_regprocedure('public.chat_voice_release_stale(integer)') IS NOT NULL THEN
    GRANT EXECUTE ON FUNCTION public.chat_voice_release_stale(integer) TO service_role;
  END IF;
END $$;

-- 3) Make PostgREST pick up the functions/columns immediately -----------
NOTIFY pgrst, 'reload schema';

-- 4) Functional check (read/write safe: runs and rolls back) ------------
-- Replace the uuid with a real voice message id to test the claim path:
--   BEGIN;
--   SELECT * FROM public.chat_voice_claim_transcription(
--     '<voice-message-uuid>'::uuid, 5, 'gpt-4o-mini-transcribe', false, 120, 3);
--   ROLLBACK;

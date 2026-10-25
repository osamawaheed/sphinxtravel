-- =====================================================================
-- TourOps Smart Chat - PHASE 2 TRANSLATIONS (TEST PHASE ONLY)
-- File: supabase/migrations/tourops_test_translations.sql
--
-- STATUS: NOT APPLIED. Run manually in the Supabase SQL Editor.
--
-- Idempotent. Does not touch RLS policies, read receipts, or messages.
-- Only: (1) unique key so a message is translated once per language,
--       (2) Realtime publication so translations appear while chat is open.
-- =====================================================================

-- 1) One translation per (message, target language). Remove any exact
--    duplicates first so the unique index can be created safely.
DELETE FROM public.chat_translations a
 USING public.chat_translations b
 WHERE a.message_id = b.message_id
   AND a.target_language = b.target_language
   AND a.ctid > b.ctid;

CREATE UNIQUE INDEX IF NOT EXISTS chat_translations_message_lang_uidx
  ON public.chat_translations (message_id, target_language);

-- 2) Realtime: app receives new translation rows instantly.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
     WHERE pubname = 'supabase_realtime'
       AND schemaname = 'public'
       AND tablename = 'chat_translations'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_translations;
  END IF;
END $$;

-- NOTE: Realtime only delivers rows the role can SELECT. The app already
-- reads chat_translations with the anon key today (existing RLS, unchanged).
-- If SELECT on chat_translations were blocked for anon, the app falls back
-- to the Edge Function response, which returns the translated text directly.

-- 3) Verification (run manually)
-- SELECT indexname FROM pg_indexes WHERE tablename = 'chat_translations';
-- SELECT tablename FROM pg_publication_tables
--  WHERE pubname = 'supabase_realtime';

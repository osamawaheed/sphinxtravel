-- =====================================================================
-- TourOps Smart Chat - PHASE 2.1 AZERBAIJANI (az) SUPPORT (TEST PHASE)
-- File: supabase/migrations/tourops_test_translation_az.sql
--
-- STATUS: NOT APPLIED. Review, then run manually in the SQL Editor.
--
-- Idempotent. Touches ONLY the language CHECK constraints:
--   * chat_translations.target_language  -> allow 'az'
--   * chat_messages.original_language    -> allow 'az'
-- No RLS, no read_at, no data changes.
-- =====================================================================

-- 1) chat_translations.target_language
DO $$
DECLARE
  c record;
BEGIN
  FOR c IN
    SELECT con.conname
      FROM pg_constraint con
      JOIN pg_class rel ON rel.oid = con.conrelid
      JOIN pg_namespace ns ON ns.oid = rel.relnamespace
     WHERE ns.nspname = 'public'
       AND rel.relname = 'chat_translations'
       AND con.contype = 'c'
       AND pg_get_constraintdef(con.oid) ILIKE '%target_language%'
  LOOP
    EXECUTE format(
      'ALTER TABLE public.chat_translations DROP CONSTRAINT %I', c.conname);
  END LOOP;

  ALTER TABLE public.chat_translations
    ADD CONSTRAINT chat_translations_target_language_check
    CHECK (target_language = ANY (ARRAY['ar','en','ru','ka','az']));
END $$;

-- 2) chat_messages.original_language (nullable column; NULL stays valid)
DO $$
DECLARE
  c record;
BEGIN
  FOR c IN
    SELECT con.conname
      FROM pg_constraint con
      JOIN pg_class rel ON rel.oid = con.conrelid
      JOIN pg_namespace ns ON ns.oid = rel.relnamespace
     WHERE ns.nspname = 'public'
       AND rel.relname = 'chat_messages'
       AND con.contype = 'c'
       AND pg_get_constraintdef(con.oid) ILIKE '%original_language%'
  LOOP
    EXECUTE format(
      'ALTER TABLE public.chat_messages DROP CONSTRAINT %I', c.conname);
  END LOOP;

  ALTER TABLE public.chat_messages
    ADD CONSTRAINT chat_messages_original_language_check
    CHECK (original_language = ANY (ARRAY['ar','en','ru','ka','az']));
END $$;

-- 3) Verification (run manually)
-- SELECT conrelid::regclass, conname, pg_get_constraintdef(oid)
--   FROM pg_constraint
--  WHERE conrelid IN ('public.chat_translations'::regclass,
--                     'public.chat_messages'::regclass)
--    AND contype = 'c';

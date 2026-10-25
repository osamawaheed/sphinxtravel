-- =====================================================================
-- TourOps TEST: guarantee Realtime delivery of chat_messages INSERTs
-- (text AND voice rows use the same publication).
--
-- STATUS: NOT APPLIED. Run manually in the SQL Editor ONLY if the
-- verification query below shows chat_messages is missing.
-- Idempotent. Changes NO RLS policy, NO Storage policy, NO data.
-- =====================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'chat_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
  END IF;
END $$;

ALTER TABLE public.chat_messages REPLICA IDENTITY FULL;

-- Verification (run manually)
-- SELECT tablename FROM pg_publication_tables
--  WHERE pubname = 'supabase_realtime' AND schemaname = 'public';

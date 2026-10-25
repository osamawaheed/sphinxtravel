-- =====================================================================
-- TourOps Smart Chat - READ RECEIPTS (TEST PHASE ONLY)
-- File: supabase/migrations/tourops_test_read_receipts.sql
--
-- STATUS: NOT APPLIED. Run manually in the Supabase SQL Editor.
--
-- *** TEST ONLY - NOT PRODUCTION SECURITY ***
-- The app signs in through Odoo, so Supabase only sees the `anon` role.
-- p_reader_role / p_reader_odoo_id are CLIENT-SUPPLIED and are NOT proof
-- of identity. Odoo token verification and assigned-driver checks will be
-- added once the Odoo APIs exist (Edge Function or custom JWT).
--
-- Idempotent: safe to run more than once. No existing messages are
-- changed or deleted by this script (no UPDATE/DELETE on chat data).
--
-- Data model for driver replacement (already in place, unchanged):
--   * chat_conversations.odoo_booking_id is UNIQUE -> one conversation
--     per booking; a driver change never creates a new conversation.
--   * chat_driver_changes records previous/new driver + changed_at.
--   * chat_messages keeps sender_name / sender_role / created_at.
-- Read-only access for the previous driver and sender-blocking are NOT
-- enforced here (no fake assignment checks) - production stage.
-- =====================================================================

-- 1) read_at column (already exists; kept for idempotency)
ALTER TABLE public.chat_messages
  ADD COLUMN IF NOT EXISTS read_at timestamptz;

-- Helps the "unread messages from the opposite role" lookup
CREATE INDEX IF NOT EXISTS chat_messages_unread_idx
  ON public.chat_messages (conversation_id, sender_role)
  WHERE read_at IS NULL;

-- 2) RPC: mark incoming (opposite-role) unread messages as read
--    Returns the number of newly marked messages.
CREATE OR REPLACE FUNCTION public.chat_mark_messages_read(
  p_conversation_id uuid,
  p_reader_role     text,
  p_reader_odoo_id  bigint
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_marked integer := 0;
BEGIN
  IF p_conversation_id IS NULL
     OR p_reader_odoo_id IS NULL
     OR p_reader_role IS NULL
     OR p_reader_role NOT IN ('customer', 'driver') THEN
    RETURN 0;
  END IF;

  UPDATE public.chat_messages m
     SET read_at = now()
   WHERE m.conversation_id = p_conversation_id
     AND m.read_at IS NULL                       -- keep existing timestamps
     AND m.sender_role <> p_reader_role          -- only the opposite role
     AND m.odoo_sender_id <> p_reader_odoo_id;   -- never the reader's own

  GET DIAGNOSTICS v_marked = ROW_COUNT;
  RETURN v_marked;
END;
$$;

-- 3) Grants
REVOKE ALL ON FUNCTION public.chat_mark_messages_read(uuid, text, bigint) FROM PUBLIC;

-- TEST ONLY: temporary anon execution because the app has no Supabase Auth
-- session yet. REMOVE this grant when Odoo token verification is added.
GRANT EXECUTE ON FUNCTION public.chat_mark_messages_read(uuid, text, bigint) TO anon;
GRANT EXECUTE ON FUNCTION public.chat_mark_messages_read(uuid, text, bigint) TO authenticated;

-- NOTE: anon gets NO direct UPDATE on chat_messages; read_at can only be
-- changed through the function above. RLS stays ENABLED. Existing RLS
-- policies for SELECT/INSERT are left untouched.

-- 4) Realtime: sender receives read_at UPDATE events on chat_messages
ALTER TABLE public.chat_messages REPLICA IDENTITY FULL;

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

-- 5) Verification (run manually after applying)
-- SELECT proname, pg_get_function_identity_arguments(oid)
--   FROM pg_proc WHERE proname = 'chat_mark_messages_read';
-- SELECT public.chat_mark_messages_read(
--   '<conversation-uuid>'::uuid, 'driver', <driver_odoo_id>::bigint);

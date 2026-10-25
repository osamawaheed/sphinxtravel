-- =====================================================================
-- TourOps Smart Chat - DELIVERY RECEIPTS (TEST PHASE ONLY)
-- File: supabase/migrations/tourops_test_delivery_receipts.sql
--
-- *** TEST ONLY - NOT PRODUCTION SECURITY ***
-- Same trust model as tourops_test_read_receipts.sql: Supabase only sees
-- the `anon` role, so p_reader_role / p_reader_odoo_id are CLIENT-SUPPLIED.
-- Odoo token verification will replace this once the Odoo APIs exist.
--
-- Meaning of the two timestamps (never inferred from INSERT):
--   delivered_at : the RECIPIENT's app, in the foreground with a live
--                  Realtime subscription, actually received the row.
--   read_at      : the recipient's app displayed the conversation.
--
-- Idempotent. No existing message is changed or deleted by this script.
-- =====================================================================

ALTER TABLE public.chat_messages
  ADD COLUMN IF NOT EXISTS delivered_at timestamptz;

CREATE INDEX IF NOT EXISTS chat_messages_undelivered_idx
  ON public.chat_messages (conversation_id, sender_role)
  WHERE delivered_at IS NULL;

CREATE OR REPLACE FUNCTION public.chat_mark_messages_delivered(
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
     SET delivered_at = now()
   WHERE m.conversation_id = p_conversation_id
     AND m.delivered_at IS NULL
     AND m.read_at IS NULL                       -- already read => no downgrade
     AND m.sender_role <> p_reader_role          -- only the opposite role
     AND m.odoo_sender_id <> p_reader_odoo_id;   -- never the reader's own

  GET DIAGNOSTICS v_marked = ROW_COUNT;
  RETURN v_marked;
END;
$$;

-- A message that is read is also delivered: keep the two columns consistent.
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
     SET read_at = now(),
         delivered_at = COALESCE(m.delivered_at, now())
   WHERE m.conversation_id = p_conversation_id
     AND m.read_at IS NULL
     AND m.sender_role <> p_reader_role
     AND m.odoo_sender_id <> p_reader_odoo_id;

  GET DIAGNOSTICS v_marked = ROW_COUNT;
  RETURN v_marked;
END;
$$;

REVOKE ALL ON FUNCTION public.chat_mark_messages_delivered(uuid, text, bigint) FROM PUBLIC;
-- TEST ONLY: remove when Odoo token verification is added.
GRANT EXECUTE ON FUNCTION public.chat_mark_messages_delivered(uuid, text, bigint) TO anon;
GRANT EXECUTE ON FUNCTION public.chat_mark_messages_delivered(uuid, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chat_mark_messages_read(uuid, text, bigint) TO anon;
GRANT EXECUTE ON FUNCTION public.chat_mark_messages_read(uuid, text, bigint) TO authenticated;

-- Realtime: chat_messages is already in supabase_realtime with
-- REPLICA IDENTITY FULL (tourops_test_read_receipts.sql), so delivered_at
-- UPDATE events reach the sender with no further change.

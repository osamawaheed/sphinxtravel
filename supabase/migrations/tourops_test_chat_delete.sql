-- =====================================================================
-- TourOps Smart Chat - DELETE MESSAGE / DELETE CONVERSATION (TEST ONLY)
-- File: supabase/migrations/tourops_test_chat_delete.sql
--
-- STATUS: NOT APPLIED. Review, then run manually in the Supabase TEST
-- project SQL Editor. Idempotent: safe to run more than once.
--
-- *** TEST ONLY - NOT PRODUCTION SECURITY ***
-- The app signs in through Odoo, so Supabase only sees the `anon` role.
-- p_actor_role / p_actor_odoo_id are CLIENT-SUPPLIED (same model as
-- chat_mark_messages_read). The sender check is therefore enforced
-- server-side against chat_messages.odoo_sender_id / sender_role, but is
-- not proof of identity until Odoo token verification exists.
--
-- What this script changes:
--   1. chat_messages: + deleted_for_everyone_at, + deleted_by_odoo_id
--      (rows are KEPT; no DELETE; history integrity preserved)
--   2. NEW table chat_message_hidden       ("Delete for Me", per user)
--   3. NEW table chat_conversation_hidden  ("Delete Conversation", per user)
--   4. NEW RPCs (SECURITY DEFINER):
--        chat_delete_message_for_me
--        chat_delete_message_for_everyone   (sender only)
--        chat_delete_conversation_for_me
--        chat_get_hidden_message_ids        (read helper for history)
--        chat_get_hidden_conversations      (read helper for inbox)
--   5. Realtime: chat_messages already publishes UPDATE (REPLICA IDENTITY
--      FULL) -> "Delete for Everyone" syncs through the existing channel.
--
-- Storage is NOT touched: objects in chat-files / chat-voice / chat-tts
-- are never deleted here (the other participant's history must stay
-- intact). Deleted media is simply no longer referenced/served to the
-- client (see "Delete for Everyone" below, which clears the references
-- the client reads).
-- =====================================================================

-- 1) chat_messages: tombstone columns -------------------------------------
ALTER TABLE public.chat_messages
  ADD COLUMN IF NOT EXISTS deleted_for_everyone_at timestamptz,
  ADD COLUMN IF NOT EXISTS deleted_by_odoo_id      bigint;

CREATE INDEX IF NOT EXISTS chat_messages_deleted_idx
  ON public.chat_messages (conversation_id)
  WHERE deleted_for_everyone_at IS NOT NULL;

-- 2) Per-user hidden messages ("Delete for Me") ---------------------------
CREATE TABLE IF NOT EXISTS public.chat_message_hidden (
  message_id     uuid        NOT NULL
                   REFERENCES public.chat_messages(id) ON DELETE CASCADE,
  viewer_role    text        NOT NULL CHECK (viewer_role IN ('customer','driver')),
  viewer_odoo_id bigint      NOT NULL,
  hidden_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, viewer_role, viewer_odoo_id)
);
ALTER TABLE public.chat_message_hidden ENABLE ROW LEVEL SECURITY;
-- No policies on purpose: anon has NO direct access. Only the
-- SECURITY DEFINER functions below read/write this table.

-- 3) Per-user hidden conversations ("Delete Conversation") ----------------
CREATE TABLE IF NOT EXISTS public.chat_conversation_hidden (
  conversation_id uuid        NOT NULL
                    REFERENCES public.chat_conversations(id) ON DELETE CASCADE,
  viewer_role     text        NOT NULL CHECK (viewer_role IN ('customer','driver')),
  viewer_odoo_id  bigint      NOT NULL,
  hidden_at       timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (conversation_id, viewer_role, viewer_odoo_id)
);
ALTER TABLE public.chat_conversation_hidden ENABLE ROW LEVEL SECURITY;

-- 4a) Delete for Me --------------------------------------------------------
CREATE OR REPLACE FUNCTION public.chat_delete_message_for_me(
  p_message_id     uuid,
  p_actor_role     text,
  p_actor_odoo_id  bigint
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_message_id IS NULL OR p_actor_odoo_id IS NULL
     OR p_actor_role IS NULL
     OR p_actor_role NOT IN ('customer', 'driver') THEN
    RETURN false;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.chat_messages WHERE id = p_message_id) THEN
    RETURN false;
  END IF;

  INSERT INTO public.chat_message_hidden
    (message_id, viewer_role, viewer_odoo_id)
  VALUES (p_message_id, p_actor_role, p_actor_odoo_id)
  ON CONFLICT (message_id, viewer_role, viewer_odoo_id) DO NOTHING;

  RETURN true;
END;
$$;

-- 4b) Delete for Everyone (sender only) ------------------------------------
-- Keeps the row (integrity) but blanks the content and the storage
-- references so nothing deleted can be displayed or played again.
CREATE OR REPLACE FUNCTION public.chat_delete_message_for_everyone(
  p_message_id     uuid,
  p_actor_role     text,
  p_actor_odoo_id  bigint
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rows integer := 0;
BEGIN
  IF p_message_id IS NULL OR p_actor_odoo_id IS NULL
     OR p_actor_role IS NULL
     OR p_actor_role NOT IN ('customer', 'driver') THEN
    RETURN false;
  END IF;

  UPDATE public.chat_messages m
     SET deleted_for_everyone_at = now(),
         deleted_by_odoo_id      = p_actor_odoo_id,
         original_text           = '',
         audio_path              = NULL,
         file_path               = NULL,
         file_name               = NULL,
         file_mime               = NULL,
         file_size_bytes         = NULL
   WHERE m.id = p_message_id
     AND m.deleted_for_everyone_at IS NULL
     AND m.odoo_sender_id = p_actor_odoo_id   -- sender only
     AND m.sender_role    = p_actor_role;

  GET DIAGNOSTICS v_rows = ROW_COUNT;
  RETURN v_rows > 0;
END;
$$;

-- 4c) Delete Conversation (current user only) ------------------------------
CREATE OR REPLACE FUNCTION public.chat_delete_conversation_for_me(
  p_conversation_id uuid,
  p_actor_role      text,
  p_actor_odoo_id   bigint
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_conversation_id IS NULL OR p_actor_odoo_id IS NULL
     OR p_actor_role IS NULL
     OR p_actor_role NOT IN ('customer', 'driver') THEN
    RETURN false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.chat_conversations WHERE id = p_conversation_id
  ) THEN
    RETURN false;
  END IF;

  -- Re-deleting simply moves the cut-off forward.
  INSERT INTO public.chat_conversation_hidden
    (conversation_id, viewer_role, viewer_odoo_id, hidden_at)
  VALUES (p_conversation_id, p_actor_role, p_actor_odoo_id, now())
  ON CONFLICT (conversation_id, viewer_role, viewer_odoo_id)
  DO UPDATE SET hidden_at = EXCLUDED.hidden_at;

  RETURN true;
END;
$$;

-- 4d) Read helper: ids the viewer must not see in a conversation ----------
-- = messages hidden "for me" + every message created BEFORE the viewer's
-- conversation cut-off. Messages created AFTER the cut-off (a new message
-- arriving) are visible again, so the conversation reappears.
CREATE OR REPLACE FUNCTION public.chat_get_hidden_message_ids(
  p_conversation_id uuid,
  p_actor_role      text,
  p_actor_odoo_id   bigint
)
RETURNS TABLE (message_id uuid)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT h.message_id
    FROM public.chat_message_hidden h
    JOIN public.chat_messages m ON m.id = h.message_id
   WHERE m.conversation_id = p_conversation_id
     AND h.viewer_role     = p_actor_role
     AND h.viewer_odoo_id  = p_actor_odoo_id
  UNION
  SELECT m.id
    FROM public.chat_messages m
    JOIN public.chat_conversation_hidden c
      ON c.conversation_id = m.conversation_id
     AND c.viewer_role     = p_actor_role
     AND c.viewer_odoo_id  = p_actor_odoo_id
   WHERE m.conversation_id = p_conversation_id
     AND m.created_at <= c.hidden_at;
$$;

-- 4e) Read helper: conversations the viewer deleted (cut-off per conv) ----
CREATE OR REPLACE FUNCTION public.chat_get_hidden_conversations(
  p_actor_role    text,
  p_actor_odoo_id bigint
)
RETURNS TABLE (conversation_id uuid, hidden_at timestamptz)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT c.conversation_id, c.hidden_at
    FROM public.chat_conversation_hidden c
   WHERE c.viewer_role    = p_actor_role
     AND c.viewer_odoo_id = p_actor_odoo_id;
$$;

-- 5) Grants ----------------------------------------------------------------
REVOKE ALL ON FUNCTION public.chat_delete_message_for_me(uuid, text, bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.chat_delete_message_for_everyone(uuid, text, bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.chat_delete_conversation_for_me(uuid, text, bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.chat_get_hidden_message_ids(uuid, text, bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.chat_get_hidden_conversations(text, bigint) FROM PUBLIC;

-- TEST ONLY: temporary anon execution (no Supabase Auth session yet).
-- REMOVE when Odoo token verification is added.
GRANT EXECUTE ON FUNCTION public.chat_delete_message_for_me(uuid, text, bigint) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.chat_delete_message_for_everyone(uuid, text, bigint) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.chat_delete_conversation_for_me(uuid, text, bigint) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.chat_get_hidden_message_ids(uuid, text, bigint) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.chat_get_hidden_conversations(text, bigint) TO anon, authenticated;

-- anon gets NO direct SELECT/INSERT/UPDATE/DELETE on the two new tables and
-- NO direct DELETE on chat_messages. Existing RLS policies are untouched.

-- 6) Realtime ---------------------------------------------------------------
-- UPDATE events on chat_messages already flow (REPLICA IDENTITY FULL), which
-- is how "Delete for Everyone" reaches the other device.
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

-- 7) Verification (run manually after applying) -----------------------------
-- SELECT proname FROM pg_proc WHERE proname LIKE 'chat_%delete%' OR proname LIKE 'chat_get_hidden%';
-- SELECT column_name FROM information_schema.columns
--  WHERE table_name = 'chat_messages' AND column_name LIKE 'deleted_%';
--
-- Message deletion test:
-- SELECT public.chat_delete_message_for_me('<msg-uuid>'::uuid, 'driver', <odoo_id>);
-- SELECT public.chat_delete_message_for_everyone('<msg-uuid>'::uuid, 'driver', <sender_odoo_id>);
--
-- Conversation deletion test:
-- SELECT public.chat_delete_conversation_for_me('<conv-uuid>'::uuid, 'driver', <odoo_id>);
-- SELECT * FROM public.chat_get_hidden_message_ids('<conv-uuid>'::uuid, 'driver', <odoo_id>);

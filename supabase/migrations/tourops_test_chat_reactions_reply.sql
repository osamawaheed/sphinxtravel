-- =====================================================================
-- TourOps Smart Chat - MESSAGE REPLY + EMOJI REACTIONS (TEST ONLY)
-- File: supabase/migrations/tourops_test_chat_reactions_reply.sql
--
-- STATUS: NOT APPLIED. Review, then run manually in the Supabase TEST
-- project SQL Editor. Idempotent: safe to run more than once.
--
-- *** TEST ONLY - NOT PRODUCTION SECURITY ***
-- Same trust model as tourops_test_chat_delete.sql: the app signs in
-- through Odoo, so Supabase only sees the `anon` role and the actor
-- (role + odoo id) is CLIENT-SUPPLIED. Writes go through a SECURITY
-- DEFINER RPC that validates input and that the message exists.
--
-- What this script changes:
--   1. chat_messages: + reply_to_message_id (nullable, self reference,
--      ON DELETE SET NULL). Existing rows are untouched (NULL).
--   2. NEW table chat_message_reactions
--        one reaction per (message, reactor_role, reactor_odoo_id);
--        changing a reaction = update of the same row.
--   3. NEW RPC chat_set_message_reaction (SECURITY DEFINER)
--        p_emoji = '' (or NULL) removes the caller's reaction.
--   4. Realtime: chat_message_reactions added to supabase_realtime with
--      REPLICA IDENTITY FULL so INSERT / UPDATE / DELETE sync live.
--
-- Nothing else is modified: no storage, no existing policy, no data.
-- =====================================================================

-- 1) Reply reference -------------------------------------------------------
ALTER TABLE public.chat_messages
  ADD COLUMN IF NOT EXISTS reply_to_message_id uuid
    REFERENCES public.chat_messages(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS chat_messages_reply_to_idx
  ON public.chat_messages (reply_to_message_id)
  WHERE reply_to_message_id IS NOT NULL;

-- 2) Reactions -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.chat_message_reactions (
  message_id       uuid        NOT NULL
                     REFERENCES public.chat_messages(id) ON DELETE CASCADE,
  conversation_id  uuid        NOT NULL
                     REFERENCES public.chat_conversations(id) ON DELETE CASCADE,
  reactor_role     text        NOT NULL CHECK (reactor_role IN ('customer','driver')),
  reactor_odoo_id  bigint      NOT NULL,
  emoji            text        NOT NULL CHECK (char_length(emoji) BETWEEN 1 AND 16),
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, reactor_role, reactor_odoo_id)
);

CREATE INDEX IF NOT EXISTS chat_message_reactions_conv_idx
  ON public.chat_message_reactions (conversation_id);

ALTER TABLE public.chat_message_reactions ENABLE ROW LEVEL SECURITY;

-- Read-only for anon (needed for history + Realtime). All writes are done
-- by the SECURITY DEFINER function below; there is NO insert/update/delete
-- policy on purpose.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename  = 'chat_message_reactions'
      AND policyname = 'chat_message_reactions_select'
  ) THEN
    CREATE POLICY chat_message_reactions_select
      ON public.chat_message_reactions
      FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;
END $$;

-- 3) Set / change / remove a reaction ---------------------------------------
CREATE OR REPLACE FUNCTION public.chat_set_message_reaction(
  p_message_id     uuid,
  p_actor_role     text,
  p_actor_odoo_id  bigint,
  p_emoji          text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_conv uuid;
  v_deleted timestamptz;
BEGIN
  IF p_message_id IS NULL OR p_actor_odoo_id IS NULL
     OR p_actor_role IS NULL
     OR p_actor_role NOT IN ('customer', 'driver') THEN
    RETURN false;
  END IF;

  SELECT conversation_id, deleted_for_everyone_at
    INTO v_conv, v_deleted
    FROM public.chat_messages
   WHERE id = p_message_id;

  IF v_conv IS NULL OR v_deleted IS NOT NULL THEN
    RETURN false;
  END IF;

  IF p_emoji IS NULL OR btrim(p_emoji) = '' THEN
    DELETE FROM public.chat_message_reactions
     WHERE message_id = p_message_id
       AND reactor_role = p_actor_role
       AND reactor_odoo_id = p_actor_odoo_id;
    RETURN true;
  END IF;

  IF char_length(p_emoji) > 16 THEN
    RETURN false;
  END IF;

  INSERT INTO public.chat_message_reactions
    (message_id, conversation_id, reactor_role, reactor_odoo_id, emoji)
  VALUES (p_message_id, v_conv, p_actor_role, p_actor_odoo_id, p_emoji)
  ON CONFLICT (message_id, reactor_role, reactor_odoo_id)
  DO UPDATE SET emoji = EXCLUDED.emoji, updated_at = now();

  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.chat_set_message_reaction(uuid, text, bigint, text)
  TO anon, authenticated;

-- 4) Realtime -----------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'chat_message_reactions'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_message_reactions;
  END IF;
END $$;

ALTER TABLE public.chat_message_reactions REPLICA IDENTITY FULL;

-- Verification (run manually)
-- SELECT column_name FROM information_schema.columns
--  WHERE table_name = 'chat_messages' AND column_name = 'reply_to_message_id';
-- SELECT tablename FROM pg_publication_tables
--  WHERE pubname = 'supabase_realtime' AND tablename = 'chat_message_reactions';

-- =====================================================================
-- Chat closure enforcement (server side)
--
-- Odoo is the source of truth for trip status. The chat-sync-driver edge
-- function writes the verdict into chat_conversations.closed_at through the
-- service-role-only chat_sec_set_conversation_closed(). From then on the
-- database refuses every new message in a closed conversation regardless of
-- the client path (app UI, other screens, direct REST/RPC calls, legacy anon
-- or Odoo JWT).
--
-- * Additive and idempotent. No existing RLS policy is dropped or relaxed.
-- * Reading history (SELECT policies) is untouched: closed chats stay
--   readable.
-- * Reactions / deletes / receipts are not message inserts and are unchanged.
-- =====================================================================

ALTER TABLE public.chat_conversations
  ADD COLUMN IF NOT EXISTS closed_at timestamptz;

-- ---------------------------------------------------------------------
-- 1) Hard guard on every message insert (all roles, all paths).
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.chat_sec_block_closed_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
  IF EXISTS (
    SELECT 1
      FROM public.chat_conversations c
     WHERE c.id = NEW.conversation_id
       AND c.closed_at IS NOT NULL
       AND c.closed_at <= pg_catalog.now()
  ) THEN
    RAISE EXCEPTION 'chat conversation is closed'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.chat_sec_block_closed_insert()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS chat_sec_block_closed_insert_trg
  ON public.chat_messages;
CREATE TRIGGER chat_sec_block_closed_insert_trg
  BEFORE INSERT ON public.chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.chat_sec_block_closed_insert();

-- ---------------------------------------------------------------------
-- 2) chat_sec_can_send also requires an open conversation (JWT path).
--    Same signature and body as before plus the closed_at condition.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.chat_sec_can_send(p_conversation_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
  SELECT public.chat_sec_has_odoo_jwt()
     AND public.chat_sec_jwt_flag('can_view')
     AND public.chat_sec_jwt_flag('can_send')
     AND EXISTS (
       SELECT 1
         FROM public.chat_conversations c
        WHERE c.id = p_conversation_id
          AND c.odoo_booking_id = public.chat_sec_jwt_booking_id()
          AND (c.closed_at IS NULL OR c.closed_at > pg_catalog.now())
          AND (
            public.chat_sec_jwt_role() = 'customer'
            OR (
              public.chat_sec_jwt_role() = 'driver'
              AND c.current_driver_odoo_id IS NOT NULL
              AND c.current_driver_odoo_id = public.chat_sec_jwt_odoo_id()
            )
          )
     );
$$;

GRANT EXECUTE ON FUNCTION public.chat_sec_can_send(uuid)
  TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 3) Service-role-only writer used by the chat-sync-driver edge function.
--    p_closed = true  -> closes (keeps the first closure time)
--    p_closed = false -> reopens (e.g. Odoo moved the trip back)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.chat_sec_set_conversation_closed(
  p_odoo_booking_id bigint,
  p_closed          boolean
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
  IF p_odoo_booking_id IS NULL OR p_closed IS NULL THEN
    RAISE EXCEPTION 'invalid closure update';
  END IF;
  UPDATE public.chat_conversations c
     SET closed_at = CASE
           WHEN p_closed THEN COALESCE(c.closed_at, pg_catalog.now())
           ELSE NULL
         END
   WHERE c.odoo_booking_id = p_odoo_booking_id;
  RETURN FOUND;
END;
$$;

REVOKE ALL ON FUNCTION public.chat_sec_set_conversation_closed(bigint, boolean)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.chat_sec_set_conversation_closed(bigint, boolean)
  TO service_role;

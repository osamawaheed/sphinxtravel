-- =====================================================================
-- TourOps Smart Chat - PHASE 3B / MIGRATION 02 of 03
-- Booking-scoped RLS, JWT-aware RPC v2 functions, Storage insert policies
--
-- STATUS: PREPARED FOR REVIEW. NOT APPLIED. DO NOT RUN IN PRODUCTION.
-- Requires migration 01. Run first in a throwaway / staging project.
--
-- PROPERTIES
--   * ADDITIVE ONLY. No DROP of any pre-existing policy, no REVOKE on any
--     pre-existing object, no ALTER of existing functions or policies.
--     (The only DROP POLICY statements target this file's own chat_sec_*
--     storage policies so the file can be re-run.)
--     Existing anon policies / grants / RPCs are left exactly as they are,
--     so the current chat keeps working while ODOO_CHAT_AUTH_ENABLED=false.
--   * New policies are named chat_sec_* and apply TO authenticated only.
--   * New RPCs are named *_v2. Old RPCs are untouched.
--   * Legacy insecure access is closed ONLY by the separate, reversible
--     script 98_phase3b_cutover_DRAFT.sql (NOT executed, NOT part of
--     this migration set's automatic run).
--
-- REVISION 2 (search_path hardening)
--   * Every SECURITY DEFINER function uses
--       SET search_path = pg_catalog, pg_temp
--     All object references are schema-qualified (public.*).
--
-- REVISION 3 (this revision)
--   1. SENDER EXCLUSION FIXED in chat_mark_messages_delivered_v2 and
--      chat_mark_messages_read_v2.
--        before:  sender_role <> v_role AND odoo_sender_id <> v_id
--        after:   NOT (sender_role = v_role AND odoo_sender_id = v_id)
--      A caller's own messages are excluded; every other message is
--      marked. The old form skipped a counterpart's message whenever
--      the two parties' numeric Odoo ids happened to be equal
--      (customer and driver ids come from different Odoo models, so
--      collisions are possible). Both functions also fail closed
--      (return 0) when the JWT role / id claims are missing.
--   2. STORAGE FORMATS VERIFIED against the Flutter code and live paths:
--        path   = '<conversation uuid>/<customer|driver>_<odooId>_<ms>.<ext>'
--                 (chat_supabase_service.dart sendVoice / sendFile)
--        voice  = webm | m4a | wav | ogg | mp3
--                 (_detectAudioFormat in chat_supabase_service.dart and
--                  chat-transcribe-message: webm, m4a, wav, ogg, mp3)
--        files  = jpg jpeg png webp gif heic pdf doc docx xls xlsx txt
--                 mp4 webm   (_attachmentMimeByExt; video added by
--                 tourops_test_chat_video.sql)
--      Revision 2 only allowed voice webm|m4a and files WITHOUT mp4/webm,
--      which would have broken wav/ogg/mp3 voice and all video the day the
--      JWT path is switched on. Both are now covered.
--      Negative ids (-?[0-9]+ in the legacy regex) are intentionally NOT
--      accepted: a JWT odoo_user_id is always a positive integer
--      (chat_sec_jwt_odoo_id only matches ^[0-9]{1,18}$), so a negative id
--      can never equal the claim and the old allowance is dead weight.
--      Bucket-level MIME allow-list and the 10 MB limit are enforced by
--      Storage itself and are NOT changed here.
--   3. RLS / BYPASS REVIEW (see section 4 and the cutover script):
--        * Every new policy is TO authenticated and calls a helper that
--          requires a valid Odoo claim set; anon never matches them.
--        * Policies are PERMISSIVE and OR-ed. Legacy policies that remain
--          (anon + authenticated USING (true), anon INSERT on storage,
--          broad table grants) still allow a JWT user to read/write
--          everything. This migration cannot close that; the cutover
--          script does, after the JWT path is tested.
--        * chat_sec_msg_insert now also pins the fields a client must not
--          choose: deleted_for_everyone_at, deleted_by_odoo_id, read_at,
--          delivered_at. (Columns that do not exist are not referenced;
--          deleted_by_odoo_id is created by tourops_test_chat_delete.sql
--          and is already used by the delete RPC below.)
--        * Reply target must belong to the SAME conversation
--          (reply_to_message_id), preventing cross-conversation probing
--          through a reply reference.
--        * Message type / attachment columns are bound to the storage
--          path conventions: audio_path / file_path must start with the
--          conversation's own uuid folder and carry the caller's own
--          role/id prefix, so a message cannot point at another
--          conversation's or another user's object.
--        * v2 RPCs: EXECUTE revoked from PUBLIC and anon, granted to
--          authenticated and service_role only.
--   4. EXISTING CHAT FEATURES (checked against the Flutter calls):
--        text / reply / reactions / delete-for-me / delete-for-everyone /
--        delete-conversation / delivered / read / voice / file / video /
--        translations / transcripts all have a v2 or policy equivalent.
--        See the "FEATURE MATRIX" comment at the bottom.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Table RLS policies (authenticated + Odoo JWT only)
-- ---------------------------------------------------------------------

-- Conversations: a client may read ONLY its own booking's conversation.
-- No client INSERT/UPDATE: creation goes through chat_sec_ensure_conversation
-- (service role).
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
      AND tablename='chat_conversations' AND policyname='chat_sec_conv_select') THEN
    CREATE POLICY chat_sec_conv_select ON public.chat_conversations
      FOR SELECT TO authenticated
      USING (public.chat_sec_can_view(id));
  END IF;
END $$;

-- Messages: SELECT when the booking claim matches.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
      AND tablename='chat_messages' AND policyname='chat_sec_msg_select') THEN
    CREATE POLICY chat_sec_msg_select ON public.chat_messages
      FOR SELECT TO authenticated
      USING (public.chat_sec_can_view(conversation_id));
  END IF;
END $$;

-- Messages: INSERT only as the authenticated identity, only while
-- chat_sec_can_send (current driver check re-evaluated per insert).
-- Sender identity columns MUST equal the JWT claims (no spoofing).
-- Server-owned state columns must be at their defaults.
-- Attachment / voice paths must live in this conversation's folder and
-- carry the caller's own <role>_<id>_ prefix.
-- A reply target must be a message of the same conversation.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
      AND tablename='chat_messages' AND policyname='chat_sec_msg_insert') THEN
    CREATE POLICY chat_sec_msg_insert ON public.chat_messages
      FOR INSERT TO authenticated
      WITH CHECK (
        public.chat_sec_can_send(conversation_id)
        AND sender_role    = public.chat_sec_jwt_role()
        AND odoo_sender_id = public.chat_sec_jwt_odoo_id()
        AND deleted_for_everyone_at IS NULL
        AND deleted_by_odoo_id IS NULL
        AND read_at IS NULL
        AND delivered_at IS NULL
        AND message_type IN ('text', 'voice', 'file')
        -- voice: audio_path required, must be this conversation + caller
        AND (
          message_type <> 'voice'
          OR (
            audio_path IS NOT NULL
            AND audio_path LIKE conversation_id::text || '/'
                                || public.chat_sec_jwt_role() || '_'
                                || public.chat_sec_jwt_odoo_id()::text || '\_%'
          )
        )
        -- file: file_path required, same rule
        AND (
          message_type <> 'file'
          OR (
            file_path IS NOT NULL
            AND file_path LIKE conversation_id::text || '/'
                               || public.chat_sec_jwt_role() || '_'
                               || public.chat_sec_jwt_odoo_id()::text || '\_%'
          )
        )
        -- text rows must not smuggle media references
        AND (
          message_type <> 'text'
          OR (audio_path IS NULL AND file_path IS NULL)
        )
        -- reply target must be in the same conversation
        AND (
          reply_to_message_id IS NULL
          OR EXISTS (
            SELECT 1 FROM public.chat_messages r
             WHERE r.id = reply_to_message_id
               AND r.conversation_id = chat_messages.conversation_id
          )
        )
      );
  END IF;
END $$;
-- No UPDATE / DELETE policy for authenticated: receipts, reactions and
-- deletes happen only through the *_v2 RPCs below.

-- Translations: readable through the parent message's conversation.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
      AND tablename='chat_translations' AND policyname='chat_sec_tr_select') THEN
    CREATE POLICY chat_sec_tr_select ON public.chat_translations
      FOR SELECT TO authenticated
      USING (EXISTS (
        SELECT 1 FROM public.chat_messages m
         WHERE m.id = chat_translations.message_id
           AND public.chat_sec_can_view(m.conversation_id)
      ));
  END IF;
END $$;

-- Voice transcripts: the app reads chat_voice_transcriptions directly
-- (chat_supabase_service.dart, select message_id, transcript_text,
-- detected_language, status). Revision 2 gave authenticated NO policy, so
-- transcripts would silently disappear on the JWT path. Same scoping as
-- translations: through the parent message's conversation. Columns are
-- not restricted here because only the 4 selected columns are read by the
-- client; the cutover script revokes broad table grants and re-grants
-- column-level SELECT.
DO $$
BEGIN
  IF to_regclass('public.chat_voice_transcriptions') IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
        AND tablename='chat_voice_transcriptions'
        AND policyname='chat_sec_vt_select') THEN
    CREATE POLICY chat_sec_vt_select ON public.chat_voice_transcriptions
      FOR SELECT TO authenticated
      USING (EXISTS (
        SELECT 1 FROM public.chat_messages m
         WHERE m.id = chat_voice_transcriptions.message_id
           AND public.chat_sec_can_view(m.conversation_id)
      ));
  END IF;
END $$;

-- Reactions: scoped SELECT. (Legacy `USING (true)` policy must be dropped
-- at cutover, see cutover script.)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
      AND tablename='chat_message_reactions' AND policyname='chat_sec_react_select') THEN
    CREATE POLICY chat_sec_react_select ON public.chat_message_reactions
      FOR SELECT TO authenticated
      USING (public.chat_sec_can_view(conversation_id));
  END IF;
END $$;

-- chat_voice_tts*, chat_ai_*, chat_message_hidden,
-- chat_conversation_hidden, chat_driver_changes, chat_assignment_events:
--   intentionally NO policy for authenticated (server / RPC only).

-- ---------------------------------------------------------------------
-- 2) RPC v2: identity comes from the JWT, never from arguments.
-- ---------------------------------------------------------------------

-- Delivered: marks the OTHER party's messages. A message is the caller's
-- own only when BOTH role and id match.
CREATE OR REPLACE FUNCTION public.chat_mark_messages_delivered_v2(
  p_conversation_id uuid
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
  v_role text   := public.chat_sec_jwt_role();
  v_id   bigint := public.chat_sec_jwt_odoo_id();
  v_n    integer := 0;
BEGIN
  IF p_conversation_id IS NULL OR v_role IS NULL OR v_id IS NULL THEN
    RETURN 0;
  END IF;
  IF NOT public.chat_sec_can_view(p_conversation_id) THEN
    RETURN 0;
  END IF;

  UPDATE public.chat_messages m
     SET delivered_at = now()
   WHERE m.conversation_id = p_conversation_id
     AND m.delivered_at IS NULL
     AND m.read_at IS NULL                       -- already read => no downgrade
     AND NOT (m.sender_role = v_role AND m.odoo_sender_id = v_id);

  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END;
$$;

-- Read: a read message is also delivered (columns stay consistent).
CREATE OR REPLACE FUNCTION public.chat_mark_messages_read_v2(
  p_conversation_id uuid
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
  v_role text   := public.chat_sec_jwt_role();
  v_id   bigint := public.chat_sec_jwt_odoo_id();
  v_n    integer := 0;
BEGIN
  IF p_conversation_id IS NULL OR v_role IS NULL OR v_id IS NULL THEN
    RETURN 0;
  END IF;
  IF NOT public.chat_sec_can_view(p_conversation_id) THEN
    RETURN 0;
  END IF;

  UPDATE public.chat_messages m
     SET read_at      = now(),
         delivered_at = COALESCE(m.delivered_at, now())
   WHERE m.conversation_id = p_conversation_id
     AND m.read_at IS NULL
     AND NOT (m.sender_role = v_role AND m.odoo_sender_id = v_id);

  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END;
$$;

-- Reactions are a write: require can_send (current driver / customer).
CREATE OR REPLACE FUNCTION public.chat_set_message_reaction_v2(
  p_message_id uuid,
  p_emoji      text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
  v_conv    uuid;
  v_deleted timestamptz;
  v_role    text   := public.chat_sec_jwt_role();
  v_id      bigint := public.chat_sec_jwt_odoo_id();
BEGIN
  IF p_message_id IS NULL OR v_role IS NULL OR v_id IS NULL THEN
    RETURN false;
  END IF;

  SELECT conversation_id, deleted_for_everyone_at
    INTO v_conv, v_deleted
    FROM public.chat_messages WHERE id = p_message_id;

  IF v_conv IS NULL OR v_deleted IS NOT NULL
     OR NOT public.chat_sec_can_send(v_conv) THEN
    RETURN false;
  END IF;

  IF p_emoji IS NULL OR btrim(p_emoji) = '' THEN
    DELETE FROM public.chat_message_reactions
     WHERE message_id = p_message_id
       AND reactor_role = v_role AND reactor_odoo_id = v_id;
    RETURN true;
  END IF;

  IF char_length(p_emoji) > 16 THEN RETURN false; END IF;

  INSERT INTO public.chat_message_reactions
    (message_id, conversation_id, reactor_role, reactor_odoo_id, emoji)
  VALUES (p_message_id, v_conv, v_role, v_id, p_emoji)
  ON CONFLICT (message_id, reactor_role, reactor_odoo_id)
  DO UPDATE SET emoji = EXCLUDED.emoji, updated_at = now();

  RETURN true;
END;
$$;

-- "Delete for me" is a personal view setting: view access is enough.
CREATE OR REPLACE FUNCTION public.chat_delete_message_for_me_v2(
  p_message_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
  v_conv uuid;
  v_role text   := public.chat_sec_jwt_role();
  v_id   bigint := public.chat_sec_jwt_odoo_id();
BEGIN
  IF p_message_id IS NULL OR v_role IS NULL OR v_id IS NULL THEN
    RETURN false;
  END IF;
  SELECT conversation_id INTO v_conv
    FROM public.chat_messages WHERE id = p_message_id;
  IF v_conv IS NULL OR NOT public.chat_sec_can_view(v_conv) THEN
    RETURN false;
  END IF;

  INSERT INTO public.chat_message_hidden
    (message_id, viewer_role, viewer_odoo_id)
  VALUES (p_message_id, v_role, v_id)
  ON CONFLICT (message_id, viewer_role, viewer_odoo_id) DO NOTHING;
  RETURN true;
END;
$$;

-- Delete for everyone: sender only AND still allowed to send.
-- Body mirrors tourops_test_chat_delete.sql (content + media refs cleared).
CREATE OR REPLACE FUNCTION public.chat_delete_message_for_everyone_v2(
  p_message_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
  v_conv uuid;
  v_rows integer := 0;
  v_role text   := public.chat_sec_jwt_role();
  v_id   bigint := public.chat_sec_jwt_odoo_id();
BEGIN
  IF p_message_id IS NULL OR v_role IS NULL OR v_id IS NULL THEN
    RETURN false;
  END IF;
  SELECT conversation_id INTO v_conv
    FROM public.chat_messages WHERE id = p_message_id;
  IF v_conv IS NULL OR NOT public.chat_sec_can_send(v_conv) THEN
    RETURN false;
  END IF;

  UPDATE public.chat_messages m
     SET deleted_for_everyone_at = now(),
         deleted_by_odoo_id      = v_id,
         original_text           = '',
         audio_path              = NULL,
         file_path               = NULL,
         file_name               = NULL,
         file_mime               = NULL,
         file_size_bytes         = NULL
   WHERE m.id = p_message_id
     AND m.deleted_for_everyone_at IS NULL
     AND m.odoo_sender_id = v_id
     AND m.sender_role    = v_role;

  GET DIAGNOSTICS v_rows = ROW_COUNT;
  RETURN v_rows > 0;
END;
$$;

CREATE OR REPLACE FUNCTION public.chat_delete_conversation_for_me_v2(
  p_conversation_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
  v_role text   := public.chat_sec_jwt_role();
  v_id   bigint := public.chat_sec_jwt_odoo_id();
BEGIN
  IF p_conversation_id IS NULL OR v_role IS NULL OR v_id IS NULL
     OR NOT public.chat_sec_can_view(p_conversation_id) THEN
    RETURN false;
  END IF;

  INSERT INTO public.chat_conversation_hidden
    (conversation_id, viewer_role, viewer_odoo_id, hidden_at)
  VALUES (p_conversation_id, v_role, v_id, now())
  ON CONFLICT (conversation_id, viewer_role, viewer_odoo_id)
  DO UPDATE SET hidden_at = EXCLUDED.hidden_at;
  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.chat_get_hidden_message_ids_v2(
  p_conversation_id uuid
)
RETURNS TABLE (message_id uuid)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
  SELECT h.message_id
    FROM public.chat_message_hidden h
    JOIN public.chat_messages m ON m.id = h.message_id
   WHERE public.chat_sec_can_view(p_conversation_id)
     AND m.conversation_id = p_conversation_id
     AND h.viewer_role    = public.chat_sec_jwt_role()
     AND h.viewer_odoo_id = public.chat_sec_jwt_odoo_id()
  UNION
  SELECT m.id
    FROM public.chat_messages m
    JOIN public.chat_conversation_hidden c
      ON c.conversation_id = m.conversation_id
     AND c.viewer_role     = public.chat_sec_jwt_role()
     AND c.viewer_odoo_id  = public.chat_sec_jwt_odoo_id()
   WHERE public.chat_sec_can_view(p_conversation_id)
     AND m.conversation_id = p_conversation_id
     AND m.created_at <= c.hidden_at;
$$;

CREATE OR REPLACE FUNCTION public.chat_get_hidden_conversations_v2()
RETURNS TABLE (conversation_id uuid, hidden_at timestamptz)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
  SELECT c.conversation_id, c.hidden_at
    FROM public.chat_conversation_hidden c
   WHERE public.chat_sec_can_view(c.conversation_id)
     AND c.viewer_role    = public.chat_sec_jwt_role()
     AND c.viewer_odoo_id = public.chat_sec_jwt_odoo_id();
$$;

-- v2 RPCs are for the Odoo-JWT path only: authenticated, not anon.
-- service_role is granted so staging tests can call them with an
-- impersonated claim set.
REVOKE ALL ON FUNCTION
  public.chat_mark_messages_delivered_v2(uuid),
  public.chat_mark_messages_read_v2(uuid),
  public.chat_set_message_reaction_v2(uuid, text),
  public.chat_delete_message_for_me_v2(uuid),
  public.chat_delete_message_for_everyone_v2(uuid),
  public.chat_delete_conversation_for_me_v2(uuid),
  public.chat_get_hidden_message_ids_v2(uuid),
  public.chat_get_hidden_conversations_v2()
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
  public.chat_mark_messages_delivered_v2(uuid),
  public.chat_mark_messages_read_v2(uuid),
  public.chat_set_message_reaction_v2(uuid, text),
  public.chat_delete_message_for_me_v2(uuid),
  public.chat_delete_message_for_everyone_v2(uuid),
  public.chat_delete_conversation_for_me_v2(uuid),
  public.chat_get_hidden_message_ids_v2(uuid),
  public.chat_get_hidden_conversations_v2()
TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 3) Storage: INSERT policies for the JWT path (authenticated only).
--    Path grammar (verified against sendVoice / sendFile):
--        <conversation uuid>/<customer|driver>_<odooId>_<epoch ms>.<ext>
--    plus:
--      * the folder conversation must belong to the JWT booking and
--        chat_sec_can_send must hold (current driver re-checked)
--      * the filename's role and id must equal the JWT claims
--    NO SELECT / UPDATE / DELETE: downloads stay signed-URL only.
--    Existing anon policies are NOT dropped here (see cutover script).
--
--    The uuid regex is evaluated BEFORE the ::uuid cast: SQL does not
--    guarantee AND short-circuit order, so the cast is wrapped in a CASE
--    that only casts when the regex matched. A malformed path therefore
--    evaluates to NULL/false and is denied instead of raising a cast
--    error.
-- ---------------------------------------------------------------------
DROP POLICY IF EXISTS "chat_sec_voice_insert" ON storage.objects;
CREATE POLICY "chat_sec_voice_insert"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'chat-voice'
  AND name ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/(customer|driver)_[0-9]{1,18}_[0-9]{1,18}\.(webm|m4a|wav|ogg|mp3)$'
  AND public.chat_sec_can_send(
        CASE WHEN name ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/'
             THEN ((storage.foldername(name))[1])::uuid END)
  AND split_part(split_part(name, '/', 2), '_', 1) = public.chat_sec_jwt_role()
  AND split_part(split_part(name, '/', 2), '_', 2) = public.chat_sec_jwt_odoo_id()::text
);

DROP POLICY IF EXISTS "chat_sec_files_insert" ON storage.objects;
CREATE POLICY "chat_sec_files_insert"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'chat-files'
  AND name ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/(customer|driver)_[0-9]{1,18}_[0-9]{1,18}\.(jpg|jpeg|png|webp|gif|heic|pdf|doc|docx|xls|xlsx|txt|mp4|webm)$'
  AND public.chat_sec_can_send(
        CASE WHEN name ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/'
             THEN ((storage.foldername(name))[1])::uuid END)
  AND split_part(split_part(name, '/', 2), '_', 1) = public.chat_sec_jwt_role()
  AND split_part(split_part(name, '/', 2), '_', 2) = public.chat_sec_jwt_odoo_id()::text
);

-- ---------------------------------------------------------------------
-- 4) BYPASS REVIEW (static, from the repo; live pg_policies already
--    confirmed by the team):
--
--  CLOSED BY THIS FILE (new JWT path)
--    - Spoofed sender on INSERT .............. pinned to JWT claims
--    - Server-owned columns on INSERT ........ pinned to NULL
--    - Cross-conversation reply reference .... same-conversation check
--    - Media path pointing at another chat/user path-prefix check
--    - Uploading into another conversation ... can_send on folder uuid
--    - Uploading as another user ............. filename prefix = claims
--    - Malformed path raising cast error ..... CASE guard
--    - Own-message exclusion on receipts ..... NOT (role AND id)
--
--  STILL OPEN UNTIL CUTOVER (legacy, confirmed live)
--    L1 chat_conversations  anon SELECT/INSERT USING/CHECK (true)
--    L2 chat_messages       anon SELECT/INSERT USING/CHECK (true)
--    L3 chat_message_reactions SELECT USING (true) anon+authenticated
--    L4 storage chat-voice / chat-files anon INSERT policies
--       (chat_voice_anon_insert, chat_files_anon_insert; they also
--        apply TO authenticated, so a JWT user can bypass the
--        chat_sec_* path checks through them)
--    L5 Broad table grants to anon / authenticated
--    L6 Legacy RPCs (chat_mark_messages_*, chat_set_message_reaction,
--       chat_delete_*, chat_get_hidden_*) executable by anon with
--       client-supplied role/id
--    L7 Edge Functions chat-file-sign / chat-transcribe-message /
--       chat-tts-message / chat-translate-message authorise with the
--       anon key + client-supplied viewer_role/viewer_id, then read with
--       the service role. These are NOT covered by RLS at all. They need
--       JWT verification in the function code before cutover completes.
--    L8 Realtime: postgres_changes on chat_messages / reactions /
--       translations obeys the SELECT policies; while L2/L3 exist anon
--       still receives every row.
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- FEATURE MATRIX (Flutter call -> JWT-path equivalent in this file)
--   send text / reply ......... INSERT chat_messages (chat_sec_msg_insert)
--   voice upload + row ........ storage chat_sec_voice_insert + msg insert
--   file / video upload + row . storage chat_sec_files_insert + msg insert
--   load history .............. SELECT chat_messages (chat_sec_msg_select)
--   conversation list/lookup .. SELECT chat_conversations (chat_sec_conv_select)
--   conversation create ....... NOT client-side: service role via
--                               chat_sec_ensure_conversation (Flutter
--                               _createConversation INSERT will be denied
--                               on the JWT path by design)
--   translations (read) ....... chat_sec_tr_select
--   voice transcripts (read) .. chat_sec_vt_select
--   reactions read ............ chat_sec_react_select
--   reactions write ........... chat_set_message_reaction_v2
--   delivered / read receipts . chat_mark_messages_*_v2
--   delete for me / everyone .. chat_delete_message_*_v2
--   delete conversation ....... chat_delete_conversation_for_me_v2
--   hidden lists .............. chat_get_hidden_*_v2
--   realtime (messages, reactions, translations) follows SELECT policies
--   signed URLs / TTS / STT / translate-on-demand: Edge Functions (L7)
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- Verification (run manually in staging)
-- SELECT policyname, cmd, roles FROM pg_policies
--  WHERE policyname LIKE 'chat_sec_%';
-- SELECT proname FROM pg_proc WHERE proname LIKE 'chat_%_v2';  -- 8 rows
-- -- search_path must be pg_catalog, pg_temp on every definer function:
-- SELECT p.oid::regprocedure AS fn, p.prosecdef, p.proconfig
--   FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
--  WHERE n.nspname = 'public' AND p.prosecdef
--    AND (p.proname LIKE 'chat_sec_%' OR p.proname LIKE 'chat_%_v2')
--    AND (p.proconfig IS NULL
--         OR NOT p.proconfig @> ARRAY['search_path=pg_catalog, pg_temp']);
-- -- expect 0 rows
-- -- v2 RPCs must NOT be executable by anon / PUBLIC:
-- SELECT p.oid::regprocedure FROM pg_proc p
--  WHERE p.proname LIKE 'chat\_%\_v2' ESCAPE '\'
--    AND (has_function_privilege('anon', p.oid, 'EXECUTE')
--         OR EXISTS (SELECT 1 FROM aclexplode(COALESCE(p.proacl,
--              acldefault('f', p.proowner))) a
--              WHERE a.grantee = 0 AND a.privilege_type = 'EXECUTE'));
-- -- expect 0 rows
-- ---------------------------------------------------------------------

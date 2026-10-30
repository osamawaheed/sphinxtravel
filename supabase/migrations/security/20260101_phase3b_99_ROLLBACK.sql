-- =====================================================================
-- TourOps Smart Chat - PHASE 3B / MIGRATION 99
-- ROLLBACK for 20260101_phase3b_01 and 20260101_phase3b_02
--
-- STATUS: PREPARED FOR REVIEW. NOT APPLIED.
--
-- Removes ONLY objects created by Phase 3B migrations 01 and 02.
-- Touches NO pre-existing policy, grant, function, table or message data.
-- Idempotent (IF EXISTS everywhere). Safe to run more than once.
--
-- DATA NOTE: the optional step at the bottom (dropping the new columns /
-- chat_assignment_events) DELETES the recorded assignment state. It is
-- commented out by default. The audit rows already copied into the
-- pre-existing chat_driver_changes table are NOT removed by this script.
-- =====================================================================

-- 1) Storage policies (migration 02) ----------------------------------
DROP POLICY IF EXISTS "chat_sec_voice_insert" ON storage.objects;
DROP POLICY IF EXISTS "chat_sec_files_insert" ON storage.objects;

-- 2) Table policies (migration 02) ------------------------------------
DROP POLICY IF EXISTS chat_sec_conv_select  ON public.chat_conversations;
DROP POLICY IF EXISTS chat_sec_msg_select   ON public.chat_messages;
DROP POLICY IF EXISTS chat_sec_msg_insert   ON public.chat_messages;
DROP POLICY IF EXISTS chat_sec_tr_select    ON public.chat_translations;
DROP POLICY IF EXISTS chat_sec_react_select ON public.chat_message_reactions;
DO $$
BEGIN
  IF to_regclass('public.chat_voice_transcriptions') IS NOT NULL THEN
    DROP POLICY IF EXISTS chat_sec_vt_select ON public.chat_voice_transcriptions;
  END IF;
END $$;

-- 3) v2 RPCs (migration 02) -------------------------------------------
DROP FUNCTION IF EXISTS public.chat_mark_messages_delivered_v2(uuid);
DROP FUNCTION IF EXISTS public.chat_mark_messages_read_v2(uuid);
DROP FUNCTION IF EXISTS public.chat_set_message_reaction_v2(uuid, text);
DROP FUNCTION IF EXISTS public.chat_delete_message_for_me_v2(uuid);
DROP FUNCTION IF EXISTS public.chat_delete_message_for_everyone_v2(uuid);
DROP FUNCTION IF EXISTS public.chat_delete_conversation_for_me_v2(uuid);
DROP FUNCTION IF EXISTS public.chat_get_hidden_message_ids_v2(uuid);
DROP FUNCTION IF EXISTS public.chat_get_hidden_conversations_v2();

-- 4) Assignment + authorization functions (migration 01) --------------
--    (dropped after the policies / RPCs that depend on them)
DROP FUNCTION IF EXISTS public.chat_sec_can_send(uuid);
DROP FUNCTION IF EXISTS public.chat_sec_can_view(uuid);
DROP FUNCTION IF EXISTS public.chat_sec_ensure_conversation(bigint, text, bigint, timestamptz);
DROP FUNCTION IF EXISTS public.chat_sec_ensure_conversation(bigint, text, bigint);
DROP FUNCTION IF EXISTS public.chat_sec_apply_authoritative_driver(bigint, bigint, timestamptz);
DROP FUNCTION IF EXISTS public.chat_sec_apply_assignment_event(
  text, bigint, bigint, bigint, timestamptz, bigint, text);
DROP FUNCTION IF EXISTS public.chat_sec_apply_assignment_event(
  text, bigint, bigint, bigint, timestamptz, text);
DROP FUNCTION IF EXISTS public.chat_sec_try_set_driver(
  uuid, bigint, timestamptz, text, bigint, text);
DROP FUNCTION IF EXISTS public.chat_sec_has_odoo_jwt();
DROP FUNCTION IF EXISTS public.chat_sec_jwt_flag(text);
DROP FUNCTION IF EXISTS public.chat_sec_jwt_role();
DROP FUNCTION IF EXISTS public.chat_sec_jwt_odoo_id();
DROP FUNCTION IF EXISTS public.chat_sec_jwt_booking_id();
DROP FUNCTION IF EXISTS public.chat_sec_claim(text);

-- 5) OPTIONAL, DATA-REMOVING (uncomment only if you want a full revert)
-- DROP TABLE IF EXISTS public.chat_assignment_events;
-- DROP INDEX IF EXISTS public.chat_assignment_events_booking_v3_idx;
-- DROP INDEX IF EXISTS public.chat_conversations_current_driver_idx;
-- ALTER TABLE public.chat_conversations
--   DROP COLUMN IF EXISTS current_driver_odoo_id,
--   DROP COLUMN IF EXISTS driver_epoch,
--   DROP COLUMN IF EXISTS driver_changed_at,
--   DROP COLUMN IF EXISTS driver_event_id,
--   DROP COLUMN IF EXISTS driver_seq,
--   DROP COLUMN IF EXISTS driver_state_source;

-- Verification (run manually)
-- SELECT proname FROM pg_proc WHERE proname LIKE 'chat_sec_%' OR proname LIKE 'chat_%_v2';  -- 0 rows
-- SELECT policyname FROM pg_policies WHERE policyname LIKE 'chat_sec_%';                    -- 0 rows

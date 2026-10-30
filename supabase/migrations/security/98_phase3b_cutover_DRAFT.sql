-- =====================================================================
-- TourOps Smart Chat - PHASE 3B / SCRIPT 98 - CUTOVER (DRAFT)
--
-- STATUS: DRAFT. NOT EXECUTED. NOT APPLIED. DO NOT RUN until every
-- precondition below is signed off in STAGING and then production.
--
-- PURPOSE
--   Removes the insecure legacy anonymous access that Migration 02
--   deliberately leaves in place, so only the Odoo-JWT path
--   (chat_sec_* policies + *_v2 RPCs) remains.
--
-- REVERSIBLE
--   Before anything is removed, the exact definition of every policy and
--   every table / function privilege that this script touches is written
--   to the audit table  security_backup.phase3b_cutover_backup.
--   98b_phase3b_cutover_REVERT_DRAFT.sql (below, in the same transaction
--   style) replays that table to restore the pre-cutover state.
--   Nothing is dropped without a backup row written first, in the same
--   transaction. The script is one transaction: any error rolls back all.
--
-- PRECONDITIONS (all must be TRUE; the script verifies what it can and
-- aborts otherwise)
--   P1  Migration 01 and 02 (Revision 3) applied and tested in staging.
--   P2  Flutter build that uses the *_v2 RPCs, sends the Odoo JWT as the
--       Supabase session, and no longer calls _createConversation INSERT
--       (conversations created by chat_sec_ensure_conversation).
--   P3  ODOO_CHAT_AUTH_ENABLED=true in the released app, and old app
--       versions are retired or force-updated (old builds use anon and
--       WILL break the moment this runs).
--   P4  Edge Functions chat-file-sign, chat-transcribe-message,
--       chat-tts-message, chat-translate-message verify the Odoo JWT
--       (not the anon key + client-supplied viewer_id) and are deployed.
--       THE SCRIPT CANNOT VERIFY THIS. Without P4 the Edge Functions
--       remain a bypass even after this cutover.
--   P5  Staging end-to-end matrix passed with a real JWT for BOTH
--       roles: text, reply, reaction, voice (webm/m4a/wav/ogg/mp3),
--       file, video, translation, transcript, delivered, read,
--       delete-for-me, delete-for-everyone, delete-conversation,
--       realtime, replaced-driver lockout, wrong-booking denial.
--   P6  A database backup / PITR point was taken immediately before.
--   P7  Set the flag below to 'YES' in the session. This is an explicit
--       human confirmation, never defaulted.
--
-- RUN AS: a role that owns the tables (postgres). Run in a maintenance
-- window.
-- =====================================================================

BEGIN;

-- Human gate (P7). Must be run as:  SET LOCAL app.chat_cutover_confirm = 'YES';
DO $$
BEGIN
  IF COALESCE(current_setting('app.chat_cutover_confirm', true), '') <> 'YES' THEN
    RAISE EXCEPTION 'Cutover not confirmed. SET LOCAL app.chat_cutover_confirm = ''YES'' after P1-P6 are signed off.';
  END IF;
END $$;

-- Precondition (P1): new objects must exist.
DO $$
DECLARE
  v_missing text[] := ARRAY[]::text[];
BEGIN
  IF to_regprocedure('public.chat_sec_can_view(uuid)') IS NULL THEN
    v_missing := v_missing || 'chat_sec_can_view';
  END IF;
  IF to_regprocedure('public.chat_sec_can_send(uuid)') IS NULL THEN
    v_missing := v_missing || 'chat_sec_can_send';
  END IF;
  IF to_regprocedure('public.chat_mark_messages_read_v2(uuid)') IS NULL THEN
    v_missing := v_missing || 'chat_mark_messages_read_v2';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
        AND tablename='chat_messages' AND policyname='chat_sec_msg_select') THEN
    v_missing := v_missing || 'chat_sec_msg_select';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='storage'
        AND tablename='objects' AND policyname='chat_sec_voice_insert') THEN
    v_missing := v_missing || 'chat_sec_voice_insert';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='storage'
        AND tablename='objects' AND policyname='chat_sec_files_insert') THEN
    v_missing := v_missing || 'chat_sec_files_insert';
  END IF;
  IF array_length(v_missing, 1) IS NOT NULL THEN
    RAISE EXCEPTION 'Cutover aborted, migrations 01/02 not fully applied. Missing: %', v_missing;
  END IF;
END $$;

-- ---------------------------------------------------------------------
-- A) BACKUP (written before any change, same transaction)
-- ---------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS security_backup;
REVOKE ALL ON SCHEMA security_backup FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS security_backup.phase3b_cutover_backup (
  id          bigserial PRIMARY KEY,
  run_at      timestamptz NOT NULL DEFAULT now(),
  kind        text NOT NULL CHECK (kind IN ('policy','table_grant','function_grant','column_grant')),
  schema_name text,
  object_name text,
  detail      text,          -- policy name / grantee:privilege / signature
  restore_sql text NOT NULL, -- exact statement that restores it
  restored_at timestamptz
);
ALTER TABLE security_backup.phase3b_cutover_backup ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON security_backup.phase3b_cutover_backup FROM PUBLIC, anon, authenticated;

-- A1) Policies to be removed: every NON chat_sec_* policy on the chat
--     tables and on chat-voice / chat-files storage, that is open to
--     anon or to authenticated/PUBLIC. chat_sec_* policies are kept.
INSERT INTO security_backup.phase3b_cutover_backup
  (kind, schema_name, object_name, detail, restore_sql)
SELECT 'policy', p.schemaname, p.tablename, p.policyname,
       format('CREATE POLICY %I ON %I.%I AS %s FOR %s TO %s%s%s;',
              p.policyname, p.schemaname, p.tablename,
              p.permissive, p.cmd,
              array_to_string(ARRAY(SELECT CASE WHEN r = 'public' THEN 'PUBLIC' ELSE quote_ident(r) END
                                      FROM unnest(p.roles) r), ', '),
              CASE WHEN p.qual IS NOT NULL THEN ' USING (' || p.qual || ')' ELSE '' END,
              CASE WHEN p.with_check IS NOT NULL THEN ' WITH CHECK (' || p.with_check || ')' ELSE '' END)
  FROM pg_policies p
 WHERE p.policyname NOT LIKE 'chat\_sec\_%' ESCAPE '\'
   AND (
        (p.schemaname = 'public' AND p.tablename IN (
           'chat_conversations','chat_messages','chat_message_reactions',
           'chat_translations','chat_voice_transcriptions',
           'chat_message_hidden','chat_conversation_hidden',
           'chat_driver_changes'))
     OR (p.schemaname = 'storage' AND p.tablename = 'objects'
         AND (COALESCE(p.qual,'') ILIKE '%chat-voice%'
              OR COALESCE(p.with_check,'') ILIKE '%chat-voice%'
              OR COALESCE(p.qual,'') ILIKE '%chat-files%'
              OR COALESCE(p.with_check,'') ILIKE '%chat-files%'
              OR p.policyname IN ('chat_voice_anon_insert','chat_files_anon_insert')))
   );

-- A2) Table privileges of anon / authenticated on the chat tables.
INSERT INTO security_backup.phase3b_cutover_backup
  (kind, schema_name, object_name, detail, restore_sql)
SELECT 'table_grant', g.table_schema, g.table_name,
       g.grantee || ':' || g.privilege_type,
       format('GRANT %s ON %I.%I TO %I;',
              g.privilege_type, g.table_schema, g.table_name, g.grantee)
  FROM information_schema.role_table_grants g
 WHERE g.table_schema = 'public'
   AND g.grantee IN ('anon','authenticated')
   AND g.table_name IN (
     'chat_conversations','chat_messages','chat_message_reactions',
     'chat_translations','chat_voice_transcriptions',
     'chat_message_hidden','chat_conversation_hidden',
     'chat_driver_changes','chat_assignment_events');

-- A3) EXECUTE on legacy (non _v2, non chat_sec_) chat RPCs for
--     anon / authenticated / PUBLIC.
INSERT INTO security_backup.phase3b_cutover_backup
  (kind, schema_name, object_name, detail, restore_sql)
SELECT 'function_grant', 'public', p.oid::regprocedure::text, r.rolname,
       format('GRANT EXECUTE ON FUNCTION %s TO %s;',
              p.oid::regprocedure::text,
              CASE WHEN r.rolname = 'public' THEN 'PUBLIC' ELSE quote_ident(r.rolname) END)
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  CROSS JOIN (VALUES ('anon'), ('authenticated'), ('public')) AS r(rolname)
 WHERE n.nspname = 'public'
   AND p.proname IN (
     'chat_mark_messages_delivered','chat_mark_messages_read',
     'chat_set_message_reaction',
     'chat_delete_message_for_me','chat_delete_message_for_everyone',
     'chat_delete_conversation_for_me',
     'chat_get_hidden_message_ids','chat_get_hidden_conversations')
   AND CASE WHEN r.rolname = 'public'
            THEN EXISTS (SELECT 1 FROM aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a
                          WHERE a.grantee = 0 AND a.privilege_type = 'EXECUTE')
            ELSE has_function_privilege(r.rolname, p.oid, 'EXECUTE')
       END;

-- ---------------------------------------------------------------------
-- B) REMOVE LEGACY ACCESS (driven by the backup rows just written)
-- ---------------------------------------------------------------------

-- B1) Drop legacy policies (non chat_sec_*).
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT schema_name, object_name, detail
             FROM security_backup.phase3b_cutover_backup
            WHERE kind = 'policy' AND restored_at IS NULL
              AND run_at = (SELECT max(run_at) FROM security_backup.phase3b_cutover_backup)
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I',
                   r.detail, r.schema_name, r.object_name);
  END LOOP;
END $$;

-- B2) Revoke broad table privileges, then grant the minimum the JWT path
--     needs. RLS (chat_sec_*) still decides row visibility.
REVOKE ALL ON
  public.chat_conversations, public.chat_messages,
  public.chat_message_reactions, public.chat_translations,
  public.chat_voice_transcriptions, public.chat_message_hidden,
  public.chat_conversation_hidden, public.chat_driver_changes
FROM anon;

REVOKE ALL ON
  public.chat_conversations, public.chat_messages,
  public.chat_message_reactions, public.chat_translations,
  public.chat_voice_transcriptions, public.chat_message_hidden,
  public.chat_conversation_hidden, public.chat_driver_changes
FROM authenticated;

-- Minimum for the JWT path (RLS policies still apply on top):
GRANT SELECT         ON public.chat_conversations      TO authenticated;
GRANT SELECT, INSERT ON public.chat_messages           TO authenticated;
GRANT SELECT         ON public.chat_message_reactions  TO authenticated;
GRANT SELECT         ON public.chat_translations       TO authenticated;
GRANT SELECT (message_id, transcript_text, detected_language, status)
                     ON public.chat_voice_transcriptions TO authenticated;
-- No UPDATE / DELETE for clients: receipts, reactions, deletes are RPC-only.

-- B3) Revoke the legacy client-identity RPCs from anon / authenticated /
--     PUBLIC. Only the *_v2 RPCs remain callable by clients.
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT DISTINCT object_name
             FROM security_backup.phase3b_cutover_backup
            WHERE kind = 'function_grant' AND restored_at IS NULL
              AND run_at = (SELECT max(run_at) FROM security_backup.phase3b_cutover_backup)
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', r.object_name);
  END LOOP;
END $$;

-- ---------------------------------------------------------------------
-- C) POST-CHECKS (abort the whole transaction if anything is still open)
-- ---------------------------------------------------------------------
DO $$
DECLARE v_n integer;
BEGIN
  SELECT count(*) INTO v_n FROM pg_policies
   WHERE schemaname = 'public'
     AND tablename IN ('chat_conversations','chat_messages',
                       'chat_message_reactions','chat_translations',
                       'chat_voice_transcriptions')
     AND policyname NOT LIKE 'chat\_sec\_%' ESCAPE '\';
  IF v_n > 0 THEN
    RAISE EXCEPTION 'Cutover aborted: % non chat_sec_* policy(ies) remain on chat tables', v_n;
  END IF;

  SELECT count(*) INTO v_n FROM pg_policies
   WHERE schemaname = 'storage' AND tablename = 'objects'
     AND policyname NOT LIKE 'chat\_sec\_%' ESCAPE '\'
     AND (COALESCE(qual,'') ILIKE '%chat-voice%' OR COALESCE(with_check,'') ILIKE '%chat-voice%'
          OR COALESCE(qual,'') ILIKE '%chat-files%' OR COALESCE(with_check,'') ILIKE '%chat-files%');
  IF v_n > 0 THEN
    RAISE EXCEPTION 'Cutover aborted: % legacy storage policy(ies) remain', v_n;
  END IF;

  SELECT count(*) INTO v_n FROM information_schema.role_table_grants
   WHERE table_schema = 'public' AND grantee = 'anon'
     AND table_name LIKE 'chat\_%' ESCAPE '\';
  IF v_n > 0 THEN
    RAISE EXCEPTION 'Cutover aborted: anon still has % table privilege(s) on chat tables', v_n;
  END IF;

  SELECT count(*) INTO v_n FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('chat_mark_messages_delivered','chat_mark_messages_read',
          'chat_set_message_reaction','chat_delete_message_for_me',
          'chat_delete_message_for_everyone','chat_delete_conversation_for_me',
          'chat_get_hidden_message_ids','chat_get_hidden_conversations')
     AND has_function_privilege('anon', p.oid, 'EXECUTE');
  IF v_n > 0 THEN
    RAISE EXCEPTION 'Cutover aborted: anon can still execute % legacy RPC(s)', v_n;
  END IF;
END $$;

-- Review the audit trail, then COMMIT (or ROLLBACK to abandon):
--   SELECT kind, count(*) FROM security_backup.phase3b_cutover_backup GROUP BY 1;
COMMIT;

-- =====================================================================
-- REVERT (separate step; run ONLY to undo this cutover)
-- File name when split out: 98b_phase3b_cutover_REVERT_DRAFT.sql
-- Replays the backed-up statements of the most recent cutover run in a
-- safe order: grants first, then policies. It does not touch chat_sec_*
-- objects, so the JWT path keeps working after a revert.
-- =====================================================================
-- BEGIN;
-- DO $$
-- DECLARE r record; v_run timestamptz;
-- BEGIN
--   SELECT max(run_at) INTO v_run FROM security_backup.phase3b_cutover_backup
--    WHERE restored_at IS NULL;
--   IF v_run IS NULL THEN
--     RAISE EXCEPTION 'Nothing to revert (no un-restored cutover backup).';
--   END IF;
--
--   -- 1) table + function grants
--   FOR r IN SELECT id, restore_sql FROM security_backup.phase3b_cutover_backup
--             WHERE run_at = v_run AND restored_at IS NULL
--               AND kind IN ('table_grant','function_grant','column_grant')
--             ORDER BY id
--   LOOP
--     EXECUTE r.restore_sql;
--     UPDATE security_backup.phase3b_cutover_backup SET restored_at = now() WHERE id = r.id;
--   END LOOP;
--
--   -- 2) policies (skip any that already exist, keeps this idempotent)
--   FOR r IN SELECT id, schema_name, object_name, detail, restore_sql
--              FROM security_backup.phase3b_cutover_backup
--             WHERE run_at = v_run AND restored_at IS NULL AND kind = 'policy'
--             ORDER BY id
--   LOOP
--     IF NOT EXISTS (SELECT 1 FROM pg_policies
--                     WHERE schemaname = r.schema_name
--                       AND tablename  = r.object_name
--                       AND policyname = r.detail) THEN
--       EXECUTE r.restore_sql;
--     END IF;
--     UPDATE security_backup.phase3b_cutover_backup SET restored_at = now() WHERE id = r.id;
--   END LOOP;
-- END $$;
-- COMMIT;
--
-- After a revert, ODOO_CHAT_AUTH_ENABLED must be set back to false and
-- the previous app build re-enabled.
--
-- KNOWN LIMITS
--   * The backup captures only privileges that existed as explicit rows
--     in information_schema.role_table_grants. Column-level grants that
--     the cutover replaces are not enumerated; table-level restoration
--     returns them to the broader pre-cutover state.
--   * Policies are restored with their pg_policies text. Run the REVERT
--     in staging first to confirm pg_get_expr output round-trips for the
--     real policies.
--   * Edge Function authorization (P4) is outside SQL and is neither
--     applied nor reverted here.
-- =====================================================================

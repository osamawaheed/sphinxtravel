-- =====================================================================
-- TourOps Smart Chat - restore TEST voice messages that failed with
-- stt_4xx / max_attempts / internal_error / interrupted
-- File: supabase/migrations/tourops_test_voice_stt400_restore.sql
--
-- STATUS: NOT APPLIED. Review, then run manually in the SQL Editor.
-- Apply AFTER deploying the fixed chat-transcribe-message function
-- (the one that defines sniffAudio). Re-running is safe (idempotent).
--
-- Safe by design
--   * NO DELETE. chat_messages rows and chat-voice storage files are never
--     touched, so every original recording stays playable.
--   * Only chat_voice_transcriptions rows that are status='failed' with a
--     known transient/permanent-by-bug error are reset (attempts -> 0,
--     error cleared). The next "Retry" re-claims them.
--   * Limited to the TEST booking conversations.
--   * 'ready' rows (real transcripts) are never modified.
-- =====================================================================

-- 1) Preview what will be reset (read-only).
-- SELECT t.message_id, t.status, t.attempts, t.error_code, t.updated_at
--   FROM public.chat_voice_transcriptions t
--   JOIN public.chat_messages m       ON m.id = t.message_id
--   JOIN public.chat_conversations c  ON c.id = m.conversation_id
--  WHERE upper(trim(c.booking_reference)) = 'RQ.TEST14596'
--    AND t.status = 'failed'
--    AND (t.error_code ~ '^stt_4[0-9]{2}$'
--         OR t.error_code IN ('max_attempts','internal_error','interrupted'));

-- 2) Reset (idempotent).
UPDATE public.chat_voice_transcriptions t
   SET attempts    = 0,
       error_code  = NULL,
       claim_token = NULL,
       updated_at  = now()
  FROM public.chat_messages m
  JOIN public.chat_conversations c ON c.id = m.conversation_id
 WHERE m.id = t.message_id
   AND upper(trim(c.booking_reference)) = 'RQ.TEST14596'
   AND t.status = 'failed'
   AND (t.error_code ~ '^stt_4[0-9]{2}$'
        OR t.error_code IN ('max_attempts', 'internal_error', 'interrupted'))
   AND (t.transcript_text IS NULL OR t.transcript_text = '');

-- 2b) Rows left 'pending' by the crashed attempts (stale claim) are taken
--     over automatically by chat_voice_claim_transcription after 120 s.

-- 3) Verify
-- SELECT message_id, status, attempts, error_code
--   FROM public.chat_voice_transcriptions ORDER BY updated_at DESC LIMIT 20;

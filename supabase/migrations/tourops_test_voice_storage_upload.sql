-- =====================================================================
-- TourOps Smart Chat - Phase 3.1 hotfix (TEST)
-- Allow the app to UPLOAD voice recordings to the PRIVATE chat-voice bucket.
--
-- STATUS: NOT APPLIED. Review, then run manually in the SQL Editor.
--
-- ROOT CAUSE (from the real browser console):
--   StorageException(message: new row violates row-level security policy,
--                    statusCode: 403, error: Unauthorized)
-- The upload to storage.objects is the FIRST step of sending a voice
-- message. storage.objects has RLS enabled and no INSERT policy exists for
-- the anon role on bucket 'chat-voice', so every upload is denied before
-- chat_messages or chat-transcribe-message are ever reached.
--
-- What this adds (and nothing else)
--   * ONE policy: INSERT only, role anon + authenticated, bucket chat-voice.
--   * Path must be '<conversation uuid>/<customer|driver>_<id>_<ts>.<ext>'
--     and the conversation must exist in public.chat_conversations.
--   * Only the audio file extensions the app produces (webm, m4a).
--
-- What this does NOT do
--   * The bucket stays PRIVATE (public = false is not touched).
--   * NO SELECT policy  -> files cannot be listed or downloaded with the anon
--     key. Playback keeps using short-lived signed URLs; the Edge Function
--     reads audio with the service role.
--   * NO UPDATE / DELETE policy -> recordings can never be overwritten
--     or removed by the client (upsert:false is also used by the app).
--   * Existing bucket limits (10 MB, audio MIME allow-list) still apply.
--   * No other table, policy or function is changed.
--
-- TEST ONLY: anon is allowed because the app has no Supabase Auth session
-- yet. Replace with Odoo-token-verified access when production auth lands.
-- =====================================================================

DROP POLICY IF EXISTS "chat_voice_anon_insert" ON storage.objects;

CREATE POLICY "chat_voice_anon_insert"
ON storage.objects
FOR INSERT
TO anon, authenticated
WITH CHECK (
  bucket_id = 'chat-voice'
  AND name ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/(customer|driver)_-?[0-9]+_[0-9]+\.(webm|m4a)$'
  AND EXISTS (
    SELECT 1
    FROM public.chat_conversations c
    WHERE c.id::text = (storage.foldername(name))[1]
  )
);

-- Verification (run manually)
-- SELECT policyname, cmd, roles FROM pg_policies
--  WHERE schemaname = 'storage' AND tablename = 'objects'
--    AND policyname = 'chat_voice_anon_insert';
-- SELECT id, public FROM storage.buckets WHERE id = 'chat-voice';  -- public = false

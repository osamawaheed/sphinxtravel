-- =====================================================================
-- TourOps Smart Chat - Video attachments (TEST)
--
-- STATUS: NOT APPLIED. Review, then run manually in the SQL Editor.
--
-- FINDING: the existing `chat-files` bucket does NOT allow video.
--   * allowed_mime_types has no video/mp4 or video/webm.
--   * The INSERT policy path regex only allows
--     jpg|jpeg|png|webp|gif|heic|pdf|doc|docx|xls|xlsx|txt.
-- Until this migration is applied, MP4/WEBM uploads are rejected by
-- Storage. The Flutter app does not claim video support in that case.
--
-- Changes (and nothing else):
--   1. Adds video/mp4 and video/webm to the bucket MIME allow-list.
--   2. Recreates the SAME INSERT-only policy with mp4|webm added to the
--      extension list. No SELECT / UPDATE / DELETE policy is added: the
--      bucket stays private and files are only reachable through short-lived
--      signed URLs issued by the `chat-file-sign` Edge Function.
--
-- NOT changed: file_size_limit (stays 10 MB - larger videos are rejected),
-- chat-voice bucket, RLS on other tables, AI tables/switches, realtime.
-- No Edge Function change is needed: chat-file-sign signs any stored path.
-- =====================================================================

UPDATE storage.buckets
SET allowed_mime_types = ARRAY[
  'image/jpeg','image/png','image/webp','image/gif','image/heic',
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'text/plain',
  'video/mp4','video/webm'
]
WHERE id = 'chat-files';

DROP POLICY IF EXISTS "chat_files_anon_insert" ON storage.objects;

CREATE POLICY "chat_files_anon_insert"
ON storage.objects
FOR INSERT
TO anon, authenticated
WITH CHECK (
  bucket_id = 'chat-files'
  AND name ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/(customer|driver)_-?[0-9]+_[0-9]+\.(jpg|jpeg|png|webp|gif|heic|pdf|doc|docx|xls|xlsx|txt|mp4|webm)$'
  AND EXISTS (
    SELECT 1
    FROM public.chat_conversations c
    WHERE c.id::text = (storage.foldername(name))[1]
  )
);

-- Verification (run manually)
-- SELECT id, public, file_size_limit, allowed_mime_types
--   FROM storage.buckets WHERE id = 'chat-files';   -- public = false, has video/*
-- SELECT policyname, cmd, roles FROM pg_policies
--  WHERE schemaname='storage' AND tablename='objects'
--    AND policyname='chat_files_anon_insert';        -- cmd = INSERT only

-- =====================================================================
-- TourOps Smart Chat - File attachments (TEST)
--
-- STATUS: NOT APPLIED. Review, then run manually in the SQL Editor.
--
-- Adds, and nothing else:
--   1. PRIVATE storage bucket `chat-files` (public = false, 10 MB limit,
--      MIME allow-list: images, PDF, DOC/DOCX, XLS/XLSX, TXT).
--   2. ONE INSERT-only policy for anon/authenticated on that bucket
--      (same pattern as the approved chat-voice upload policy).
--      NO SELECT / UPDATE / DELETE policy -> files cannot be listed or
--      downloaded with the anon key. Downloads need a short-lived signed
--      URL issued by an Edge Function using the service role.
--   3. Attachment columns on public.chat_messages and an extended
--      message_type CHECK ('text','voice','file').
--
-- Not touched: chat-voice bucket/policies, RLS on other tables, AI tables,
-- AI switches, realtime publication, driver replacement logic.
--
-- TEST ONLY: anon is allowed because the app has no Supabase Auth session
-- yet. Replace with Odoo-token-verified access for production.
-- =====================================================================

-- 1. Private bucket -----------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'chat-files',
  'chat-files',
  false,
  10485760,
  ARRAY[
    'image/jpeg','image/png','image/webp','image/gif','image/heic',
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'text/plain'
  ]
)
ON CONFLICT (id) DO UPDATE
  SET public = false,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

-- 2. Upload-only policy -------------------------------------------------
DROP POLICY IF EXISTS "chat_files_anon_insert" ON storage.objects;

CREATE POLICY "chat_files_anon_insert"
ON storage.objects
FOR INSERT
TO anon, authenticated
WITH CHECK (
  bucket_id = 'chat-files'
  AND name ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/(customer|driver)_-?[0-9]+_[0-9]+\.(jpg|jpeg|png|webp|gif|heic|pdf|doc|docx|xls|xlsx|txt)$'
  AND EXISTS (
    SELECT 1
    FROM public.chat_conversations c
    WHERE c.id::text = (storage.foldername(name))[1]
  )
);

-- 3. Message columns + type check --------------------------------------
ALTER TABLE public.chat_messages
  ADD COLUMN IF NOT EXISTS file_path text,
  ADD COLUMN IF NOT EXISTS file_name text,
  ADD COLUMN IF NOT EXISTS file_mime text,
  ADD COLUMN IF NOT EXISTS file_size_bytes integer;

DO $$
DECLARE
  c record;
BEGIN
  FOR c IN
    SELECT conname
    FROM pg_constraint
    WHERE conrelid = 'public.chat_messages'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) ILIKE '%message_type%'
  LOOP
    EXECUTE format('ALTER TABLE public.chat_messages DROP CONSTRAINT %I', c.conname);
  END LOOP;
END $$;

ALTER TABLE public.chat_messages
  ADD CONSTRAINT chat_messages_message_type_check
  CHECK (message_type = ANY (ARRAY['text'::text, 'voice'::text, 'file'::text]));

-- Verification (run manually)
-- SELECT id, public, file_size_limit FROM storage.buckets WHERE id = 'chat-files'; -- public = false
-- SELECT policyname, cmd, roles FROM pg_policies
--  WHERE schemaname='storage' AND tablename='objects' AND policyname='chat_files_anon_insert';
-- SELECT column_name FROM information_schema.columns
--  WHERE table_name='chat_messages' AND column_name LIKE 'file_%';

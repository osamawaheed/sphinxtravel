-- =====================================================================
-- TourOps: Odoo -> Supabase notification infrastructure (PHASE 1)
-- Project: TourOps-SmartChat (uwllcyhmsletdflnrpcm, eu-west-1)
--
-- STATUS: PREPARED ONLY. NOT EXECUTED. Do not run until explicitly approved.
--
-- Scope: three NEW, separate tables. No existing chat table, RLS policy,
-- function, JWT setting or auth object is touched.
--
-- IDENTITY MODEL (important)
--   The app does NOT use Supabase Auth users for chat. Identity is an
--   Odoo-issued, booking-scoped JWT carrying odoo_user_id + odoo_role
--   ('customer' | 'driver'); `sub` is not a UUID. Therefore a verified
--   notification recipient is the pair (recipient_role, recipient_odoo_id),
--   which is exactly what Odoo sends (customer_odoo_id / driver_odoo_id).
--   Those IDs come from the HMAC-authenticated webhook, not from a client.
--
-- ACCESS MODEL (Phase 1 = fail closed)
--   * RLS enabled on all three tables.
--   * NO policies for anon/authenticated => clients can read/write nothing.
--   * All privileges revoked from PUBLIC, anon, authenticated.
--   * Only service_role (Edge Function) can read/write. service_role
--     bypasses RLS.
--   * App read access is intentionally NOT enabled. See the commented
--     "PHASE 2 (DISABLED)" section at the bottom for the future policy,
--     which must be reviewed and enabled separately.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) odoo_notification_events : raw received webhook events (audit log)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.odoo_notification_events (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id           uuid        NOT NULL,
  schema_version     text        NOT NULL,
  event_type         text        NOT NULL,
  occurred_at        timestamptz NOT NULL,
  source             text        NOT NULL,
  environment        text        NOT NULL,
  booking_id         bigint,
  booking_reference  text,
  trip_id            bigint,
  customer_odoo_id   bigint,
  driver_odoo_id     bigint,
  recipient_roles    text[]      NOT NULL DEFAULT ARRAY[]::text[],
  data               jsonb       NOT NULL DEFAULT '{}'::jsonb,
  received_at        timestamptz NOT NULL DEFAULT now(),
  processing_status  text        NOT NULL DEFAULT 'received',
  processed_at       timestamptz,
  attempt_count      integer     NOT NULL DEFAULT 0,
  last_error         text,
  CONSTRAINT odoo_notification_events_event_id_key UNIQUE (event_id),
  CONSTRAINT odoo_notification_events_status_chk CHECK (
    processing_status IN (
      'received',            -- durably stored, not yet fanned out
      'processed',           -- notifications created
      'pending_recipient',   -- recipient mapping unavailable/blocked
      'suppressed',          -- intentionally no user-facing notification
      'failed'               -- processing error, eligible for retry
    )
  ),
  CONSTRAINT odoo_notification_events_env_chk CHECK (environment IN ('test', 'production'))
);

CREATE INDEX IF NOT EXISTS idx_odoo_notif_events_status
  ON public.odoo_notification_events (processing_status, received_at);
CREATE INDEX IF NOT EXISTS idx_odoo_notif_events_booking
  ON public.odoo_notification_events (booking_id, occurred_at);
CREATE INDEX IF NOT EXISTS idx_odoo_notif_events_trip
  ON public.odoo_notification_events (trip_id, occurred_at);
CREATE INDEX IF NOT EXISTS idx_odoo_notif_events_type
  ON public.odoo_notification_events (event_type, occurred_at);

-- ---------------------------------------------------------------------
-- 2) app_notifications : per-recipient notifications (user-facing)
--    Recipient = (recipient_role, recipient_odoo_id), taken from the
--    authenticated webhook. Text is NOT pre-rendered: the app localizes
--    from notification_type + params (future localization).
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.app_notifications (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_event_id    uuid        NOT NULL
                     REFERENCES public.odoo_notification_events (event_id)
                     ON DELETE CASCADE,
  recipient_role     text        NOT NULL,
  recipient_odoo_id  bigint      NOT NULL,
  notification_type  text        NOT NULL,   -- == Odoo event_type
  category           text        NOT NULL DEFAULT 'general',
  booking_id         bigint,
  booking_reference  text,
  trip_id            bigint,
  params             jsonb       NOT NULL DEFAULT '{}'::jsonb,  -- localization params
  -- Same-transition dedupe key (TRIP_STATUS_CHANGED + specific status event).
  dedupe_key         text,
  is_read            boolean     NOT NULL DEFAULT false,
  read_at            timestamptz,
  occurred_at        timestamptz NOT NULL,
  created_at         timestamptz NOT NULL DEFAULT now(),
  -- Future push delivery bookkeeping (unused in Phase 1).
  push_status        text        NOT NULL DEFAULT 'not_requested',
  push_sent_at       timestamptz,
  CONSTRAINT app_notifications_role_chk CHECK (recipient_role IN ('customer', 'driver')),
  CONSTRAINT app_notifications_push_chk CHECK (
    push_status IN ('not_requested', 'pending', 'sent', 'failed', 'skipped')
  ),
  -- One notification per source event per recipient: retries/concurrency safe.
  CONSTRAINT app_notifications_event_recipient_key
    UNIQUE (source_event_id, recipient_role, recipient_odoo_id)
);

-- One USER-FACING notification per logical transition per recipient.
-- Partial unique index: rows without a dedupe_key are unaffected.
CREATE UNIQUE INDEX IF NOT EXISTS uq_app_notifications_dedupe
  ON public.app_notifications (recipient_role, recipient_odoo_id, dedupe_key)
  WHERE dedupe_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_app_notifications_recipient
  ON public.app_notifications (recipient_role, recipient_odoo_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_app_notifications_unread
  ON public.app_notifications (recipient_role, recipient_odoo_id)
  WHERE is_read = false;

-- ---------------------------------------------------------------------
-- 3) app_push_tokens : RESERVED for future push. Not used in Phase 1.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.app_push_tokens (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_role     text        NOT NULL,
  recipient_odoo_id  bigint      NOT NULL,
  device_id          text        NOT NULL,
  platform           text        NOT NULL,
  token              text        NOT NULL,
  is_active          boolean     NOT NULL DEFAULT true,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  last_seen_at       timestamptz,
  CONSTRAINT app_push_tokens_role_chk CHECK (recipient_role IN ('customer', 'driver')),
  CONSTRAINT app_push_tokens_platform_chk CHECK (platform IN ('ios', 'android', 'web')),
  CONSTRAINT app_push_tokens_device_key UNIQUE (recipient_role, recipient_odoo_id, device_id)
);

CREATE INDEX IF NOT EXISTS idx_app_push_tokens_recipient
  ON public.app_push_tokens (recipient_role, recipient_odoo_id)
  WHERE is_active = true;

-- ---------------------------------------------------------------------
-- 4) Lock everything down (fail closed)
-- ---------------------------------------------------------------------
ALTER TABLE public.odoo_notification_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_notifications        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_push_tokens          ENABLE ROW LEVEL SECURITY;

-- Explicitly drop any policy of the same name (idempotent re-run) and do
-- NOT create any anon/authenticated policy: RLS with zero policies denies
-- all non-bypass roles.
DROP POLICY IF EXISTS "service_role_only_events"        ON public.odoo_notification_events;
DROP POLICY IF EXISTS "service_role_only_notifications" ON public.app_notifications;
DROP POLICY IF EXISTS "service_role_only_push_tokens"   ON public.app_push_tokens;

REVOKE ALL ON public.odoo_notification_events FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.app_notifications        FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.app_push_tokens          FROM PUBLIC, anon, authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.odoo_notification_events TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.app_notifications        TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.app_push_tokens          TO service_role;

-- ---------------------------------------------------------------------
-- 5) Atomic, idempotent ingestion RPC (service_role only)
--    Inserts the event; ON CONFLICT (event_id) DO NOTHING makes concurrent
--    duplicate requests safe. Returns true when this call inserted the row.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.odoo_notif_ingest_event(
  p_event_id          uuid,
  p_schema_version    text,
  p_event_type        text,
  p_occurred_at       timestamptz,
  p_source            text,
  p_environment       text,
  p_booking_id        bigint,
  p_booking_reference text,
  p_trip_id           bigint,
  p_customer_odoo_id  bigint,
  p_driver_odoo_id    bigint,
  p_recipient_roles   text[],
  p_data              jsonb
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $func$
DECLARE
  v_inserted integer;
BEGIN
  INSERT INTO public.odoo_notification_events (
    event_id, schema_version, event_type, occurred_at, source, environment,
    booking_id, booking_reference, trip_id, customer_odoo_id, driver_odoo_id,
    recipient_roles, data
  ) VALUES (
    p_event_id, p_schema_version, p_event_type, p_occurred_at, p_source, p_environment,
    p_booking_id, p_booking_reference, p_trip_id, p_customer_odoo_id, p_driver_odoo_id,
    COALESCE(p_recipient_roles, ARRAY[]::text[]), COALESCE(p_data, '{}'::jsonb)
  )
  ON CONFLICT (event_id) DO NOTHING;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;
  RETURN v_inserted = 1;
END;
$func$;

REVOKE ALL ON FUNCTION public.odoo_notif_ingest_event(
  uuid, text, text, timestamptz, text, text, bigint, text, bigint, bigint, bigint, text[], jsonb
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.odoo_notif_ingest_event(
  uuid, text, text, timestamptz, text, text, bigint, text, bigint, bigint, bigint, text[], jsonb
) TO service_role;

-- =====================================================================
-- PHASE 2 (DISABLED - DO NOT ENABLE WITHOUT SEPARATE APPROVAL)
--
-- Client read access for app_notifications requires a JWT that carries a
-- verified odoo_user_id + odoo_role. The existing chat JWT is
-- booking-scoped (booking_id claim). Before enabling, confirm with the
-- Odoo developer whether a non-booking-scoped identity token is issued
-- (or whether the chat JWT may be reused for the notification inbox).
-- Existing helpers public.chat_sec_jwt_odoo_id() / chat_sec_jwt_role()
-- already read those claims and could be reused READ-ONLY:
--
--   CREATE POLICY "recipient_reads_own_notifications"
--   ON public.app_notifications FOR SELECT TO authenticated
--   USING (
--     public.chat_sec_has_odoo_jwt()
--     AND recipient_role      = public.chat_sec_jwt_role()
--     AND recipient_odoo_id   = public.chat_sec_jwt_odoo_id()
--   );
--   GRANT SELECT ON public.app_notifications TO authenticated;
--
-- Mark-as-read must go through a narrow SECURITY DEFINER RPC that updates
-- only is_read/read_at for the caller's own rows. app_push_tokens must be
-- written only through a similar RPC. Never expose odoo_notification_events.
-- =====================================================================

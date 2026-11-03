-- =====================================================================
-- TourOps: Odoo notification webhook - RETRY SAFETY (PHASE 1 fix)
-- Project: TourOps-SmartChat (uwllcyhmsletdflnrpcm)
--
-- STATUS: PREPARED ONLY. NOT EXECUTED. Run only after explicit approval,
--         and AFTER 20260201000000_odoo_notifications_phase1.sql.
--
-- Problem fixed
--   * A stored event whose notification fan-out failed was marked 'failed'
--     but the webhook still returned HTTP 200, so Odoo stopped retrying.
--   * A repeated event_id always returned "duplicate" without retrying
--     failed / pending_recipient events.
--
-- Approach
--   * All state transitions happen in the database, inside row-locked
--     transactions (SELECT ... FOR UPDATE), so two concurrent requests can
--     never process the same event at once.
--   * A short lease (locked_until) marks "being processed". A crashed worker's
--     lease simply expires and the event can be reclaimed.
--   * Fan-out + status update happen in ONE transaction (atomic).
--   * Notification dedupe is preserved by the existing unique constraint
--     (source_event_id, recipient_role, recipient_odoo_id) and the partial
--     unique index on (recipient_role, recipient_odoo_id, dedupe_key).
--
-- Scope: ONLY the three notification objects. No chat table, RLS policy,
-- JWT setting, auth object or messaging object is touched. Additive only.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Additive columns on odoo_notification_events
-- ---------------------------------------------------------------------
ALTER TABLE public.odoo_notification_events
  ADD COLUMN IF NOT EXISTS locked_until  timestamptz,
  ADD COLUMN IF NOT EXISTS last_attempt_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_odoo_notif_events_retryable
  ON public.odoo_notification_events (processing_status, locked_until)
  WHERE processing_status IN ('received', 'failed', 'pending_recipient');

-- ---------------------------------------------------------------------
-- 2) odoo_notif_claim_event : atomic ingest + claim (row-locked)
--
-- Returns jsonb { "action": "...", "attempt": n }
--   inserted     new event stored and claimed -> caller must fan out
--   retry        existing 'failed'/'received' event claimed -> fan out again
--   recheck      existing 'pending_recipient' event claimed -> re-evaluate
--                recipients using the (newly received) signed payload
--   duplicate    already 'processed'/'suppressed' -> 200 duplicate
--   in_progress  another request holds a fresh lease -> caller returns 5xx
--
-- For non-terminal events the mutable routing fields are refreshed from the
-- latest HMAC-verified payload so a later re-send can supply missing
-- recipient information. Terminal ('processed') rows are never modified.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.odoo_notif_claim_event(
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
  p_data              jsonb,
  p_lease_seconds     integer DEFAULT 60
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $func$
DECLARE
  v_row      public.odoo_notification_events%ROWTYPE;
  v_lease    timestamptz := now() + make_interval(secs => GREATEST(p_lease_seconds, 5));
  v_inserted integer;
BEGIN
  -- Concurrency-safe first insert. Losing racers fall through to the lock.
  INSERT INTO public.odoo_notification_events (
    event_id, schema_version, event_type, occurred_at, source, environment,
    booking_id, booking_reference, trip_id, customer_odoo_id, driver_odoo_id,
    recipient_roles, data, processing_status, attempt_count,
    locked_until, last_attempt_at
  ) VALUES (
    p_event_id, p_schema_version, p_event_type, p_occurred_at, p_source, p_environment,
    p_booking_id, p_booking_reference, p_trip_id, p_customer_odoo_id, p_driver_odoo_id,
    COALESCE(p_recipient_roles, ARRAY[]::text[]), COALESCE(p_data, '{}'::jsonb),
    'received', 1, v_lease, now()
  )
  ON CONFLICT (event_id) DO NOTHING;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;
  IF v_inserted = 1 THEN
    RETURN jsonb_build_object('action', 'inserted', 'attempt', 1);
  END IF;

  -- Existing event: lock the row so concurrent requests serialize here.
  SELECT * INTO v_row
  FROM public.odoo_notification_events
  WHERE event_id = p_event_id
  FOR UPDATE;

  IF NOT FOUND THEN
    -- Extremely unlikely (row deleted between statements). Make Odoo retry.
    RETURN jsonb_build_object('action', 'in_progress', 'attempt', 0);
  END IF;

  IF v_row.processing_status IN ('processed', 'suppressed') THEN
    RETURN jsonb_build_object('action', 'duplicate', 'attempt', v_row.attempt_count);
  END IF;

  -- Another request is actively processing this event (fresh lease).
  IF v_row.locked_until IS NOT NULL AND v_row.locked_until > now() THEN
    RETURN jsonb_build_object('action', 'in_progress', 'attempt', v_row.attempt_count);
  END IF;

  -- Claim for (re)processing. Refresh routing fields from the latest
  -- authenticated payload (event_id / event_type identity never changes).
  UPDATE public.odoo_notification_events
  SET locked_until      = v_lease,
      last_attempt_at   = now(),
      attempt_count     = v_row.attempt_count + 1,
      booking_id        = COALESCE(p_booking_id, booking_id),
      booking_reference = COALESCE(p_booking_reference, booking_reference),
      trip_id           = COALESCE(p_trip_id, trip_id),
      customer_odoo_id  = COALESCE(p_customer_odoo_id, customer_odoo_id),
      driver_odoo_id    = COALESCE(p_driver_odoo_id, driver_odoo_id),
      recipient_roles   = COALESCE(p_recipient_roles, recipient_roles),
      data              = COALESCE(p_data, data)
  WHERE event_id = p_event_id;

  RETURN jsonb_build_object(
    'action',
    CASE WHEN v_row.processing_status = 'pending_recipient' THEN 'recheck' ELSE 'retry' END,
    'attempt', v_row.attempt_count + 1
  );
END;
$func$;

-- ---------------------------------------------------------------------
-- 3) odoo_notif_fanout : atomic fan-out + status update (one transaction)
--
-- p_rows: jsonb array of
--   { recipient_role, recipient_odoo_id, dedupe_key }
-- p_unresolved: roles that could not be resolved (event stays pending)
--
-- Inserts are idempotent: ON CONFLICT DO NOTHING covers BOTH the
-- (source_event_id, recipient_role, recipient_odoo_id) constraint and the
-- partial (recipient, dedupe_key) unique index. Status is set in the same
-- transaction, so there is never a "notifications created but not recorded"
-- or "recorded but not created" state.
--
-- Returns the resulting processing_status.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.odoo_notif_fanout(
  p_event_id   uuid,
  p_rows       jsonb,
  p_unresolved text[] DEFAULT ARRAY[]::text[]
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $func$
DECLARE
  v_ev     public.odoo_notification_events%ROWTYPE;
  v_status text;
BEGIN
  SELECT * INTO v_ev
  FROM public.odoo_notification_events
  WHERE event_id = p_event_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'event not found';
  END IF;

  IF v_ev.processing_status IN ('processed', 'suppressed') THEN
    RETURN v_ev.processing_status;  -- already terminal; nothing to do
  END IF;

  IF p_rows IS NOT NULL AND jsonb_typeof(p_rows) = 'array'
     AND jsonb_array_length(p_rows) > 0 THEN
    INSERT INTO public.app_notifications (
      source_event_id, recipient_role, recipient_odoo_id, notification_type,
      booking_id, booking_reference, trip_id, params, dedupe_key, occurred_at
    )
    SELECT
      v_ev.event_id,
      r->>'recipient_role',
      (r->>'recipient_odoo_id')::bigint,
      v_ev.event_type,
      v_ev.booking_id,
      v_ev.booking_reference,
      v_ev.trip_id,
      v_ev.data,
      NULLIF(r->>'dedupe_key', ''),
      v_ev.occurred_at
    FROM jsonb_array_elements(p_rows) AS r
    ON CONFLICT DO NOTHING;
  END IF;

  IF COALESCE(array_length(p_unresolved, 1), 0) > 0 THEN
    v_status := 'pending_recipient';
  ELSE
    v_status := 'processed';
  END IF;

  UPDATE public.odoo_notification_events
  SET processing_status = v_status,
      processed_at      = CASE WHEN v_status = 'processed' THEN now() ELSE processed_at END,
      locked_until      = NULL,
      last_error        = CASE
                            WHEN v_status = 'pending_recipient'
                              THEN 'unresolved roles: ' || array_to_string(p_unresolved, ',')
                            ELSE NULL
                          END
  WHERE event_id = p_event_id;

  RETURN v_status;
END;
$func$;

-- ---------------------------------------------------------------------
-- 4) odoo_notif_mark_failed : record a failure and release the lease so the
--    next Odoo delivery (HTTP 5xx -> retry) can re-claim immediately.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.odoo_notif_mark_failed(
  p_event_id uuid,
  p_error    text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $func$
BEGIN
  UPDATE public.odoo_notification_events
  SET processing_status = 'failed',
      locked_until      = NULL,
      last_error        = left(COALESCE(p_error, 'fanout error'), 300)
  WHERE event_id = p_event_id
    AND processing_status NOT IN ('processed', 'suppressed');
END;
$func$;

-- ---------------------------------------------------------------------
-- 5) Privileges: service_role only (fail closed)
-- ---------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.odoo_notif_claim_event(
  uuid, text, text, timestamptz, text, text, bigint, text, bigint, bigint, bigint, text[], jsonb, integer
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.odoo_notif_claim_event(
  uuid, text, text, timestamptz, text, text, bigint, text, bigint, bigint, bigint, text[], jsonb, integer
) TO service_role;

REVOKE ALL ON FUNCTION public.odoo_notif_fanout(uuid, jsonb, text[])
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.odoo_notif_fanout(uuid, jsonb, text[]) TO service_role;

REVOKE ALL ON FUNCTION public.odoo_notif_mark_failed(uuid, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.odoo_notif_mark_failed(uuid, text) TO service_role;

-- The Phase 1 ingest RPC (odoo_notif_ingest_event) is left in place but is
-- no longer called by the updated function.

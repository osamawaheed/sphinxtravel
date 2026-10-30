-- =====================================================================
-- TourOps Smart Chat - PHASE 3B / MIGRATION 01 of 03  (REVISION 4)
-- JWT helpers + current-driver assignment state
--
-- STATUS: REVISED FOR REVIEW. NOT DEPLOYED. DO NOT RUN IN PRODUCTION
-- UNTIL APPROVED. Run first in a throwaway / staging Supabase project.
--
-- ADDITIVE AND REVERSIBLE. Safe to apply on a database where revision 1,
-- 2 or 3 was already applied: tables / columns are created with
-- IF NOT EXISTS, functions are CREATE OR REPLACE, and no existing policy,
-- grant or data is changed. (Only superseded chat_sec_* function
-- signatures from earlier revisions are dropped.) Rollback: 99_ROLLBACK.sql.
--
-- WHAT REVISION 4 FIXES (on top of revision 3)
--   A. OLDER EVENT CAN NEVER OVERWRITE NEWER STATE. Revision 3 let a
--      higher sequence win regardless of timestamp, so an event with a
--      higher sequence but an OLDER effective_at could replace newer
--      state. Now chat_sec_try_set_driver applies, in order:
--        Rule A  effective_at < stored driver_changed_at  -> 'stale'
--                (the timestamp high-water mark never moves backwards,
--                 whatever the sequence says);
--        Rule B  both sequences present and sequence/timestamp disagree
--                (newer ts but LOWER seq)  -> 'conflict', state unchanged;
--        Rule C  equal ts, no usable sequence, different driver
--                -> 'conflict'; same driver -> 'same';
--        Rule D  authoritative reads are versioned by observed_at and
--                are the tie-breaker for parked conflicts, but are
--                still subject to Rule A.
--      The sequence is a HIGH-WATER MARK: authoritative / seed writes
--      retain it (GREATEST), so a stale sequenced event cannot sneak in
--      after an authoritative write cleared it (revision 3 set it NULL).
--   B. AUTHORITATIVE RECONCILIATION USES THE GUARDED WRITER.
--      chat_sec_apply_authoritative_driver no longer has its own UPDATE.
--      It takes the same per-booking advisory lock and calls
--      chat_sec_try_set_driver(..., 'authoritative'), so the row lock,
--      the never-regress timestamp rule and the sequence high-water mark
--      apply to it exactly as to the webhook, poller and bootstrap.
--   Tests: supabase/tests/security/run_phase3b_01_tests.mjs
--
-- WHAT REVISION 3 FIXED
--   1. FAIL CLOSED FOR DRIVER VIEWING. chat_sec_can_view no longer allows
--      a driver when current_driver_odoo_id IS NULL. An unknown driver
--      cannot read conversations. A driver can view only when the
--      recorded current driver equals the JWT odoo_user_id.
--   2. EXPLICIT PUBLIC REVOKE ON ALL SECURITY DEFINER FUNCTIONS. Section 8
--      sweeps every public.chat_sec_* function and revokes EXECUTE from PUBLIC, anon and
--      authenticated, then re-grants exactly what is intended. This also
--      repairs a database where revision 1 left the default PUBLIC
--      execute privilege in place. (Migration 02's _v2 RPCs revoke
--      PUBLIC themselves; see the review note about them.)
--   3. NO LEXICOGRAPHIC event_id ORDERING. Event id strings are never
--      compared with < or >. Ordering uses, in this priority:
--        a) a verified numeric sequence from Odoo (p_sequence, e.g. the
--           integer id from GET /chat/assignment-events), compared only
--           with other sequences;
--        b) effective_at;
--        c) if effective_at is EQUAL and no verified sequence orders the
--           two events, the conflict is NOT guessed. The event is
--           recorded with outcome 'conflict' and state is unchanged
--           until chat_sec_apply_authoritative_driver (Odoo's own
--           current driver from GET /chat/bookings/{id}) resolves it.
--   4. WEBHOOK / BOOTSTRAP CANNOT OVERWRITE NEWER STATE. Every state
--      write (webhook, poller, bootstrap seed, replay, authoritative
--      reconcile) goes through ONE function, chat_sec_try_set_driver,
--      which holds a per-booking lock and writes only if the incoming
--      version is strictly newer than the stored version. The bootstrap
--      calls it too; it has no separate unguarded UPDATE.
--
-- EXPECTED JWT CLAIMS (Odoo-issued, HS256, role = authenticated)
--   odoo_user_id : integer
--   odoo_role    : 'customer' | 'driver'
--   booking_id   : integer   (matches chat_conversations.odoo_booking_id)
--   can_view     : boolean   (top level; app_metadata fallback)
--   can_send     : boolean   (top level; app_metadata fallback)
--   `sub` is NOT a uuid, so auth.uid() is never used.
--   Former-driver read-only claims are NOT documented by Odoo and are
--   intentionally NOT implemented (deferred).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Claim readers (SECURITY INVOKER: they only read the request GUC).
--    NULL on missing / malformed claims => every check fails CLOSED.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.chat_sec_claim(p_key text)
RETURNS text
LANGUAGE sql
STABLE
SET search_path = pg_catalog, pg_temp
AS $$
  SELECT COALESCE(
    NULLIF(auth.jwt() ->> p_key, ''),
    NULLIF(auth.jwt() -> 'app_metadata' ->> p_key, '')
  );
$$;

CREATE OR REPLACE FUNCTION public.chat_sec_jwt_booking_id()
RETURNS bigint
LANGUAGE sql
STABLE
SET search_path = pg_catalog, pg_temp
AS $$
  SELECT CASE
    WHEN public.chat_sec_claim('booking_id') ~ '^[0-9]{1,18}$'
    THEN public.chat_sec_claim('booking_id')::bigint
    ELSE NULL
  END;
$$;

CREATE OR REPLACE FUNCTION public.chat_sec_jwt_odoo_id()
RETURNS bigint
LANGUAGE sql
STABLE
SET search_path = pg_catalog, pg_temp
AS $$
  SELECT CASE
    WHEN public.chat_sec_claim('odoo_user_id') ~ '^[0-9]{1,18}$'
    THEN public.chat_sec_claim('odoo_user_id')::bigint
    ELSE NULL
  END;
$$;

CREATE OR REPLACE FUNCTION public.chat_sec_jwt_role()
RETURNS text
LANGUAGE sql
STABLE
SET search_path = pg_catalog, pg_temp
AS $$
  SELECT CASE
    WHEN public.chat_sec_claim('odoo_role') IN ('customer', 'driver')
    THEN public.chat_sec_claim('odoo_role')
    ELSE NULL
  END;
$$;

CREATE OR REPLACE FUNCTION public.chat_sec_jwt_flag(p_key text)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = pg_catalog, pg_temp
AS $$
  SELECT COALESCE(public.chat_sec_claim(p_key) = 'true', false);
$$;

-- True only for a request carrying a valid Odoo chat identity.
CREATE OR REPLACE FUNCTION public.chat_sec_has_odoo_jwt()
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = pg_catalog, pg_temp
AS $$
  SELECT COALESCE(auth.role() = 'authenticated', false)
     AND public.chat_sec_jwt_booking_id() IS NOT NULL
     AND public.chat_sec_jwt_odoo_id()    IS NOT NULL
     AND public.chat_sec_jwt_role()       IS NOT NULL;
$$;

-- ---------------------------------------------------------------------
-- 2) Assignment state (additive). Safe if already applied.
--    NULL current_driver_odoo_id = "unknown" => drivers FAIL CLOSED for
--    BOTH view and send on the JWT path. The legacy anon path is
--    unaffected.
--
--    driver_seq          : HIGH-WATER MARK of the verified Odoo sequence
--                          seen for this conversation. Never lowered or
--                          cleared by any write.
--    driver_state_source : 'event' | 'authoritative' | 'seed'
-- ---------------------------------------------------------------------
ALTER TABLE public.chat_conversations
  ADD COLUMN IF NOT EXISTS current_driver_odoo_id bigint,
  ADD COLUMN IF NOT EXISTS driver_epoch           integer     NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS driver_changed_at      timestamptz,
  ADD COLUMN IF NOT EXISTS driver_event_id        text,
  ADD COLUMN IF NOT EXISTS driver_seq             bigint,
  ADD COLUMN IF NOT EXISTS driver_state_source    text;

CREATE INDEX IF NOT EXISTS chat_conversations_current_driver_idx
  ON public.chat_conversations (current_driver_odoo_id)
  WHERE current_driver_odoo_id IS NOT NULL;

-- Idempotency + audit for webhook / assignment-events deliveries.
-- Server-side only: RLS enabled, NO policies, NO anon/authenticated grants.
CREATE TABLE IF NOT EXISTS public.chat_assignment_events (
  odoo_event_id   text        PRIMARY KEY,
  odoo_booking_id bigint      NOT NULL,
  old_driver_id   bigint,
  new_driver_id   bigint,
  effective_at    timestamptz NOT NULL,
  source          text        NOT NULL DEFAULT 'webhook'
                    CHECK (source IN ('webhook', 'poll', 'manual')),
  applied_at      timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.chat_assignment_events
  ADD COLUMN IF NOT EXISTS outcome text;
ALTER TABLE public.chat_assignment_events
  ADD COLUMN IF NOT EXISTS odoo_sequence bigint;

ALTER TABLE public.chat_assignment_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.chat_assignment_events FROM PUBLIC, anon, authenticated;

-- Replaces the revision-2 index that sorted on the text event id.
DROP INDEX IF EXISTS public.chat_assignment_events_booking_idx;
CREATE INDEX IF NOT EXISTS chat_assignment_events_booking_v3_idx
  ON public.chat_assignment_events (odoo_booking_id, effective_at DESC);

-- ---------------------------------------------------------------------
-- 3) THE SINGLE GUARDED WRITER for driver assignment state.
--    Internal: called by the functions below, never by clients.
--
--    "Newer" (incoming I vs stored S), evaluated in this order:
--      0. S has no state (driver_changed_at IS NULL)  -> I applies
--      A. I.effective_at <  S.driver_changed_at       -> 'stale'
--         (timestamp never regresses; sequence cannot override this)
--      B. both have a sequence:
--           equal                                      -> 'same'
--           I.effective_at >  S ts AND I.seq < S.seq   -> 'conflict'
--           I.effective_at =  S ts AND I.seq < S.seq   -> 'stale'
--           otherwise (higher seq, ts >= S)            -> applies
--      C. equal ts and no sequence on both sides:
--           same driver -> 'same'; different -> 'conflict'
--      D. source 'authoritative' skips B/C (Odoo's own read is the
--         tie-breaker) but is still subject to A.
--      E. a lower sequence than the stored high-water mark -> 'stale';
--         a 'seed' at an equal timestamp -> 'same'.
--      Otherwise the incoming version applies (e.g. a sequence-less
--      event with a strictly newer timestamp is ordered by time alone).
--    Event-id strings are not used for ordering anywhere.
--
--    Returns 'applied' | 'stale' | 'conflict' | 'same'
--    The caller must already hold the per-booking advisory lock; the
--    function also takes a row lock (FOR UPDATE) on the conversation.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.chat_sec_try_set_driver(
  p_conversation_id uuid,
  p_driver_id       bigint,
  p_effective_at    timestamptz,
  p_event_id        text,
  p_sequence        bigint,
  p_source          text
)
RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
  v_cur_driver bigint;
  v_cur_at     timestamptz;
  v_cur_seq    bigint;
  v_cur_src    text;
  v_new_seq    bigint;
BEGIN
  IF p_conversation_id IS NULL OR p_driver_id IS NULL
     OR p_effective_at IS NULL
     OR p_source NOT IN ('event', 'authoritative', 'seed') THEN
    RAISE EXCEPTION 'invalid driver state write';
  END IF;

  -- Row lock: the comparison and the write are one atomic unit, and it
  -- serialises every writer (webhook, poll, bootstrap, authoritative).
  SELECT c.current_driver_odoo_id, c.driver_changed_at, c.driver_seq,
         c.driver_state_source
    INTO v_cur_driver, v_cur_at, v_cur_seq, v_cur_src
    FROM public.chat_conversations c
   WHERE c.id = p_conversation_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'conversation not found';
  END IF;

  IF v_cur_at IS NOT NULL THEN
    -- RULE A: the timestamp high-water mark NEVER moves backwards.
    -- An incoming version older than the stored one is stale no matter
    -- what its sequence says. An older event can therefore never
    -- overwrite newer state (including authoritative state).
    IF p_effective_at < v_cur_at THEN
      RETURN 'stale';
    END IF;

    -- RULE B: the sequence and the timestamp must not disagree.
    -- Newer timestamp but a LOWER sequence (or the reverse) means the
    -- two ordering signals contradict each other. We do not trust one
    -- over the other: park it, leave state unchanged, and let the
    -- authoritative Odoo read resolve it.
    IF p_source = 'authoritative' THEN
      -- RULE D: an authoritative read (Odoo's own current driver) is
      -- the tie-breaker. Reaching this point means observed_at >=
      -- stored driver_changed_at (Rule A already rejected older reads),
      -- so it supersedes any parked conflict or equal-timestamp event.
      -- It still runs under the same row lock and still never lowers
      -- the timestamp or the sequence high-water mark.
      IF v_cur_driver IS NOT DISTINCT FROM p_driver_id
         AND p_effective_at = v_cur_at THEN
        RETURN 'same';
      END IF;
    ELSIF p_sequence IS NOT NULL AND v_cur_seq IS NOT NULL THEN
      IF p_sequence = v_cur_seq THEN
        RETURN 'same';
      END IF;
      IF p_effective_at > v_cur_at AND p_sequence < v_cur_seq THEN
        RETURN 'conflict';
      END IF;
      IF p_effective_at = v_cur_at AND p_sequence < v_cur_seq THEN
        RETURN 'stale';
      END IF;
      -- Remaining cases: sequence higher with timestamp >= stored.
    ELSIF p_effective_at = v_cur_at THEN
      -- RULE C: equal timestamp and no usable sequence on both sides.
      -- Same driver: nothing to resolve. Different driver: do not guess.
      IF v_cur_driver IS NOT DISTINCT FROM p_driver_id THEN
        RETURN 'same';
      END IF;
      RETURN 'conflict';
    END IF;

    -- A lower-sequence event can never win over an existing sequence,
    -- even when the stored row came from an authoritative read that kept
    -- the sequence high-water mark.
    IF p_sequence IS NOT NULL AND v_cur_seq IS NOT NULL
       AND p_sequence < v_cur_seq THEN
      RETURN 'stale';
    END IF;

    -- A seed (bootstrap hint) never replaces existing event/authoritative
    -- state at an equal timestamp.
    IF p_source = 'seed' AND p_effective_at = v_cur_at THEN
      RETURN 'same';
    END IF;
  END IF;

  -- Sequence is a high-water mark: authoritative / seed writes carry no
  -- sequence of their own and RETAIN the stored one, so a later stale
  -- sequenced event is still rejected.
  v_new_seq := CASE
    WHEN p_sequence IS NULL THEN v_cur_seq
    WHEN v_cur_seq  IS NULL THEN p_sequence
    ELSE GREATEST(v_cur_seq, p_sequence)
  END;

  UPDATE public.chat_conversations
     SET current_driver_odoo_id = p_driver_id,
         driver_epoch           = driver_epoch + 1,
         driver_changed_at      = p_effective_at,
         driver_event_id        = COALESCE(p_event_id, driver_event_id),
         driver_seq             = v_new_seq,
         driver_state_source    = p_source
   WHERE id = p_conversation_id;

  RETURN 'applied';
END;
$$;

-- ---------------------------------------------------------------------
-- 4) Apply an assignment event (webhook / assignment-events poller).
--    Called ONLY by a service-role Edge Function that has verified the
--    X-TourOps-Signature HMAC.
--
--    p_sequence: the verified numeric ordering value from Odoo (the
--    integer id of the row in GET /chat/assignment-events, if Odoo
--    confirms it is monotonic per booking). Pass NULL when it is not
--    verified; the function then falls back to effective_at and parks
--    same-timestamp conflicts instead of guessing.
--
--    Returns: 'applied' | 'duplicate' | 'stale' | 'conflict' | 'same'
--             | 'no_conversation'
-- ---------------------------------------------------------------------
-- Drop the revision-1/2 signature (6 args, no sequence) so the old
-- lexicographic version cannot be called by mistake. This only removes a
-- not-yet-deployed function created by earlier revisions of THIS file.
DROP FUNCTION IF EXISTS public.chat_sec_apply_assignment_event(
  text, bigint, bigint, bigint, timestamptz, text);

CREATE OR REPLACE FUNCTION public.chat_sec_apply_assignment_event(
  p_event_id        text,
  p_odoo_booking_id bigint,
  p_old_driver_id   bigint,
  p_new_driver_id   bigint,
  p_effective_at    timestamptz,
  p_sequence        bigint DEFAULT NULL,
  p_source          text   DEFAULT 'webhook'
)
RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
  v_conv     uuid;
  v_prev     bigint;
  v_inserted integer;
  v_source   text;
  v_result   text;
BEGIN
  IF p_event_id IS NULL OR btrim(p_event_id) = ''
     OR p_odoo_booking_id IS NULL
     OR p_new_driver_id IS NULL
     OR p_effective_at IS NULL THEN
    RAISE EXCEPTION 'invalid assignment event';
  END IF;

  v_source := CASE WHEN p_source IN ('webhook', 'poll', 'manual')
                   THEN p_source ELSE 'webhook' END;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtext('chat_sec_assignment'),
    pg_catalog.hashtext(p_odoo_booking_id::text)
  );

  INSERT INTO public.chat_assignment_events
    (odoo_event_id, odoo_booking_id, old_driver_id, new_driver_id,
     effective_at, source, outcome, odoo_sequence)
  VALUES
    (p_event_id, p_odoo_booking_id, p_old_driver_id, p_new_driver_id,
     p_effective_at, v_source, 'received', p_sequence)
  ON CONFLICT (odoo_event_id) DO NOTHING;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;
  IF v_inserted = 0 THEN
    RETURN 'duplicate';
  END IF;

  SELECT c.id, c.current_driver_odoo_id
    INTO v_conv, v_prev
    FROM public.chat_conversations c
   WHERE c.odoo_booking_id = p_odoo_booking_id;

  IF v_conv IS NULL THEN
    UPDATE public.chat_assignment_events
       SET outcome = 'no_conversation'
     WHERE odoo_event_id = p_event_id;
    RETURN 'no_conversation';
  END IF;

  v_result := public.chat_sec_try_set_driver(
    v_conv, p_new_driver_id, p_effective_at, p_event_id, p_sequence, 'event');

  IF v_result = 'applied' AND v_prev IS DISTINCT FROM p_new_driver_id THEN
    -- new_driver_name is NOT NULL in the live table; Odoo sends no name.
    INSERT INTO public.chat_driver_changes
      (conversation_id, previous_driver_odoo_id, new_driver_odoo_id,
       new_driver_name, changed_at)
    VALUES
      (v_conv, COALESCE(p_old_driver_id, v_prev), p_new_driver_id,
       '', p_effective_at);
  END IF;

  UPDATE public.chat_assignment_events
     SET outcome = v_result
   WHERE odoo_event_id = p_event_id;

  RETURN v_result;
END;
$$;

-- ---------------------------------------------------------------------
-- 5) Authoritative reconcile. The Edge Function reads Odoo's CURRENT
--    driver (GET /chat/bookings/{id}, server-to-server) and passes it
--    here. This is the only way to resolve a 'conflict', and the
--    recommended path for the bootstrap and a periodic backstop.
--
--    p_observed_at is the time the Edge Function READ Odoo. It is
--    versioned like any other write and goes through
--    chat_sec_try_set_driver (source 'authoritative'), so a read older
--    than stored state returns 'stale' and can never overwrite a newer
--    webhook event. A read at or after the stored timestamp applies and
--    resolves a parked 'conflict'. The stored sequence high-water mark
--    is retained, never cleared.
--
--    Returns 'applied' | 'stale' | 'same' | 'no_conversation'
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.chat_sec_apply_authoritative_driver(
  p_odoo_booking_id bigint,
  p_driver_id       bigint,
  p_observed_at     timestamptz
)
RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
  v_conv   uuid;
BEGIN
  IF p_odoo_booking_id IS NULL OR p_driver_id IS NULL
     OR p_observed_at IS NULL THEN
    RAISE EXCEPTION 'invalid authoritative driver';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtext('chat_sec_assignment'),
    pg_catalog.hashtext(p_odoo_booking_id::text)
  );

  SELECT c.id INTO v_conv
    FROM public.chat_conversations c
   WHERE c.odoo_booking_id = p_odoo_booking_id;

  IF v_conv IS NULL THEN
    RETURN 'no_conversation';
  END IF;

  -- NO direct UPDATE here. The authoritative read is versioned by
  -- observed_at and goes through the SAME guarded writer as every other
  -- source, so the per-booking advisory lock, the row lock, the
  -- never-regress timestamp rule and the sequence high-water mark all
  -- apply. A read older than stored state returns 'stale'.
  RETURN public.chat_sec_try_set_driver(
    v_conv, p_driver_id, p_observed_at, NULL, NULL, 'authoritative');
END;
$$;

-- ---------------------------------------------------------------------
-- 6) Server-side conversation bootstrap. Service role only.
--
--    NEVER overwrites assignment state. It has NO UPDATE of its own on
--    driver columns:
--      * a new row is created WITHOUT a driver;
--      * the newest parked 'no_conversation' event (highest verified
--        sequence, else latest effective_at; a same-timestamp tie with
--        no sequence is not guessed and is left for the authoritative
--        reconcile) is replayed through chat_sec_try_set_driver;
--      * the optional driver hint from Odoo is applied through
--        chat_sec_try_set_driver with source 'seed' at p_observed_at,
--        so a newer webhook event that already exists always wins.
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.chat_sec_ensure_conversation(bigint, text, bigint);

CREATE OR REPLACE FUNCTION public.chat_sec_ensure_conversation(
  p_odoo_booking_id   bigint,
  p_booking_reference text,
  p_current_driver_id bigint      DEFAULT NULL,
  p_observed_at       timestamptz DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
  v_id      uuid;
  v_created boolean := false;
  v_ev      record;
BEGIN
  IF p_odoo_booking_id IS NULL
     OR p_booking_reference IS NULL
     OR btrim(p_booking_reference) = '' THEN
    RAISE EXCEPTION 'booking id and reference required';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtext('chat_sec_assignment'),
    pg_catalog.hashtext(p_odoo_booking_id::text)
  );

  SELECT c.id INTO v_id
    FROM public.chat_conversations c
   WHERE c.odoo_booking_id = p_odoo_booking_id;

  IF v_id IS NULL THEN
    INSERT INTO public.chat_conversations (odoo_booking_id, booking_reference)
    VALUES (p_odoo_booking_id, p_booking_reference)
    ON CONFLICT (odoo_booking_id) DO NOTHING
    RETURNING id INTO v_id;

    IF v_id IS NULL THEN
      SELECT c.id INTO v_id
        FROM public.chat_conversations c
       WHERE c.odoo_booking_id = p_odoo_booking_id;
    ELSE
      v_created := true;
    END IF;
  END IF;

  -- Replay the newest parked event. Order: verified sequence, then
  -- effective_at. NO ordering by the text event id.
  IF v_created THEN
    SELECT e.odoo_event_id, e.new_driver_id, e.effective_at, e.odoo_sequence
      INTO v_ev
      FROM public.chat_assignment_events e
     WHERE e.odoo_booking_id = p_odoo_booking_id
       AND e.outcome = 'no_conversation'
     ORDER BY e.odoo_sequence DESC NULLS LAST, e.effective_at DESC
     LIMIT 1;

    IF FOUND THEN
      PERFORM public.chat_sec_try_set_driver(
        v_id, v_ev.new_driver_id, v_ev.effective_at,
        v_ev.odoo_event_id, v_ev.odoo_sequence, 'event');

      UPDATE public.chat_assignment_events
         SET outcome = 'replayed'
       WHERE odoo_booking_id = p_odoo_booking_id
         AND outcome = 'no_conversation';
    END IF;
  END IF;

  -- Driver hint from Odoo: guarded writer only, versioned by the time
  -- Odoo was read. Never blind-overwrites a newer event.
  IF p_current_driver_id IS NOT NULL AND p_observed_at IS NOT NULL THEN
    PERFORM public.chat_sec_try_set_driver(
      v_id, p_current_driver_id, p_observed_at, NULL, NULL, 'seed');
  END IF;

  RETURN v_id;
END;
$$;

-- ---------------------------------------------------------------------
-- 7) Per-conversation authorization predicates. FAIL CLOSED.
--
--    DRIVER (view AND send): allowed only when
--        c.current_driver_odoo_id IS NOT NULL
--        AND c.current_driver_odoo_id = JWT odoo_user_id.
--    An unknown (NULL) driver cannot read or write. A replaced driver is
--    blocked the moment the guarded writer commits, even with an
--    unexpired JWT.
--
--    CUSTOMER: booking claim must match. The DB has no Odoo
--    booking-status feed, so a revoked booking stays accessible until
--    the JWT expires (<= 15 min) unless Odoo refuses to refresh.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.chat_sec_can_view(p_conversation_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
  SELECT public.chat_sec_has_odoo_jwt()
     AND public.chat_sec_jwt_flag('can_view')
     AND EXISTS (
       SELECT 1
         FROM public.chat_conversations c
        WHERE c.id = p_conversation_id
          AND c.odoo_booking_id = public.chat_sec_jwt_booking_id()
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

-- ---------------------------------------------------------------------
-- 8) EXECUTE PERMISSIONS - explicit, and a sweep that also repairs a
--    database where revision 1 / 2 was applied.
--
--    Step A: revoke EXECUTE from PUBLIC, anon and authenticated on EVERY
--            function in public whose name starts with chat_sec_ (all
--            SECURITY DEFINER helpers, whatever their signature, so
--            leftover revision 1 / 2 signatures are covered). Postgres grants
--            EXECUTE to PUBLIC by default on CREATE FUNCTION, and
--            CREATE OR REPLACE does not remove a privilege that is
--            already there, so this must be explicit.
--    Step B: grant back exactly what is intended.
-- ---------------------------------------------------------------------
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS sig
      FROM pg_catalog.pg_proc p
      JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname LIKE 'chat\_sec\_%' ESCAPE '\'
  LOOP
    EXECUTE format(
      'REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', r.sig);
  END LOOP;
END
$$;

-- Service-role only: state writers and bootstrap.
GRANT EXECUTE ON FUNCTION public.chat_sec_try_set_driver(
  uuid, bigint, timestamptz, text, bigint, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.chat_sec_apply_assignment_event(
  text, bigint, bigint, bigint, timestamptz, bigint, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.chat_sec_apply_authoritative_driver(
  bigint, bigint, timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.chat_sec_ensure_conversation(
  bigint, text, bigint, timestamptz) TO service_role;

-- Claim readers / predicates: authenticated + service_role only.
-- (anon carries no Odoo JWT, so these would only ever return false.)
GRANT EXECUTE ON FUNCTION public.chat_sec_claim(text)            TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.chat_sec_jwt_booking_id()       TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.chat_sec_jwt_odoo_id()          TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.chat_sec_jwt_role()             TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.chat_sec_jwt_flag(text)         TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.chat_sec_has_odoo_jwt()         TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.chat_sec_can_view(uuid)         TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.chat_sec_can_send(uuid)         TO authenticated, service_role;

-- NOTE: the sweep is limited to chat_sec_* functions. The migration-02
-- *_v2 RPCs already REVOKE FROM PUBLIC, anon and GRANT TO authenticated
-- inside migration 02 itself, so they are not touched here.

-- ---------------------------------------------------------------------
-- Verification (run manually in staging after applying)
-- -- 1. No SECURITY DEFINER function in public is executable by PUBLIC/anon
-- SELECT p.oid::regprocedure AS fn, p.prosecdef, p.proconfig,
--        has_function_privilege('anon',         p.oid, 'EXECUTE') AS anon_x,
--        has_function_privilege('authenticated',p.oid, 'EXECUTE') AS auth_x,
--        has_function_privilege('service_role', p.oid, 'EXECUTE') AS svc_x,
--        EXISTS (SELECT 1 FROM aclexplode(COALESCE(p.proacl,
--                  acldefault('f', p.proowner))) a
--                 WHERE a.grantee = 0 AND a.privilege_type = 'EXECUTE') AS public_x
--   FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
--  WHERE n.nspname = 'public' AND p.proname LIKE 'chat\_sec\_%' ESCAPE '\'
--  ORDER BY 1;                         -- public_x must be false everywhere
-- -- 2. Driver fail-closed: conversation with current_driver_odoo_id NULL
-- --    -> chat_sec_can_view(...) = false for a driver JWT.
-- -- 3. Ordering: run the automated suite
-- --    supabase/tests/security/run_phase3b_01_tests.mjs (PGlite, isolated).
-- --    Expected outcomes:
-- --    same event id twice                          -> applied, duplicate
-- --    older effective_at (any sequence)            -> stale
-- --    newer ts but LOWER sequence                  -> conflict (kept)
-- --    equal ts, no sequence, different driver      -> conflict (kept)
-- --    authoritative read older than stored         -> stale
-- --    authoritative read newer/equal               -> applied
-- --    bootstrap hint older than stored             -> stale
-- ---------------------------------------------------------------------

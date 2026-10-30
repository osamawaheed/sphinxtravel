// Isolated automated tests for Phase 3B Migration 01 (Revision 4).
//
// Runs against PGlite: real PostgreSQL (WASM) in memory. It never opens a
// connection to any remote database, so production cannot be touched.
//
// It loads the REAL migration file from disk (nothing is re-typed), applies it
// twice (idempotency), runs the scenarios, then applies the rollback script.
//
// Usage, from any scratch directory:
//   npm i @electric-sql/pglite
//   node run_phase3b_01_tests.mjs <path-to-repo-root>
//
// LIMITATION: PGlite is a single-connection engine. These tests prove ordering,
// idempotency, authorization and permission logic. They do NOT exercise true
// parallel transactions; the advisory/row-lock concurrency protection must be
// verified separately on a throwaway Postgres with two real sessions.
import { PGlite } from '@electric-sql/pglite';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = process.argv[2] || '.';
const read = (p) => readFileSync(join(root, p), 'utf8');
const mig = read('supabase/migrations/security/20260101_phase3b_01_jwt_helpers_assignment.sql');
const rollback = read('supabase/migrations/security/20260101_phase3b_99_ROLLBACK.sql');

// Live table shapes (from Supabase list_tables) - only what Migration 01 uses.
const BOOT = `
CREATE ROLE anon NOLOGIN; CREATE ROLE authenticated NOLOGIN; CREATE ROLE service_role NOLOGIN;
CREATE SCHEMA auth;
CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS $$
  SELECT COALESCE(NULLIF(current_setting('request.jwt.claims', true), ''), '{}')::jsonb $$;
CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS $$
  SELECT (COALESCE(NULLIF(current_setting('request.jwt.claims', true), ''), '{}')::jsonb ->> 'role')::text $$;
GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role;
CREATE TABLE public.chat_conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  odoo_booking_id bigint NOT NULL UNIQUE,
  booking_reference text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.chat_driver_changes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES public.chat_conversations(id),
  previous_driver_odoo_id bigint,
  new_driver_odoo_id bigint NOT NULL,
  new_driver_name text NOT NULL,
  changed_at timestamptz NOT NULL DEFAULT now());
ALTER TABLE public.chat_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_driver_changes ENABLE ROW LEVEL SECURITY;`;

const db = new PGlite();
await db.exec(BOOT);
await db.exec(mig); console.log('apply #1 ok');
await db.exec(mig); console.log('apply #2 (idempotent) ok');

const T0 = '2026-01-01T10:00:00Z';
const at = (min) => new Date(Date.parse(T0) + min * 60000).toISOString();
let pass = 0, fail = 0; const failures = [];
const check = (name, actual, expected) => {
  const ok = String(actual) === String(expected);
  ok ? pass++ : (fail++, failures.push(`${name}: expected=${expected} actual=${actual}`));
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${ok ? '' : `   [expected=${expected} actual=${actual}]`}`);
};
const q = async (sql, p = []) => (await db.query(sql, p)).rows;
const ev = async (id, bk, nd, min, seq = null, od = null) =>
  (await q(`SELECT public.chat_sec_apply_assignment_event($1,$2,$3,$4,$5::timestamptz,$6,'webhook') r`, [id, bk, od, nd, at(min), seq]))[0].r;
const auth = async (bk, d, min) => (await q(`SELECT public.chat_sec_apply_authoritative_driver($1,$2,$3::timestamptz) r`, [bk, d, at(min)]))[0].r;
const mk = async (bk, d = null, min = null) =>
  (await q(`SELECT public.chat_sec_ensure_conversation($1,$2,$3,$4::timestamptz) r`, [bk, 'REF-' + bk, d, min === null ? null : at(min)]))[0].r;
const drv = async (bk) => (await q(`SELECT current_driver_odoo_id d FROM public.chat_conversations WHERE odoo_booking_id=$1`, [bk]))[0]?.d ?? null;
const claims = (o) => db.exec(`SELECT set_config('request.jwt.claims', '${JSON.stringify(o)}', false)`);
const can = async (fn, id) => (await q(`SELECT public.${fn}($1::uuid) r`, [id]))[0].r;
const convId = async (bk) => (await q(`SELECT id FROM public.chat_conversations WHERE odoo_booking_id=$1`, [bk]))[0].id;
const row = async (bk) => (await q(`SELECT * FROM public.chat_conversations WHERE odoo_booking_id=$1`, [bk]))[0];

console.log('\n== A. DUPLICATE EVENTS ==');
await mk(1001);
check('A1 first delivery applied', await ev('e-1', 1001, 11, 0, 1), 'applied');
check('A2 exact duplicate ignored', await ev('e-1', 1001, 11, 0, 1), 'duplicate');
check('A3 duplicate id with different payload ignored', await ev('e-1', 1001, 99, 60, 9), 'duplicate');
check('A4 driver unchanged', await drv(1001), 11);
check('A5 duplicates wrote no extra audit rows', (await q(`SELECT count(*)::int n FROM public.chat_driver_changes d JOIN public.chat_conversations c ON c.id=d.conversation_id WHERE c.odoo_booking_id=1001`))[0].n, 1);
check('A6 event row stored once', (await q(`SELECT count(*)::int n FROM public.chat_assignment_events WHERE odoo_event_id='e-1'`))[0].n, 1);
const ep = (await row(1001)).driver_epoch;
await ev('e-1', 1001, 11, 0, 1);
check('A7 duplicate does not bump driver_epoch', (await row(1001)).driver_epoch, ep);

console.log('\n== B. DELAYED WEBHOOKS ==');
await mk(1002);
check('B1 drv21 t0 seq5 applied', await ev('b-1', 1002, 21, 0, 5), 'applied');
check('B2 drv22 t+10 seq6 applied', await ev('b-2', 1002, 22, 10, 6), 'applied');
check('B3 delayed older event (new id) stale', await ev('b-3', 1002, 21, 0, 5), 'stale');
check('B4 delayed older ts, no seq, stale', await ev('b-4', 1002, 21, 5, null), 'stale');
check('B5 current driver still 22', await drv(1002), 22);
check('B6 stale outcome recorded', (await q(`SELECT outcome o FROM public.chat_assignment_events WHERE odoo_event_id='b-4'`))[0].o, 'stale');

console.log('\n== C. CONFLICTING TIMESTAMPS / SEQUENCES / AUTHORITATIVE ==');
await mk(1003); await ev('c-1', 1003, 31, 10, 10);
check('C1 HIGHER seq + OLDER ts cannot overwrite (stale)', await ev('c-2', 1003, 32, 0, 99), 'stale');
check('C2 driver unchanged', await drv(1003), 31);
check('C3 NEWER ts + LOWER seq parked as conflict', await ev('c-3', 1003, 33, 20, 3), 'conflict');
check('C4 driver unchanged after conflict', await drv(1003), 31);
await mk(1004); await ev('c-4', 1004, 41, 0, null);
check('C5 equal ts, no seq, different driver = conflict', await ev('c-5', 1004, 42, 0, null), 'conflict');
check('C6 equal ts, no seq, same driver = same', await ev('c-6', 1004, 41, 0, null), 'same');
check('C7 driver unchanged', await drv(1004), 41);
await mk(1005); await ev('c-7', 1005, 51, 0, 10);
check('C8 equal ts + higher seq applied', await ev('c-8', 1005, 52, 0, 11), 'applied');
check('C9 equal ts + lower seq stale', await ev('c-9', 1005, 53, 0, 9), 'stale');
check('C10 driver is 52', await drv(1005), 52);
check('C11 authoritative resolves parked conflict', await auth(1004, 42, 0.01), 'applied');
check('C12 driver now 42', await drv(1004), 42);
check('C13 OLDER authoritative read is stale', await auth(1004, 41, -60), 'stale');
check('C14 driver still 42', await drv(1004), 42);
await mk(1006); await ev('c-10', 1006, 61, 0, 20); await auth(1006, 62, 30);
check('C15 authoritative applied', await drv(1006), 62);
check('C16 old sequenced event stale after authoritative', await ev('c-11', 1006, 61, 5, 21), 'stale');
check('C17 seq high-water retained through authoritative write', (await row(1006)).driver_seq, 20);
check('C18 driver still 62', await drv(1006), 62);
check('C19 stored ts never lowered', (await q(`SELECT (driver_changed_at >= $1::timestamptz) b FROM public.chat_conversations WHERE odoo_booking_id=1006`, [at(30)]))[0].b, true);
check('C20 event at same ts as authoritative state = conflict', await ev('c-12', 1006, 63, 30, null), 'conflict');
check('C21 driver still 62', await drv(1006), 62);
check('C22 newer ts + higher seq applies after authoritative', await ev('c-13', 1006, 64, 40, 25), 'applied');
check('C23 authoritative state recorded its source', (await row(1004)).driver_state_source, 'authoritative');
await mk(1007); await ev('c-14', 1007, 71, 0, 10);
check('C24 no-seq event with strictly newer ts applies (time-only ordering)', await ev('c-15', 1007, 72, 5, null), 'applied');
check('C25 ...and seq high-water is retained', (await row(1007)).driver_seq, 10);
check('C26 authoritative same driver same ts = same (no epoch bump)', await (async () => { const e = (await row(1007)).driver_epoch; const r = await auth(1007, 72, 5); return `${r}/${(await row(1007)).driver_epoch === e}`; })(), 'same/true');

console.log('\n== D. BOOTSTRAP ==');
check('D1 event before conversation = no_conversation', await ev('d-1', 1010, 71, 0, 1), 'no_conversation');
await mk(1010);
check('D2 parked event replayed -> driver 71', await drv(1010), 71);
check('D3 parked event marked replayed', (await q(`SELECT outcome o FROM public.chat_assignment_events WHERE odoo_event_id='d-1'`))[0].o, 'replayed');
await mk(1010, 99, -60);
check('D4 OLDER bootstrap hint cannot overwrite', await drv(1010), 71);
await mk(1010, 72, 60);
check('D5 NEWER bootstrap hint applies (seed)', await drv(1010), 72);
await mk(1011); await ev('d-2', 1011, 81, 0, 4); await mk(1011, 82, 0);
check('D6 equal-ts seed does not replace event state', await drv(1011), 81);
await mk(1011);
check('D7 re-bootstrap leaves driver', await drv(1011), 81);
check('D8 one conversation per booking', (await q(`SELECT count(*)::int n FROM public.chat_conversations WHERE odoo_booking_id=1011`))[0].n, 1);
await ev('d-3', 1012, 91, 0, 1); await ev('d-4', 1012, 92, 5, 2); await mk(1012);
check('D9 newest parked event wins on bootstrap', await drv(1012), 92);
await mk(1013);
check('D10 new conversation has NULL driver', await drv(1013), null);
await mk(1014); await ev('d-5', 1014, 101, 30, 7); await mk(1014, 100, 10);
check('D11 stale bootstrap hint after webhook cannot overwrite', await drv(1014), 101);

console.log('\n== E. DRIVER REVOCATION / AUTHORIZATION ==');
await mk(1020); await ev('r-1', 1020, 101, 0, 1);
const c20 = await convId(1020);
const dc = (id, bk = 1020) => ({ role: 'authenticated', booking_id: bk, odoo_user_id: id, odoo_role: 'driver', can_view: true, can_send: true });
await claims(dc(101));
check('E1 current driver can view', await can('chat_sec_can_view', c20), true);
check('E2 current driver can send', await can('chat_sec_can_send', c20), true);
await claims({});
check('E3 replacement event applied', await ev('r-2', 1020, 102, 60, 2, 101), 'applied');
await claims(dc(101));
check('E4 OLD driver loses view immediately (unexpired JWT)', await can('chat_sec_can_view', c20), false);
check('E5 OLD driver loses send immediately', await can('chat_sec_can_send', c20), false);
await claims(dc(102));
check('E6 NEW driver can view', await can('chat_sec_can_view', c20), true);
check('E7 NEW driver can send', await can('chat_sec_can_send', c20), true);
await claims({});
check('E8 delayed event re-naming old driver is stale', await ev('r-3', 1020, 101, 10, 1), 'stale');
await claims(dc(101));
check('E9 old driver still blocked after delayed event', await can('chat_sec_can_view', c20), false);
await claims({});
check('E10 stale authoritative read of old driver cannot re-grant', await auth(1020, 101, -5), 'stale');
await claims(dc(101));
check('E11 old driver still blocked after stale authoritative', await can('chat_sec_can_send', c20), false);
const c13 = await convId(1013);
await claims(dc(101, 1013));
check('E12 NULL current driver: driver CANNOT view (fail closed)', await can('chat_sec_can_view', c13), false);
check('E13 NULL current driver: driver CANNOT send', await can('chat_sec_can_send', c13), false);
await claims({ role: 'authenticated', booking_id: 1020, odoo_user_id: 5, odoo_role: 'customer', can_view: true, can_send: true });
check('E14 customer can view own booking', await can('chat_sec_can_view', c20), true);
await claims({ role: 'authenticated', booking_id: 9999, odoo_user_id: 5, odoo_role: 'customer', can_view: true, can_send: true });
check('E15 customer with other booking denied', await can('chat_sec_can_view', c20), false);
await claims({ role: 'authenticated', booking_id: 1020, odoo_user_id: 5, odoo_role: 'customer', can_view: false, can_send: true });
check('E16 can_view=false denied', await can('chat_sec_can_view', c20), false);
await claims({ role: 'authenticated', booking_id: 1020, odoo_user_id: 5, odoo_role: 'customer', can_view: true, can_send: false });
check('E17 can_send=false: cannot send, can view', `${await can('chat_sec_can_send', c20)}/${await can('chat_sec_can_view', c20)}`, 'false/true');
await claims({ role: 'anon' });
check('E18 anon role denied', await can('chat_sec_can_view', c20), false);
await claims({});
check('E19 no claims denied', await can('chat_sec_can_view', c20), false);

console.log('\n== F. EXECUTE PERMISSIONS / SEARCH PATH ==');
const fns = await q(`SELECT p.oid::regprocedure::text sig, p.prosecdef sd, p.proconfig cfg,
  EXISTS (SELECT 1 FROM aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a WHERE a.grantee=0 AND a.privilege_type='EXECUTE') pub,
  has_function_privilege('anon', p.oid,'EXECUTE') anon_x, has_function_privilege('authenticated', p.oid,'EXECUTE') auth_x,
  has_function_privilege('service_role', p.oid,'EXECUTE') svc_x
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname LIKE 'chat\\_sec\\_%' ESCAPE '\\' ORDER BY 1`);
check('F0 number of chat_sec_* functions', fns.length, 12);
const writers = ['chat_sec_try_set_driver', 'chat_sec_apply_assignment_event', 'chat_sec_apply_authoritative_driver', 'chat_sec_ensure_conversation'];
for (const f of fns) {
  check(`F PUBLIC cannot execute ${f.sig}`, f.pub, false);
  check(`F anon cannot execute ${f.sig}`, f.anon_x, false);
  check(`F service_role can execute ${f.sig}`, f.svc_x, true);
  if (writers.some((w) => f.sig.startsWith('public.' + w))) check(`F authenticated cannot execute writer ${f.sig}`, f.auth_x, false);
  if (f.sd) check(`F safe search_path on SECURITY DEFINER ${f.sig}`, (f.cfg || []).some((c) => c.startsWith('search_path=pg_catalog')), true);
}
check('F assignment_events not readable by authenticated', (await q(`SELECT has_table_privilege('authenticated','public.chat_assignment_events','SELECT') b`))[0].b, false);

console.log('\n== G. ROLLBACK ==');
await db.exec(rollback);
check('G1 rollback removes all chat_sec_* functions', (await q(`SELECT count(*)::int n FROM pg_proc WHERE proname LIKE 'chat\\_sec\\_%' ESCAPE '\\'`))[0].n, 0);
check('G2 rollback keeps assignment data (non-destructive)', (await q(`SELECT count(*)::int n FROM public.chat_assignment_events`))[0].n > 0, true);
await db.exec(rollback);
check('G3 rollback is re-runnable', true, true);
await db.exec(mig);
check('G4 migration re-applies after rollback', (await q(`SELECT count(*)::int n FROM pg_proc WHERE proname LIKE 'chat\\_sec\\_%' ESCAPE '\\'`))[0].n, 12);

console.log(`\nTOTAL ${pass + fail}  PASS ${pass}  FAIL ${fail}`);
if (fail) console.log('FAILURES:\n' + failures.join('\n'));
await db.close();
process.exit(fail ? 1 : 0);

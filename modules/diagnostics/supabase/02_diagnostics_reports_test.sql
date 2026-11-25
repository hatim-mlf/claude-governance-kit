-- Tests for 02_diagnostics_reports.sql, run by test.sh after 01, on a throwaway local Postgres.
-- auth.uid() is a stand-in reading the same setting Supabase's does. Each check raises on failure.
\set ON_ERROR_STOP on

-- Stand-in users (the FK to auth.users needs them).
INSERT INTO auth.users(id) VALUES ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000a2'), ('00000000-0000-0000-0000-0000000000a3');

-- 1. A signed-in user may send a report.
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);
SET ROLE authenticated;
DO $$
BEGIN
  IF NOT public.submit_report('general', 'It stopped at 40%', '[{"code":"import.failed"}]'::jsonb,
       '1.0', '7', '26.1', 'iPhone17,1') THEN
    RAISE EXCEPTION 'a valid report was refused';
  END IF;
END $$;

-- 2. The app may not read, write or delete the table directly.
DO $$
BEGIN
  BEGIN PERFORM count(*) FROM diagnostics.reports; RAISE EXCEPTION 'authenticated could read reports';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN INSERT INTO diagnostics.reports(app_version, build, os_version, device_model, topic, note)
        VALUES ('1', '1', '1', 'x', 'general', 'x'); RAISE EXCEPTION 'authenticated could insert directly';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;

-- 3. Anonymous callers cannot call it, and a call with no signed-in user stores nothing.
SET ROLE anon;
DO $$
BEGIN
  BEGIN PERFORM public.submit_report('general', 'x', '[]'::jsonb, '1', '1', '1', 'x');
        RAISE EXCEPTION 'anon could call submit_report';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM count(*) FROM diagnostics.reports; RAISE EXCEPTION 'anon could read reports';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub', '', false);
DO $$
BEGIN
  IF public.submit_report('general', 'x', '[]'::jsonb, '1', '1', '1', 'x') THEN
    RAISE EXCEPTION 'a report with no signed-in user was stored';
  END IF;
END $$;

-- 4. Bad input is refused: an unknown topic, a note over 2000 characters, recent that is not an array or is over 32 KB.
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a2', false);
SET ROLE authenticated;
DO $$
DECLARE big jsonb;
BEGIN
  IF public.submit_report('billing', 'x', '[]'::jsonb, '1', '1', '1', 'x') THEN RAISE EXCEPTION 'unknown topic accepted'; END IF;
  IF public.submit_report('general', repeat('x', 2001), '[]'::jsonb, '1', '1', '1', 'x') THEN RAISE EXCEPTION 'long note accepted'; END IF;
  IF NOT public.submit_report('general', repeat('x', 2000), '[]'::jsonb, '1', '1', '1', 'x') THEN RAISE EXCEPTION '2000-char note refused'; END IF;
  IF public.submit_report('general', 'x', '{"a":1}'::jsonb, '1', '1', '1', 'x') THEN RAISE EXCEPTION 'non-array recent accepted'; END IF;
  SELECT jsonb_agg(jsonb_build_object('code', repeat('x', 400))) INTO big FROM generate_series(1, 120);
  IF public.submit_report('general', 'x', big, '1', '1', '1', 'x') THEN RAISE EXCEPTION 'oversized recent accepted'; END IF;
  IF public.submit_report('general', 'x', '[]'::jsonb, repeat('v', 33), '1', '1', 'x') THEN RAISE EXCEPTION 'long app_version accepted'; END IF;
END $$;
RESET ROLE;

-- 5. A user may send 5 in 24 hours (a2 has sent 1 above); the 6th is refused, and another user is unaffected.
SET ROLE authenticated;
DO $$
BEGIN
  FOR i IN 1..4 LOOP
    IF NOT public.submit_report('other', 'n' || i, '[]'::jsonb, '1', '1', '1', 'x') THEN
      RAISE EXCEPTION 'report % within the limit was refused', i + 1;
    END IF;
  END LOOP;
  IF public.submit_report('other', 'sixth', '[]'::jsonb, '1', '1', '1', 'x') THEN
    RAISE EXCEPTION 'the 6th report in 24 hours was accepted';
  END IF;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a3', false);
SET ROLE authenticated;
DO $$
BEGIN
  IF NOT public.submit_report('general', 'other user', '[]'::jsonb, '1', '1', '1', 'x') THEN
    RAISE EXCEPTION 'another user was limited by the first user''s reports';
  END IF;
END $$;
RESET ROLE;

-- 6. The global cap: 500 a day.
INSERT INTO auth.users(id) SELECT gen_random_uuid() FROM generate_series(1, 500);
INSERT INTO diagnostics.reports(user_id, app_version, build, os_version, device_model, topic, note)
    SELECT id, '1', '1', '1', 'x', 'general', 'bulk'
    FROM auth.users WHERE id NOT IN (SELECT user_id FROM diagnostics.reports);
SET ROLE authenticated;
DO $$
BEGIN
  IF public.submit_report('general', 'over the cap', '[]'::jsonb, '1', '1', '1', 'x') THEN
    RAISE EXCEPTION 'a report past the global daily cap was accepted';
  END IF;
END $$;
RESET ROLE;

-- 7. service_role (the digest) reads them; the stored user is the caller's, taken from the token.
SET ROLE service_role;
DO $$
DECLARE who uuid;
BEGIN
  SELECT user_id INTO who FROM diagnostics.reports WHERE note = 'It stopped at 40%';
  IF who <> '00000000-0000-0000-0000-0000000000a1' THEN RAISE EXCEPTION 'user_id was %', who; END IF;
END $$;
RESET ROLE;

-- 8. The purge keeps reports 180 days (events and crashes 90).
DO $$
DECLARE removed int; left_ int;
BEGIN
  DELETE FROM diagnostics.reports WHERE note = 'bulk';
  UPDATE diagnostics.reports SET received_at = now() - interval '181 days' WHERE note = 'n1';
  UPDATE diagnostics.reports SET received_at = now() - interval '100 days' WHERE note = 'n2';
  SELECT count(*) INTO left_ FROM diagnostics.reports;
  removed := diagnostics.purge_expired();
  IF removed <> 1 THEN RAISE EXCEPTION 'expected 1 report purged, got %', removed; END IF;
  IF (SELECT count(*) FROM diagnostics.reports) <> left_ - 1 THEN RAISE EXCEPTION 'the 100-day-old report should stay'; END IF;
END $$;

-- 8b. The redefined purge still removes events and crashes at 90 days.
DO $$
DECLARE removed int;
BEGIN
  INSERT INTO diagnostics.events(occurred_at, received_at, install_id, app_version, build, os_version, device_model, category, code)
    VALUES (now(), now() - interval '91 days', gen_random_uuid(), '1', '1', '1', 'x', 'sync', 'sync.old'),
           (now(), now() - interval '89 days', gen_random_uuid(), '1', '1', '1', 'x', 'sync', 'sync.young');
  INSERT INTO diagnostics.crashes(received_at, install_id, app_version, build, os_version, device_model, kind, payload)
    VALUES (now() - interval '91 days', gen_random_uuid(), '1', '1', '1', 'x', 'crash', '{}'::jsonb);
  removed := diagnostics.purge_expired();
  IF removed <> 2 THEN RAISE EXCEPTION 'expected the 91-day event and crash purged, got %', removed; END IF;
  IF NOT EXISTS (SELECT 1 FROM diagnostics.events WHERE code = 'sync.young') THEN RAISE EXCEPTION 'a 89-day event was purged'; END IF;
END $$;

-- 9. Account deletion removes the user's reports (FK to auth.users, ON DELETE CASCADE).
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM diagnostics.reports WHERE user_id = '00000000-0000-0000-0000-0000000000a3') THEN
    RAISE EXCEPTION 'setup: user a3 has no report';
  END IF;
  DELETE FROM auth.users WHERE id = '00000000-0000-0000-0000-0000000000a3';
  IF EXISTS (SELECT 1 FROM diagnostics.reports WHERE user_id = '00000000-0000-0000-0000-0000000000a3') THEN
    RAISE EXCEPTION 'a deleted account''s report survived';
  END IF;
END $$;

\echo 'diagnostics_reports_test: all checks passed'

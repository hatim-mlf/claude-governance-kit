-- Tests for 01_diagnostics.sql, run by test.sh on a throwaway local Postgres, never on a project.
-- Each check raises on failure.
\set ON_ERROR_STOP on

-- 1. The app (anon or authenticated) may report a batch through the function.
SET ROLE anon;
DO $$
DECLARE n int;
BEGIN
  n := public.report_diagnostics(jsonb_build_array(
    jsonb_build_object('occurred_at', now(), 'install_id', '00000000-0000-0000-0000-000000000001',
      'app_version', '1.0', 'build', '1', 'os_version', '26.1', 'device_model', 'iPhone17,1',
      'category', 'sync', 'code', 'sync.push.http_status', 'context', jsonb_build_object('status', 401)),
    jsonb_build_object('occurred_at', now(), 'install_id', '00000000-0000-0000-0000-000000000001',
      'app_version', '1.0', 'build', '1', 'os_version', '26.1', 'device_model', 'iPhone17,1',
      'category', 'auth', 'code', 'auth.refresh.failed')));
  IF n <> 2 THEN RAISE EXCEPTION 'expected 2 accepted, got %', n; END IF;
END $$;

-- 2. The app may not read, write or delete the tables directly.
DO $$
BEGIN
  BEGIN PERFORM count(*) FROM diagnostics.events; RAISE EXCEPTION 'anon could read events';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN INSERT INTO diagnostics.events(occurred_at, install_id, app_version, build, os_version, device_model, category, code)
        VALUES (now(), gen_random_uuid(), '1', '1', '1', 'x', 'sync', 'x'); RAISE EXCEPTION 'anon could insert directly';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM count(*) FROM diagnostics.crashes; RAISE EXCEPTION 'anon could read crashes';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

-- 3. Malformed events are dropped, not stored: a bad category, a bad code, a missing install id,
--    a context that is not an object, an oversized context.
DO $$
DECLARE n int;
BEGIN
  n := public.report_diagnostics(jsonb_build_array(
    jsonb_build_object('occurred_at', now(), 'install_id', '00000000-0000-0000-0000-000000000002',
      'app_version', '1.0', 'build', '1', 'os_version', '26.1', 'device_model', 'x', 'category', 'Sync Errors!', 'code', 'x'),
    jsonb_build_object('occurred_at', now(), 'install_id', '00000000-0000-0000-0000-000000000002',
      'app_version', '1.0', 'build', '1', 'os_version', '26.1', 'device_model', 'x', 'category', 'sync', 'code', 'has spaces'),
    jsonb_build_object('occurred_at', now(),
      'app_version', '1.0', 'build', '1', 'os_version', '26.1', 'device_model', 'x', 'category', 'sync', 'code', 'sync.x'),
    jsonb_build_object('occurred_at', now(), 'install_id', '00000000-0000-0000-0000-000000000002',
      'app_version', '1.0', 'build', '1', 'os_version', '26.1', 'device_model', 'x', 'category', 'sync', 'code', 'sync.x',
      'context', '"a string"'::jsonb),
    jsonb_build_object('occurred_at', now(), 'install_id', '00000000-0000-0000-0000-000000000002',
      'app_version', '1.0', 'build', '1', 'os_version', '26.1', 'device_model', 'x', 'category', 'sync', 'code', 'sync.x',
      'context', jsonb_build_object('blob', repeat('x', 3000)))));
  IF n <> 0 THEN RAISE EXCEPTION 'expected 0 accepted from malformed events, got %', n; END IF;
END $$;

-- 4. A batch over 100 events is refused whole; an install is capped at 500 a day.
DO $$
DECLARE n int; batch jsonb; one jsonb;
BEGIN
  one := jsonb_build_object('occurred_at', now(), 'install_id', '00000000-0000-0000-0000-000000000003',
      'app_version', '1.0', 'build', '1', 'os_version', '26.1', 'device_model', 'x', 'category', 'sync', 'code', 'sync.x');
  SELECT jsonb_agg(one) INTO batch FROM generate_series(1, 101);
  n := public.report_diagnostics(batch);
  IF n <> 0 THEN RAISE EXCEPTION 'a batch of 101 was accepted (%)', n; END IF;
  SELECT jsonb_agg(one) INTO batch FROM generate_series(1, 100);
  FOR i IN 1..5 LOOP n := public.report_diagnostics(batch); END LOOP;
  n := public.report_diagnostics(jsonb_build_array(one));
  IF n <> 0 THEN RAISE EXCEPTION 'the 501st event of the day was accepted'; END IF;
END $$;

-- 5. A crash report goes through its own function; an unknown kind or an oversized payload is refused.
DO $$
BEGIN
  IF NOT public.report_crash('00000000-0000-0000-0000-000000000001', '1.0', '1', '26.1', 'iPhone17,1',
                             'crash', jsonb_build_object('callStackTree', jsonb_build_object('x', 1))) THEN
    RAISE EXCEPTION 'a valid crash was refused';
  END IF;
  IF public.report_crash('00000000-0000-0000-0000-000000000001', '1.0', '1', '26.1', 'x', 'explosion', '{}'::jsonb) THEN
    RAISE EXCEPTION 'an unknown kind was accepted';
  END IF;
  IF public.report_crash('00000000-0000-0000-0000-000000000001', '1.0', '1', '26.1', 'x', 'crash',
                         jsonb_build_object('blob', repeat('x', 70000))) THEN
    RAISE EXCEPTION 'an oversized payload was accepted';
  END IF;
END $$;
RESET ROLE;

-- 6. What was stored, read as the owner: 2 + 500 events, 1 crash.
DO $$
DECLARE e int; c int;
BEGIN
  SELECT count(*) INTO e FROM diagnostics.events;
  SELECT count(*) INTO c FROM diagnostics.crashes;
  IF e <> 502 THEN RAISE EXCEPTION 'expected 502 events stored, found %', e; END IF;
  IF c <> 1 THEN RAISE EXCEPTION 'expected 1 crash stored, found %', c; END IF;
END $$;

-- 7. The purge removes what is older than 90 days and keeps the rest.
DO $$
DECLARE removed int; left_ int;
BEGIN
  UPDATE diagnostics.events SET received_at = now() - interval '91 days' WHERE code = 'auth.refresh.failed';
  UPDATE diagnostics.crashes SET received_at = now() - interval '91 days';
  removed := diagnostics.purge_expired();
  IF removed <> 2 THEN RAISE EXCEPTION 'expected 2 rows purged, got %', removed; END IF;
  SELECT count(*) INTO left_ FROM diagnostics.events;
  IF left_ <> 501 THEN RAISE EXCEPTION 'expected 501 events left, found %', left_; END IF;
END $$;

-- 8. Review fix: a global daily cap stops a flood from invented install ids.
UPDATE diagnostics.daily_intake SET n = 100000 WHERE day = current_date AND kind = 'events';
SET ROLE anon;
DO $$
DECLARE n int;
BEGIN
  n := public.report_diagnostics(jsonb_build_array(jsonb_build_object('occurred_at', now(),
    'install_id', gen_random_uuid(), 'app_version', '1.0', 'build', '1', 'os_version', '26.1',
    'device_model', 'x', 'category', 'sync', 'code', 'sync.x')));
  IF n <> 0 THEN RAISE EXCEPTION 'an event past the global daily cap was accepted'; END IF;
  BEGIN PERFORM count(*) FROM diagnostics.daily_intake; RAISE EXCEPTION 'anon could read the intake counter';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;

\echo 'diagnostics_test: all checks passed'

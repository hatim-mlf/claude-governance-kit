-- Diagnostics intake (claude-governance-kit modules/diagnostics). Proven in production on the
-- project this kit came from. Events and crash reports from installs of the app: never location,
-- user content or names, never linked to an account. The app writes only through the two
-- SECURITY DEFINER functions; the schema is not exposed to the API, so nothing here can be read
-- with the app's public key. Kept 90 days. Tested by test.sh beside this file.
-- Caps: 100 events per call, 500 per install a day, 100,000 a day globally; crashes 20 per
-- install a day, 2,000 globally. Change them with a reason (expected users x events per run).
-- Needs the pg_cron extension (Supabase: Database > Extensions) for the purge schedule at the end.
CREATE SCHEMA diagnostics;
REVOKE ALL ON SCHEMA diagnostics FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA diagnostics TO service_role;

CREATE TABLE diagnostics.events (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    received_at timestamptz NOT NULL DEFAULT now(),
    occurred_at timestamptz NOT NULL,
    install_id uuid NOT NULL,
    session_id uuid,
    app_version text NOT NULL CHECK (length(app_version) <= 32),
    build text NOT NULL CHECK (length(build) <= 32),
    os_version text NOT NULL CHECK (length(os_version) <= 32),
    device_model text NOT NULL CHECK (length(device_model) <= 64),
    category text NOT NULL CHECK (category ~ '^[a-z_]{1,32}$'),
    code text NOT NULL CHECK (code ~ '^[a-z0-9_.]{1,64}$'),
    context jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(context) = 'object' AND pg_column_size(context) <= 2048),
    fingerprint text
);
CREATE INDEX ON diagnostics.events (received_at);
CREATE INDEX ON diagnostics.events (install_id, received_at);
CREATE INDEX ON diagnostics.events (category, code);

CREATE TABLE diagnostics.crashes (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    received_at timestamptz NOT NULL DEFAULT now(),
    install_id uuid NOT NULL,
    app_version text NOT NULL CHECK (length(app_version) <= 32),
    build text NOT NULL CHECK (length(build) <= 32),
    os_version text NOT NULL CHECK (length(os_version) <= 32),
    device_model text NOT NULL CHECK (length(device_model) <= 64),
    kind text NOT NULL CHECK (kind IN ('crash','hang','cpu','disk','launch')),
    payload jsonb NOT NULL CHECK (pg_column_size(payload) <= 65536)
);
CREATE INDEX ON diagnostics.crashes (received_at);

-- the app's key is public, so per-install caps alone let anyone invent
-- install ids and fill the free-tier database. A global daily cap, kept as a counter (cheap to check).
CREATE TABLE diagnostics.daily_intake (
    day date NOT NULL,
    kind text NOT NULL CHECK (kind IN ('events','crashes')),
    n integer NOT NULL DEFAULT 0,
    PRIMARY KEY (day, kind)
);

REVOKE ALL ON ALL TABLES IN SCHEMA diagnostics FROM PUBLIC, anon, authenticated;
GRANT SELECT, DELETE ON ALL TABLES IN SCHEMA diagnostics TO service_role;

CREATE OR REPLACE FUNCTION public.report_diagnostics(p_events jsonb)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_item jsonb;
    v_count integer := 0;
    v_rate integer;
BEGIN
    IF p_events IS NULL OR jsonb_typeof(p_events) <> 'array' OR jsonb_array_length(p_events) > 100 THEN
        RETURN 0;
    END IF;
    -- Global cap: 100,000 events a day across all installs.
    INSERT INTO diagnostics.daily_intake (day, kind, n)
        VALUES (current_date, 'events', jsonb_array_length(p_events))
        ON CONFLICT (day, kind) DO UPDATE SET n = diagnostics.daily_intake.n + EXCLUDED.n
        RETURNING n INTO v_rate;
    IF v_rate > 100000 THEN
        RETURN 0;
    END IF;
    FOR v_item IN SELECT jsonb_array_elements(p_events) LOOP
        BEGIN
            SELECT count(*) INTO v_rate FROM diagnostics.events
                WHERE install_id = (v_item->>'install_id')::uuid
                AND received_at > now() - interval '24 hours';
            IF v_rate >= 500 THEN
                CONTINUE;
            END IF;
            INSERT INTO diagnostics.events
                (occurred_at, install_id, session_id, app_version, build, os_version,
                 device_model, category, code, context)
            VALUES
                ((v_item->>'occurred_at')::timestamptz,
                 (v_item->>'install_id')::uuid,
                 NULLIF(v_item->>'session_id', '')::uuid,
                 v_item->>'app_version', v_item->>'build', v_item->>'os_version',
                 v_item->>'device_model', v_item->>'category', v_item->>'code',
                 COALESCE(v_item->'context', '{}'::jsonb));
            v_count := v_count + 1;
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
    END LOOP;
    RETURN v_count;
END;
$$;
REVOKE ALL ON FUNCTION public.report_diagnostics(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.report_diagnostics(jsonb) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.report_crash(
    p_install_id uuid, p_app_version text, p_build text,
    p_os_version text, p_device_model text, p_kind text, p_payload jsonb
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_crashes integer;
BEGIN
    IF p_kind NOT IN ('crash','hang','cpu','disk','launch') THEN
        RETURN false;
    END IF;
    IF pg_column_size(p_payload) > 65536 THEN
        RETURN false;
    END IF;
    -- Global cap: 2,000 crash reports a day across all installs.
    INSERT INTO diagnostics.daily_intake (day, kind, n) VALUES (current_date, 'crashes', 1)
        ON CONFLICT (day, kind) DO UPDATE SET n = diagnostics.daily_intake.n + 1
        RETURNING n INTO v_crashes;
    IF v_crashes > 2000 THEN
        RETURN false;
    END IF;
    SELECT count(*) INTO v_crashes FROM diagnostics.crashes
        WHERE install_id = p_install_id AND received_at > now() - interval '24 hours';
    IF v_crashes >= 20 THEN
        RETURN false;
    END IF;
    INSERT INTO diagnostics.crashes
        (install_id, app_version, build, os_version, device_model, kind, payload)
    VALUES
        (p_install_id, p_app_version, p_build, p_os_version, p_device_model, p_kind, p_payload);
    RETURN true;
EXCEPTION WHEN OTHERS THEN
    RETURN false;
END;
$$;
REVOKE ALL ON FUNCTION public.report_crash(uuid,text,text,text,text,text,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.report_crash(uuid,text,text,text,text,text,jsonb) TO anon, authenticated;

CREATE OR REPLACE FUNCTION diagnostics.purge_expired()
RETURNS integer
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
    v_deleted integer := 0;
    v_n integer;
BEGIN
    DELETE FROM diagnostics.events WHERE received_at < now() - interval '90 days';
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_deleted := v_deleted + v_n;
    DELETE FROM diagnostics.crashes WHERE received_at < now() - interval '90 days';
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_deleted := v_deleted + v_n;
    DELETE FROM diagnostics.daily_intake WHERE day < current_date - 7;
    RETURN v_deleted;
END;
$$;

SELECT cron.schedule('diagnostics-purge', '41 3 * * *', 'SELECT diagnostics.purge_expired()');

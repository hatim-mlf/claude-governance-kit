-- "Send a report" (claude-governance-kit modules/diagnostics), applied after 01_diagnostics.sql.
-- The one place a signed-in user's account and a note reach the project, and only when they tap
-- Send: the note, a topic, app/OS/device, and the app's recent diagnostic codes (codes and safe
-- context only). No install id is stored, so a report cannot be joined to the anonymous events.
-- Topics: replace ('general','other') with the app's own, here AND in submit_report.
-- Kept 180 days; account deletion removes a user's reports. Tested by test.sh beside this file.
CREATE TABLE diagnostics.reports (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    received_at timestamptz NOT NULL DEFAULT now(),
    user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,  -- account deletion removes the user's reports
    app_version text NOT NULL CHECK (length(app_version) <= 32),
    build text NOT NULL CHECK (length(build) <= 32),
    os_version text NOT NULL CHECK (length(os_version) <= 32),
    device_model text NOT NULL CHECK (length(device_model) <= 64),
    topic text NOT NULL CHECK (topic IN ('general','other')),
    note text NOT NULL CHECK (char_length(note) <= 2000),
    recent jsonb NOT NULL DEFAULT '[]'::jsonb
        CHECK (jsonb_typeof(recent) = 'array' AND pg_column_size(recent) <= 32768),
    status text NOT NULL DEFAULT 'new'
);
CREATE INDEX ON diagnostics.reports (received_at);
CREATE INDEX ON diagnostics.reports (user_id, received_at);
ALTER TABLE diagnostics.reports ENABLE ROW LEVEL SECURITY;   -- no policy: only the owner and service_role (bypass) read it
REVOKE ALL ON diagnostics.reports FROM PUBLIC, anon, authenticated;
GRANT SELECT, UPDATE, DELETE ON diagnostics.reports TO service_role;   -- UPDATE: moving status from 'new'

CREATE OR REPLACE FUNCTION public.submit_report(
    p_topic text, p_note text, p_recent jsonb,
    p_app_version text, p_build text, p_os_version text, p_device_model text
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user uuid := auth.uid();
    v_n integer;
BEGIN
    IF v_user IS NULL THEN
        RETURN false;
    END IF;
    IF p_topic IS NULL OR p_topic NOT IN ('general','other')
       OR p_note IS NULL OR char_length(p_note) > 2000
       OR p_recent IS NULL OR jsonb_typeof(p_recent) <> 'array' OR pg_column_size(p_recent) > 32768 THEN
        RETURN false;
    END IF;
    -- At most 5 per user in 24 hours, and 500 a day across everyone.
    SELECT count(*) INTO v_n FROM diagnostics.reports
        WHERE user_id = v_user AND received_at > now() - interval '24 hours';
    IF v_n >= 5 THEN
        RETURN false;
    END IF;
    SELECT count(*) INTO v_n FROM diagnostics.reports WHERE received_at > now() - interval '24 hours';
    IF v_n >= 500 THEN
        RETURN false;
    END IF;
    INSERT INTO diagnostics.reports
        (user_id, app_version, build, os_version, device_model, topic, note, recent)
    VALUES
        (v_user, p_app_version, p_build, p_os_version, p_device_model, p_topic, p_note, p_recent);
    RETURN true;
EXCEPTION WHEN OTHERS THEN
    RETURN false;
END;
$$;
-- Supabase grants new public functions to anon by default, so anon is revoked by name, not only PUBLIC.
REVOKE ALL ON FUNCTION public.submit_report(text,text,jsonb,text,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_report(text,text,jsonb,text,text,text,text) TO authenticated;

-- Reports are kept 180 days; events and crashes stay at 90 (diagnostics.purge_expired, redefined whole).
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
    DELETE FROM diagnostics.reports WHERE received_at < now() - interval '180 days';
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_deleted := v_deleted + v_n;
    DELETE FROM diagnostics.daily_intake WHERE day < current_date - 7;
    RETURN v_deleted;
END;
$$;

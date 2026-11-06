-- Secure Firebase push device registration.
-- Identity is derived exclusively from the verified Odoo JWT.

CREATE OR REPLACE FUNCTION public.app_push_register_device(
    p_device_id text,
    p_platform text,
    p_token text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_claims jsonb := auth.jwt();
    v_user_id text;
    v_role text;
BEGIN
    v_user_id := COALESCE(
        NULLIF(v_claims ->> 'odoo_user_id', ''),
        NULLIF(v_claims #>> '{app_metadata,odoo_user_id}', '')
    );

    v_role := COALESCE(
        NULLIF(v_claims ->> 'odoo_role', ''),
        NULLIF(v_claims #>> '{app_metadata,odoo_role}', '')
    );

    IF auth.role() IS DISTINCT FROM 'authenticated'
       OR v_claims ->> 'iss' IS DISTINCT FROM 'tourops-odoo'
       OR v_claims ->> 'scope' IS DISTINCT FROM 'notifications'
       OR v_claims ->> 'environment' IS DISTINCT FROM 'test'
       OR v_user_id IS NULL
       OR v_user_id !~ '^[1-9][0-9]{0,17}$'
       OR v_role IS NULL
       OR v_role NOT IN ('customer', 'driver')
    THEN
        RAISE EXCEPTION 'Unauthorized notification identity';
    END IF;

    IF p_device_id IS NULL OR length(p_device_id) > 128
       OR length(trim(p_device_id)) = 0
       OR p_token IS NULL OR length(p_token) > 8192
       OR length(trim(p_token)) = 0
       OR p_platform IS NULL
       OR p_platform NOT IN ('ios', 'android', 'web')
    THEN
        RAISE EXCEPTION 'Invalid device registration';
    END IF;

    INSERT INTO public.app_push_tokens (
        environment,
        recipient_role,
        recipient_odoo_id,
        device_id,
        platform,
        token,
        is_active,
        created_at,
        updated_at,
        last_seen_at
    )
    VALUES (
        'test',
        v_role,
        v_user_id::bigint,
        trim(p_device_id),
        p_platform,
        trim(p_token),
        true,
        now(),
        now(),
        now()
    )
    ON CONFLICT (
        environment,
        recipient_role,
        recipient_odoo_id,
        device_id
    )
    DO UPDATE SET
        platform = EXCLUDED.platform,
        token = EXCLUDED.token,
        is_active = true,
        updated_at = now(),
        last_seen_at = now();

    RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.app_push_register_device(text,text,text)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.app_push_register_device(text,text,text)
TO authenticated;

-- set session to show stk_superuser as the actor performing all the tasks
SET stk.session = '{\"psql_user\": \"stk_superuser\"}';

-- create domain to allow for web/rest communication
create domain "text/html" as text;

-- add event type for form
ALTER TYPE private.stk_event_type_enum ADD VALUE 'FORM_POST'; commit; --note: commit is needed to be able to use the enum value below
INSERT INTO private.enum_comment (enum_type, enum_value, comment, is_default) VALUES
('stk_event_type_enum', 'FORM_POST', 'Used to capture form posts', false)
;
SELECT private.stk_table_type_create('stk_event_type');

CREATE OR REPLACE FUNCTION api.stk_form_post_fn(jsonb) RETURNS "text/html" AS $$
DECLARE
    type_uu_v uuid;
BEGIN
    -- Get the type_uu for FORM_POST
    SELECT uu
    INTO type_uu_v
    FROM private.stk_event_type
    WHERE type_enum = 'FORM_POST';

    -- Insert using the type_uu
    INSERT INTO private.stk_event (record_json, name, type_uu)
    VALUES ($1, 'test', type_uu_v);

    RETURN 'Submitted - Thank you!!';
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER;
COMMENT ON FUNCTION api.stk_form_post_fn(jsonb) IS 'api function used to write to stk_form_post table';

GRANT EXECUTE ON FUNCTION api.stk_form_post_fn(jsonb) TO stk_api_role;



CREATE TABLE private.enum_comment (
    enum_comment_uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    enum_type text NOT NULL,
    enum_value text NOT NULL,
    comment text,
    created TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by_uu uuid, -- allow null and no fk because created so early
    updated TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by_uu uuid, -- allow null and no fk because created so early
	UNIQUE (enum_type, enum_value)
);
COMMENT ON TABLE private.enum_comment IS 'table to hold comments on enum values';

CREATE OR REPLACE FUNCTION private.enum_value(enum_name text)
RETURNS TABLE (enum_value text, comment text)
AS $$
BEGIN
    RETURN QUERY EXECUTE format(
        'SELECT e.enum_value::text, c.comment
         FROM (SELECT unnest(enum_range(NULL::%I.%I))::text AS enum_value) e
         LEFT JOIN private.enum_comment c ON c.enum_type = %L AND c.enum_value = e.enum_value::text',
        'private',
        enum_name,
        enum_name
    );
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER;
COMMENT ON FUNCTION private.enum_value(text) IS 'function to extract enum values into table with comments';

CREATE OR REPLACE VIEW api.enum_value AS
SELECT 'wf_request_type'::text AS enum_name, enum_value, comment
FROM private.enum_value('wf_request_type');
COMMENT ON VIEW api.enum_value IS 'Show enum values and comments';


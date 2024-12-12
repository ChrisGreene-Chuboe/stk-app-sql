

-- TODO: determine why this table does not have a stk_ prefix - either explain for correct
CREATE TABLE private.enum_comment (
    uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    enum_type text NOT NULL,
    enum_value text NOT NULL,
    comment text,
    created TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by_uu uuid, -- allow null and no fk because created so early
    updated TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by_uu uuid, -- allow null and no fk because created so early
	UNIQUE (enum_type, enum_value)
);
COMMENT ON TABLE private.enum_comment IS 'The `enum_comment` table holds comments on enum values. This table exists because psql does not have the ability to comment on enum values directly.';

CREATE OR REPLACE VIEW api.enum_value AS
SELECT
    t.typname AS enum_name,
    e.enumlabel AS enum_value,
    ec.comment
FROM pg_type t
JOIN pg_enum e ON t.oid = e.enumtypid
JOIN pg_namespace n ON n.oid = t.typnamespace
LEFT JOIN private.enum_comment ec ON ec.enum_type = t.typname AND ec.enum_value = e.enumlabel
WHERE t.typtype = 'e'
    AND n.nspname = 'private'
ORDER BY enum_name, e.enumsortorder;

COMMENT ON VIEW api.enum_value IS 'Shows all `api` schema enum types in the database with their values and comments';

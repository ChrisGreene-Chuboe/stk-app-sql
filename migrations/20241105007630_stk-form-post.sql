

-- set session to show stk_superuser as the actor performing all the tasks
SET stk.session = '{\"psql_user\": \"stk_superuser\"}';

create domain "text/html" as text;

---- primary_section start ----
CREATE TABLE private.stk_form_post (
  uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT generated always AS ('stk_form_post') stored,
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL, -- no FK by convention
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL, -- no FK by convention
  is_active BOOLEAN NOT NULL DEFAULT true,
  record_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  date_processed TIMESTAMPTZ,
  is_processed BOOLEAN GENERATED ALWAYS AS (date_processed IS NOT NULL) STORED,
  description TEXT
);
COMMENT ON TABLE private.stk_form_post IS 'Holds form_post records';

CREATE VIEW api.stk_form_post AS SELECT * FROM private.stk_form_post;
COMMENT ON VIEW api.stk_form_post IS 'Holds form_post records';
---- primary_section end ----

-- create triggers for newly created tables
SELECT private.stk_trigger_create();

CREATE OR REPLACE FUNCTION api.stk_form_post_fn(jsonb) RETURNS "text/html" AS $$
BEGIN
    INSERT INTO private.stk_form_post (record_json)
    VALUES ($1);
    RETURN 'Submitted - Thank you!!';
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER;
COMMENT ON FUNCTION api.stk_form_post_fn(jsonb) IS 'api function used to write to stk_form_post table';

GRANT EXECUTE ON FUNCTION api.stk_form_post_fn(jsonb) TO stk_api_role;

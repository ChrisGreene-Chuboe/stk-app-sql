
create domain "text/html" as text;

CREATE TABLE IF NOT EXISTS private.stk_form_post (
  stk_form_post_uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_active BOOLEAN NOT NULL DEFAULT true,
  form_data jsonb NOT NULL,
  description TEXT
);
COMMENT ON TABLE private.stk_form_post IS 'table used to receive html form posts';

CREATE OR REPLACE FUNCTION api.stk_form_post_fn(jsonb) RETURNS "text/html" AS $$
BEGIN
    INSERT INTO private.stk_form_post (form_data)
    VALUES ($1);
    RETURN 'Submitted - Thank you!!';
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER;
COMMENT ON FUNCTION api.stk_form_post_fn(jsonb) IS 'api function used to write to stk_form_post table';

GRANT EXECUTE ON FUNCTION api.stk_form_post_fn(jsonb) TO postgrest_web_anon;

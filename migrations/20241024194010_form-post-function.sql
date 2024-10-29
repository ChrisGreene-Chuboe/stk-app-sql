
CREATE TABLE IF NOT EXISTS private.stk_form_post (
  stk_form_post_uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_active BOOLEAN NOT NULL DEFAULT true,
  form_data json NOT NULL,
  description TEXT
);

CREATE OR REPLACE FUNCTION api.stk_form_post_fn(json) RETURNS text AS $$
BEGIN
    INSERT INTO private.stk_form_post (form_data)
    VALUES ($1);
    RETURN 'Submitted - Thank you!!';
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION api.stk_form_post_fn(json) TO postgrest_web_anon;

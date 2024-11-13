

CREATE TABLE private.stk_wf_request (
  stk_wf_request_uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_active BOOLEAN NOT NULL DEFAULT true,
  date_completed TIMESTAMPTZ,
  name TEXT NOT NULL,
  description TEXT,
  date_due TIMESTAMPTZ
);
COMMENT ON TABLE private.stk_wf_request IS 'table to hold task and todos';

CREATE VIEW api.stk_wf_request AS SELECT * FROM private.stk_wf_request;
COMMENT ON VIEW api.stk_wf_request IS 'table to hold task and todos';

----sample data
--INSERT INTO api.stk_wf_request (name) VALUES
--  ('perform vitory lap'), ('pat self on back'), ('hug and kiss those you love');

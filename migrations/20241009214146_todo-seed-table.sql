

-- Create and configure private schema
CREATE SCHEMA IF NOT EXISTS private;
COMMENT ON SCHEMA private is 'schema used to encapsulate data and private functions';
GRANT USAGE, CREATE ON SCHEMA private TO stk_superuser;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA private TO stk_superuser;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA private TO stk_superuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA private GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO stk_superuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA private GRANT ALL ON SEQUENCES TO stk_superuser;

-- Create and configure api schema
CREATE SCHEMA IF NOT EXISTS api;
COMMENT ON SCHEMA api is 'schema used to create a public interface to the private schema';
GRANT USAGE, CREATE ON SCHEMA api TO stk_superuser;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA api TO stk_superuser;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA api TO stk_superuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO stk_superuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT ALL ON SEQUENCES TO stk_superuser;

ALTER ROLE stk_superuser SET search_path TO public, private, api;

--Note: leaving public schema since used by sqlx migration
--ALTER SCHEMA public OWNER TO stk_superuser;

--SET ROLE stk_superuser;

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


--CREATE ROLE stk_todo_superuser NOLOGIN;

--ALTER DATABASE stk_todo_db OWNER TO stk_todo_superuser;

-- Create and configure private schema
CREATE SCHEMA IF NOT EXISTS private;
GRANT USAGE, CREATE ON SCHEMA private TO stk_todo_superuser;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA private TO stk_todo_superuser;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA private TO stk_todo_superuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA private GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO stk_todo_superuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA private GRANT ALL ON SEQUENCES TO stk_todo_superuser;

-- Create and configure api schema
CREATE SCHEMA IF NOT EXISTS api;
GRANT USAGE, CREATE ON SCHEMA api TO stk_todo_superuser;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA api TO stk_todo_superuser;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA api TO stk_todo_superuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO stk_todo_superuser;
ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT ALL ON SEQUENCES TO stk_todo_superuser;

ALTER ROLE stk_todo_superuser SET search_path TO private, api;

--Note: leaving public schema since used by sqlx migration
--ALTER SCHEMA public OWNER TO stk_todo_superuser;

--SET ROLE stk_todo_superuser;

CREATE TABLE private.stk_todo (
  stk_todo_uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_active BOOLEAN NOT NULL DEFAULT true,
  date_completed TIMESTAMPTZ,
  name TEXT NOT NULL,
  description TEXT,
  date_due TIMESTAMPTZ
);

CREATE VIEW api.stk_todo AS SELECT * FROM private.stk_todo;

INSERT INTO api.stk_todo (name) VALUES
  ('perform vitory lap'), ('pat self on back'), ('hug and kiss those you love');

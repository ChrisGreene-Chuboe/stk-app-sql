-- Add migration script here

CREATE ROLE stk_todo_superuser NOLOGIN;

ALTER DATABASE stk_todo_db OWNER TO stk_todo_superuser;

GRANT CONNECT ON DATABASE stk_todo_db TO stk_todo_superuser;

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

-- Drop public schema since not needed
--DROP SCHEMA IF EXISTS public CASCADE;

create table private.stk_todo_x (
  stk_todo_uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_active BOOLEAN NOT NULL DEFAULT true,
  date_completed TIMESTAMPTZ NOT NULL DEFAULT now(),
  name TEXT NOT NULL,
  description TEXT,
  date_due TIMESTAMPTZ
);

create view api.stk_todo as select * from private.stk_todo_x;

INSERT INTO api.stk_todo (name) VALUES
  ('perform vitory lap'), ('pat self on back'), ('hug and kiss those you love');

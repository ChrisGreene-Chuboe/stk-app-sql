
--create PostgREST artifacts
--This script should be combined with the following script where stk_todo_user is created.
  -- Do not see a reason to have both postgrest_web_anon and stk_todo_user - just use stk_todo_user for both
CREATE ROLE postgrest_web_anon NOLOGIN;
COMMENT ON ROLE postgrest_web_anon IS 'anonymous role for PostgREST';
GRANT USAGE ON schema api TO postgrest_web_anon;

-- if want to grant all in api schema
GRANT ALL ON ALL TABLES IN SCHEMA api TO postgrest_web_anon;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA api TO postgrest_web_anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT ALL ON TABLES TO postgrest_web_anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT ALL ON SEQUENCES TO postgrest_web_anon;

-- if want to grant single table
--GRANT ALL ON api.stk_todo TO postgrest_web_anon;

CREATE ROLE postgrest NOINHERIT LOGIN ;
COMMENT ON ROLE postgrest IS 'PostgREST login role for PostgREST that has no priviledges';
GRANT postgrest_web_anon TO postgrest;

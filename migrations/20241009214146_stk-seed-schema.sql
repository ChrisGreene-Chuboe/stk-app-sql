

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


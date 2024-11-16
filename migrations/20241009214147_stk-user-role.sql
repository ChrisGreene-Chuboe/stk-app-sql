

-- create todo api user role
CREATE ROLE stk_api_role NOLOGIN;
COMMENT ON ROLE stk_api_role IS 'role with ability to use the stk_db api schema but not see or modify the private schema';
GRANT USAGE ON SCHEMA api TO stk_api_role;
GRANT ALL ON ALL TABLES IN SCHEMA api TO stk_api_role;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA api TO stk_api_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT ALL ON TABLES TO stk_api_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT ALL ON SEQUENCES TO stk_api_role;

ALTER ROLE stk_api_role SET search_path TO api;

-- create todo private user role
CREATE ROLE stk_private_role NOLOGIN;
COMMENT ON ROLE stk_private_role IS 'role with ability to use the stk_db private schema but not see or modify the api schema';
GRANT USAGE ON SCHEMA private TO stk_private_role;
GRANT ALL ON ALL TABLES IN SCHEMA private TO stk_private_role;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA private TO stk_private_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA private GRANT ALL ON TABLES TO stk_private_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA private GRANT ALL ON SEQUENCES TO stk_private_role;

ALTER ROLE stk_private_role SET search_path TO private;

-- create generic todo login user - this needs to eventually be removed and replaced with actual users
CREATE ROLE stk_login NOINHERIT LOGIN ;
COMMENT ON ROLE stk_login IS 'stk_login role that has no priviledges except to switch to stk_api_role';
GRANT stk_api_role TO stk_login;
GRANT stk_private_role TO stk_login;
GRANT stk_api_role TO stk_superuser; -- allow 'superuser' to play role of 'api_role'
GRANT stk_private_role TO stk_superuser; -- allow 'superuser' to play role of 'private_role'

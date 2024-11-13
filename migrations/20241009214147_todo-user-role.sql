

-- create todo api user role
CREATE ROLE stk_todo_api_role NOLOGIN;
COMMENT ON ROLE stk_todo_api_role IS 'role with ability to use the stk_todo_db api schema but not see or modify the private schema';
GRANT USAGE ON SCHEMA api TO stk_todo_api_role;
GRANT ALL ON ALL TABLES IN SCHEMA api TO stk_todo_api_role;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA api TO stk_todo_api_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT ALL ON TABLES TO stk_todo_api_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT ALL ON SEQUENCES TO stk_todo_api_role;

ALTER ROLE stk_todo_api_role SET search_path TO api;

-- create todo private user role
CREATE ROLE stk_todo_private_role NOLOGIN;
COMMENT ON ROLE stk_todo_private_role IS 'role with ability to use the stk_todo_db private schema but not see or modify the api schema';
GRANT USAGE ON SCHEMA private TO stk_todo_private_role;
GRANT ALL ON ALL TABLES IN SCHEMA private TO stk_todo_private_role;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA private TO stk_todo_private_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA private GRANT ALL ON TABLES TO stk_todo_private_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA private GRANT ALL ON SEQUENCES TO stk_todo_private_role;

ALTER ROLE stk_todo_private_role SET search_path TO private;

-- create generic todo login user - this needs to eventually be removed and replaced with actual users
CREATE ROLE stk_todo_login NOINHERIT LOGIN ;
COMMENT ON ROLE stk_todo_login IS 'stk_todo_login role that has no priviledges except to switch to stk_todo_api_role';
GRANT stk_todo_api_role TO stk_todo_login;
GRANT stk_todo_private_role TO stk_todo_login;
GRANT stk_todo_api_role TO stk_todo_superuser; -- allow 'superuser' to play role of 'api_role'
GRANT stk_todo_private_role TO stk_todo_superuser; -- allow 'superuser' to play role of 'private_role'



-- create todo user role
CREATE ROLE stk_todo_user NOLOGIN;
COMMENT ON ROLE stk_todo_user IS 'role with ability to use the stk_todo_db but not administer it';
GRANT USAGE ON SCHEMA api TO stk_todo_user;
GRANT ALL ON ALL TABLES IN SCHEMA api TO stk_todo_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA api TO stk_todo_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT ALL ON TABLES TO stk_todo_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT ALL ON SEQUENCES TO stk_todo_user;

ALTER ROLE stk_todo_user SET search_path TO api;

-- create generic todo login user - this needs to eventually be removed and replaced with actual users
CREATE ROLE stk_todo_login NOINHERIT LOGIN ;
COMMENT ON ROLE stk_todo_login IS 'stk_todo_login role that has no priviledges except to switch to stk_todo_user';
GRANT stk_todo_user TO stk_todo_login;

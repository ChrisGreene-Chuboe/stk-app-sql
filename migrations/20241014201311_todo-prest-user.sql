-- Add migration script here
--create schema api
CREATE ROLE postgrest_web_anon NOLOGIN;
GRANT USAGE ON schema api TO postgrest_web_anon;
GRANT ALL ON api.stk_todo TO postgrest_web_anon;
CREATE ROLE postgrest NOINHERIT LOGIN ;
GRANT postgrest_web_anon TO postgrest;

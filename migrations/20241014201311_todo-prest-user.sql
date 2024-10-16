-- Add migration script here
--create schema api
create role postgrest_web_anon nologin;
grant usage on schema api to postgrest_web_anon;
grant all on stk_todo to postgrest_web_anon;
create role postgrest noinherit login ;
grant postgrest_web_anon to postgrest;

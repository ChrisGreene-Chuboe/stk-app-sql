-- Add migration script here
--create schema api
create role postrest_web_anon nologin;
grant usage on schema public to postrest_web_anon;
grant all on todo to postrest_web_anon;
create role postrest login ;
grant postrest_web_anon to postrest;

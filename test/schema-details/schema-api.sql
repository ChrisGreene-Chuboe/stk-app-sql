

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA api;




COMMENT ON SCHEMA api IS 'schema used to create a public interface to the private schema';



CREATE VIEW api.enum_value AS
 SELECT t.typname AS enum_name,
    e.enumlabel AS enum_value,
    ec.comment
   FROM (((pg_type t
     JOIN pg_enum e ON ((t.oid = e.enumtypid)))
     JOIN pg_namespace n ON ((n.oid = t.typnamespace)))
     LEFT JOIN private.enum_comment ec ON (((ec.enum_type = t.typname) AND (ec.enum_value = e.enumlabel))))
  WHERE ((t.typtype = 'e'::"char") AND (n.nspname = 'private'::name))
  ORDER BY t.typname, e.enumsortorder;




COMMENT ON VIEW api.enum_value IS 'Shows all `api` schema enum types in the database with their values and comments';



CREATE VIEW api.stk_actor AS
 SELECT uu,
    table_name,
    created,
    created_by_uu,
    updated,
    updated_by_uu,
    is_active,
    is_template,
    is_valid,
    type_uu,
    parent_uu,
    search_key,
    name,
    name_first,
    name_middle,
    name_last,
    description,
    psql_user
   FROM private.stk_actor;




COMMENT ON VIEW api.stk_actor IS 'Holds actor records';



CREATE VIEW api.stk_actor_type AS
 SELECT uu,
    table_name,
    created,
    created_by_uu,
    updated,
    updated_by_uu,
    is_active,
    is_default,
    type_enum,
    search_key,
    name,
    description
   FROM private.stk_actor_type;




COMMENT ON VIEW api.stk_actor_type IS 'Holds the types of stk_actor records.';






















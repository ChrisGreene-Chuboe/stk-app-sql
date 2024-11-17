


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

SET default_tablespace = '';

SET default_table_access_method = heap;


CREATE TABLE private.stk_actor (
    stk_actor_uu uuid DEFAULT gen_random_uuid() NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_template boolean DEFAULT false NOT NULL,
    is_valid boolean DEFAULT true NOT NULL,
    stk_actor_type_uu uuid NOT NULL,
    stk_actor_parent_uu uuid,
    search_key text DEFAULT gen_random_uuid() NOT NULL,
    name text,
    name_first text,
    name_middle text,
    name_last text,
    description text,
    psql_user text,
    created_by_uu uuid NOT NULL,
    updated_by_uu uuid NOT NULL
);




COMMENT ON TABLE private.stk_actor IS 'Holds actor records';



CREATE TABLE private.stk_actor_type (
    stk_actor_type_uu uuid DEFAULT gen_random_uuid() NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    actor_type private.actor_type NOT NULL,
    search_key text DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text,
    created_by_uu uuid NOT NULL,
    updated_by_uu uuid NOT NULL
);




COMMENT ON TABLE private.stk_actor_type IS 'Holds the types of stk_actor records. To see a list of all actor_type enums and their comments, select from api.enum_value where enum_name is actor_type.';



CREATE TABLE private.stk_delme (
    stk_delme_uu uuid DEFAULT gen_random_uuid() NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    created_by_uu uuid,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_uu uuid,
    is_active boolean DEFAULT true NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    search_key text DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text
);




COMMENT ON TABLE private.stk_delme IS 'delete this table!!!';



CREATE TABLE private.stk_trigger_mgt (
    stk_trigger_mgt_uu uuid DEFAULT gen_random_uuid() NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    created_by_uu uuid,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_uu uuid,
    is_include boolean DEFAULT false NOT NULL,
    is_exclude boolean DEFAULT false NOT NULL,
    table_name text[] NOT NULL,
    function_name_prefix integer NOT NULL,
    function_name_root text NOT NULL,
    function_event text NOT NULL
);




COMMENT ON TABLE private.stk_trigger_mgt IS '`stk_trigger_mgt` is a table used to create triggers across mutiple tables. 

- Case when `is_include` and `is_exclude` are both false (default) then `table_name` is ignored and triggers are created on all tables in the `private` schema.
- Case when `is_include` = true then only create triggers for the tables in `table_name` array.
- Case when `is_exclude` = true then create the trigger for the `private` schema tables in `table_name` array.

Here is an example that will result in creating table triggers named stk_"table_name"_tgr_t1000 that call on a function named t1000_change_log() for all tables:

```sql
insert into private.stk_trigger_mgt (function_name_prefix,function_name_root,table_name,function_event) values (1000,''change_log'',''stk_change_log'',''BEFORE INSERT OR UPDATE OR DELETE'');
select private.stk_trigger_create();
```

Note that triggers will be created with the `t` prefix because psql does not like it when you create objects that begin with numbers.

Note that triggers are executed in alphabetical order. This is why we have a 0000-9999 number convention to easily create logical regions/sequences of execution.
';


















CREATE UNIQUE INDEX stk_actor_psql_user_uidx ON private.stk_actor USING btree (lower(psql_user)) WHERE (psql_user IS NOT NULL);


































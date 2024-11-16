


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



CREATE TABLE private.stk_attribute_tag (
    stk_attribute_tag_uu uuid DEFAULT gen_random_uuid() NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_template boolean DEFAULT false NOT NULL,
    is_valid boolean DEFAULT true NOT NULL,
    table_name text,
    record_uu uuid,
    stk_attribute_tag_type_uu uuid,
    attributes jsonb
);




COMMENT ON TABLE private.stk_attribute_tag IS 'Holds attribute tag records that describe other records in the system as referenced by table_name and record_uu. The attributes column holds the actual json attribute tag values used to describe the foreign record.';



CREATE TABLE private.stk_attribute_tag_type (
    stk_attribute_tag_type_uu uuid DEFAULT gen_random_uuid() NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    attribute_tag_type private.attribute_tag_type NOT NULL,
    search_key text DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text,
    attributes jsonb NOT NULL
);




COMMENT ON TABLE private.stk_attribute_tag_type IS 'Holds the types of stk_attribute_tag records. Attributes column holds a json template to be used when creating a new skt_attribute_tag record.';



CREATE TABLE private.stk_change_log (
    stk_change_log_uu uuid DEFAULT gen_random_uuid() NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    created_by_uu uuid NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_uu uuid NOT NULL,
    table_name text,
    record_uu uuid,
    column_name text,
    batch_id text,
    changes jsonb
);




COMMENT ON TABLE private.stk_change_log IS 'table to hold column level changes including inserts, updates and deletes to all table not in stk_change_log_exclude';



CREATE UNLOGGED TABLE private.stk_statistic (
    stk_statistic_uu uuid DEFAULT gen_random_uuid() NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    created_by_uu uuid NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_uu uuid NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    table_name text,
    record_uu uuid,
    stk_statistic_type_uu uuid DEFAULT gen_random_uuid(),
    search_key text DEFAULT gen_random_uuid() NOT NULL,
    description text,
    statistic jsonb NOT NULL
);




COMMENT ON TABLE private.stk_statistic IS 'Holds the system statistic records that make retriving cached calculations easier and faster without changing the actual table. Statistic column holds the actual json values used to describe the statistic.';



CREATE TABLE private.stk_statistic_type (
    stk_statistic_type_uu uuid DEFAULT gen_random_uuid() NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    created_by_uu uuid NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_uu uuid NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    statistic_type private.statistic_type NOT NULL,
    search_key text DEFAULT gen_random_uuid() NOT NULL,
    description text,
    statistic jsonb NOT NULL
);




COMMENT ON TABLE private.stk_statistic_type IS 'Holds the types of stk_statistic records. Statistic column holds a json template to be used when creating a new stk_statistic record.';



CREATE TABLE private.stk_system_config (
    stk_system_config_uu uuid DEFAULT gen_random_uuid() NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    stk_system_config_type_uu uuid DEFAULT gen_random_uuid(),
    search_key text DEFAULT gen_random_uuid() NOT NULL,
    description text,
    configuration jsonb NOT NULL
);




COMMENT ON TABLE private.stk_system_config IS 'Holds the system configuration records that dictates how the system behaves. Configuration column holds the actual json configuration values used to describe the system configuration.';



CREATE TABLE private.stk_system_config_type (
    stk_system_config_type_uu uuid DEFAULT gen_random_uuid() NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    system_config_level_type private.system_config_level_type NOT NULL,
    search_key text DEFAULT gen_random_uuid() NOT NULL,
    description text,
    configuration jsonb NOT NULL
);




COMMENT ON TABLE private.stk_system_config_type IS 'Holds the types of stk_system_config records. Configuration column holds a json template to be used when creating a new stk_system_config record.';



CREATE TABLE private.stk_wf_request (
    stk_wf_request_uu uuid DEFAULT gen_random_uuid() NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_template boolean DEFAULT false NOT NULL,
    is_valid boolean DEFAULT true NOT NULL,
    stk_wf_request_type_uu uuid NOT NULL,
    stk_wf_request_parent_uu uuid,
    name text NOT NULL,
    description text
);




COMMENT ON TABLE private.stk_wf_request IS 'Holds wf_request records';



CREATE TABLE private.stk_wf_request_type (
    stk_wf_request_type_uu uuid DEFAULT gen_random_uuid() NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    wf_request_type private.wf_request_type NOT NULL,
    search_key text DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text
);




COMMENT ON TABLE private.stk_wf_request_type IS 'Holds the types of stk_wf_request records. To see a list of all wf_request_type enums and their comments, select from api.enum_value where enum_name is wf_request_type.';



CREATE TABLE private.stk_change_log_exclude (
    stk_change_log_exclude_uu uuid DEFAULT gen_random_uuid() NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    table_name text
);




COMMENT ON TABLE private.stk_change_log_exclude IS 'table identifyinig all table_names that should not maintain change logs';



CREATE TABLE private.stk_form_post (
    stk_form_post_uu uuid DEFAULT gen_random_uuid() NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    created_by_uu uuid NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_uu uuid NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    form_data jsonb NOT NULL,
    description text
);




COMMENT ON TABLE private.stk_form_post IS 'table used to receive html form posts';



CREATE TABLE private.stk_trigger_mgt (
    stk_trigger_mgt_uu uuid DEFAULT gen_random_uuid() NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    created_by_uu uuid,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_uu uuid,
    is_include boolean DEFAULT false NOT NULL,
    is_exclude boolean DEFAULT false NOT NULL,
    table_name text NOT NULL,
    function_name_prefix integer NOT NULL,
    function_name_root text NOT NULL
);




COMMENT ON TABLE private.stk_trigger_mgt IS '`stk_trigger_mgt` is a table identifying all `table_name` that either need inclusion or exclusion when batch creating triggers for all listed functions.  

Setting `is_include` to true for a record automatically excludes all tables not already included for a given function. `is_include` and `is_exclude` must have different values for any given record. Said another way, either `is_include` or `is_exclude` must be set to true.

Here is an example that will result in creating table triggers named stk_"table_name"_tgr_t1000 that call on a function named t1000_change_log():

```sql
insert into private.stk_trigger_mgt (function_name_prefix,function_name_root,table_name,is_include,is_exclude) values (1000,''change_log'',''stk_change_log'',false,true);
select private.stk_trigger_create();
```
Note that triggers will be created with the `t` prefix because psql does not like it when you create objects that begin with numbers.

Note that triggers are executed in alphabetical order. This is why we have a 0000-9999 number convention to easily create logical regions of execution.
';



















































CREATE UNIQUE INDEX stk_actor_psql_user_uidx ON private.stk_actor USING btree (lower(psql_user)) WHERE (psql_user IS NOT NULL);














































































































































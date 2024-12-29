


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


CREATE TABLE private.stk_abbreviation (
    uu uuid DEFAULT gen_random_uuid() NOT NULL,
    table_name text GENERATED ALWAYS AS ('stk_appreviation'::text) STORED,
    stk_entity_uu uuid NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    created_by_uu uuid NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_uu uuid NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    search_key text DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text
);




COMMENT ON TABLE private.stk_abbreviation IS 'Holds stk_abbreviation records';



CREATE TABLE private.stk_actor (
    uu uuid DEFAULT gen_random_uuid() NOT NULL,
    table_name text GENERATED ALWAYS AS ('stk_actor'::text) STORED,
    created timestamp with time zone DEFAULT now() NOT NULL,
    created_by_uu uuid NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_uu uuid NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_template boolean DEFAULT false NOT NULL,
    is_valid boolean DEFAULT true NOT NULL,
    type_uu uuid NOT NULL,
    parent_uu uuid,
    search_key text DEFAULT gen_random_uuid() NOT NULL,
    name text,
    name_first text,
    name_middle text,
    name_last text,
    description text,
    psql_user text,
    stk_entity_uu uuid NOT NULL
);




COMMENT ON TABLE private.stk_actor IS 'Holds actor records';



CREATE TABLE private.stk_actor_type (
    uu uuid DEFAULT gen_random_uuid() NOT NULL,
    table_name text GENERATED ALWAYS AS ('stk_actor_type'::text) STORED,
    created timestamp with time zone DEFAULT now() NOT NULL,
    created_by_uu uuid NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_uu uuid NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    type_enum private.stk_actor_type_enum NOT NULL,
    search_key text DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text,
    stk_entity_uu uuid NOT NULL
);




COMMENT ON TABLE private.stk_actor_type IS 'Holds the types of stk_actor records. To see a list of all actor_type enums and their comments, select from api.enum_value where enum_name is actor_type.';



CREATE TABLE private.stk_async (
    uu uuid DEFAULT gen_random_uuid() NOT NULL,
    table_name text GENERATED ALWAYS AS ('stk_async'::text) STORED,
    created timestamp with time zone DEFAULT now() NOT NULL,
    created_by_uu uuid NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_uu uuid NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    type_uu uuid NOT NULL,
    date_processed timestamp with time zone,
    is_processed boolean GENERATED ALWAYS AS ((date_processed IS NOT NULL)) STORED,
    search_key text DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text,
    batch_id text
);




COMMENT ON TABLE private.stk_async IS 'Holds async records';



CREATE TABLE private.stk_async_type (
    uu uuid DEFAULT gen_random_uuid() NOT NULL,
    table_name text GENERATED ALWAYS AS ('stk_async_type'::text) STORED,
    created timestamp with time zone DEFAULT now() NOT NULL,
    created_by_uu uuid NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_uu uuid NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    type_enum private.stk_async_type_enum NOT NULL,
    search_key text DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text
);




COMMENT ON TABLE private.stk_async_type IS 'Holds the types of stk_async records. To see a list of all stk_async_type_enum enums and their comments, select from api.enum_value where enum_name is stk_async_type_enum.';



CREATE TABLE private.stk_attribute_tag (
    uu uuid DEFAULT gen_random_uuid() NOT NULL
);




CREATE TABLE private.stk_attribute_tag_part (
    uu uuid NOT NULL,
    table_name text GENERATED ALWAYS AS ('stk_attribute_tag'::text) STORED,
    stk_entity_uu uuid NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    created_by_uu uuid NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_uu uuid NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_template boolean DEFAULT false NOT NULL,
    is_valid boolean DEFAULT true NOT NULL,
    type_uu uuid NOT NULL,
    record_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    date_processed timestamp with time zone,
    is_processed boolean GENERATED ALWAYS AS ((date_processed IS NOT NULL)) STORED,
    search_key text DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text
)
PARTITION BY LIST (type_uu);




COMMENT ON TABLE private.stk_attribute_tag_part IS 'Holds attribute_tag records';



CREATE TABLE private.stk_attribute_tag_type (
    uu uuid DEFAULT gen_random_uuid() NOT NULL,
    table_name text GENERATED ALWAYS AS ('stk_attribute_tag_type'::text) STORED,
    stk_entity_uu uuid NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    created_by_uu uuid NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_uu uuid NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    is_singleton boolean DEFAULT false NOT NULL,
    type_enum private.stk_attribute_tag_type_enum NOT NULL,
    record_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    search_key text DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text
);




COMMENT ON TABLE private.stk_attribute_tag_type IS 'Holds the types of stk_attribute_tag records. To see a list of all stk_attribute_tag_type_enum enums and their comments, select from api.enum_value where enum_name is stk_attribute_tag_type_enum.';



CREATE TABLE private.stk_change_log (
    uu uuid DEFAULT gen_random_uuid() NOT NULL,
    table_name text GENERATED ALWAYS AS ('stk_change_log'::text) STORED,
    created timestamp with time zone DEFAULT now() NOT NULL,
    created_by_uu uuid NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_uu uuid NOT NULL,
    column_name text,
    record_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    batch_id text
);




COMMENT ON TABLE private.stk_change_log IS 'table to hold column level changes including inserts, updates and deletes to all table not in stk_change_log_exclude';



CREATE TABLE private.stk_changeme (
    uu uuid DEFAULT gen_random_uuid() NOT NULL,
    table_name text GENERATED ALWAYS AS ('stk_changeme'::text) STORED,
    stk_entity_uu uuid NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    created_by_uu uuid NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_uu uuid NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    type_uu uuid NOT NULL,
    search_key text DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text
);




COMMENT ON TABLE private.stk_changeme IS 'Holds changeme records';



CREATE TABLE private.stk_changeme_type (
    uu uuid DEFAULT gen_random_uuid() NOT NULL,
    table_name text GENERATED ALWAYS AS ('stk_changeme_type'::text) STORED,
    stk_entity_uu uuid NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    created_by_uu uuid NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_uu uuid NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    type_enum private.stk_changeme_type_enum NOT NULL,
    search_key text DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text
);




COMMENT ON TABLE private.stk_changeme_type IS 'Holds the types of stk_changeme records. To see a list of all stk_changeme_type_enum enums and their comments, select from api.enum_value where enum_name is stk_changeme_type_enum.';



CREATE TABLE private.stk_entity (
    uu uuid DEFAULT gen_random_uuid() NOT NULL,
    table_name text GENERATED ALWAYS AS ('stk_entity'::text) STORED,
    created timestamp with time zone DEFAULT now() NOT NULL,
    created_by_uu uuid NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_uu uuid NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_template boolean DEFAULT false NOT NULL,
    is_valid boolean DEFAULT true NOT NULL,
    type_uu uuid NOT NULL,
    parent_uu uuid,
    search_key text DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text
);




COMMENT ON TABLE private.stk_entity IS 'Holds entity records';



CREATE TABLE private.stk_entity_type (
    uu uuid DEFAULT gen_random_uuid() NOT NULL,
    table_name text GENERATED ALWAYS AS ('stk_entity_type'::text) STORED,
    created timestamp with time zone DEFAULT now() NOT NULL,
    created_by_uu uuid NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_uu uuid NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    type_enum private.stk_entity_type_enum NOT NULL,
    search_key text DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text
);




COMMENT ON TABLE private.stk_entity_type IS 'Holds the types of stk_entity records. To see a list of all stk_entity_type_enum enums and their comments, select from api.enum_value where enum_name is stk_entity_type_enum.';



CREATE TABLE private.stk_form_post (
    uu uuid DEFAULT gen_random_uuid() NOT NULL,
    table_name text GENERATED ALWAYS AS ('stk_form_post'::text) STORED,
    created timestamp with time zone DEFAULT now() NOT NULL,
    created_by_uu uuid NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_uu uuid NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    record_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    date_processed timestamp with time zone,
    is_processed boolean GENERATED ALWAYS AS ((date_processed IS NOT NULL)) STORED,
    description text
);




COMMENT ON TABLE private.stk_form_post IS 'Holds form_post records';



CREATE TABLE private.stk_request (
    uu uuid DEFAULT gen_random_uuid() NOT NULL,
    table_name text GENERATED ALWAYS AS ('stk_request'::text) STORED,
    stk_entity_uu uuid NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    created_by_uu uuid NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_uu uuid NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_template boolean DEFAULT false NOT NULL,
    is_valid boolean DEFAULT true NOT NULL,
    type_uu uuid NOT NULL,
    parent_uu uuid,
    date_processed timestamp with time zone,
    is_processed boolean GENERATED ALWAYS AS ((date_processed IS NOT NULL)) STORED,
    search_key text DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text
);




COMMENT ON TABLE private.stk_request IS 'Holds wf_request records';



CREATE TABLE private.stk_request_type (
    uu uuid DEFAULT gen_random_uuid() NOT NULL,
    table_name text GENERATED ALWAYS AS ('stk_request_type'::text) STORED,
    stk_entity_uu uuid NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    created_by_uu uuid NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_uu uuid NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    type_enum private.stk_request_type_enum NOT NULL,
    search_key text DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text
);




COMMENT ON TABLE private.stk_request_type IS 'Holds the types of stk_request records. To see a list of all stk_request_type_enum enums and their comments, select from api.enum_value where enum_name is stk_request_type_enum.';



CREATE TABLE private.stk_statistic (
    uu uuid DEFAULT gen_random_uuid() NOT NULL,
    table_name text GENERATED ALWAYS AS ('stk_statistic'::text) STORED,
    created timestamp with time zone DEFAULT now() NOT NULL,
    created_by_uu uuid NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_uu uuid NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    type_uu uuid NOT NULL,
    record_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    search_key text DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text
);




COMMENT ON TABLE private.stk_statistic IS 'Holds the system statistic records that make retriving cached calculations easier and faster without changing the actual table. Statistic column holds the actual json values used to describe the statistic.';



CREATE TABLE private.stk_statistic_type (
    uu uuid DEFAULT gen_random_uuid() NOT NULL,
    table_name text GENERATED ALWAYS AS ('stk_statistic_type'::text) STORED,
    stk_entity_uu uuid NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    created_by_uu uuid NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_uu uuid NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    type_enum private.stk_statistic_type_enum NOT NULL,
    record_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    search_key text DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text
);




COMMENT ON TABLE private.stk_statistic_type IS 'Holds the types of stk_statistic records. To see a list of all stk_statistic_type_enum enums and their comments, select from api.enum_value where enum_name is stk_statistic_type_enum.';



CREATE TABLE private.stk_system_config (
    uu uuid DEFAULT gen_random_uuid() NOT NULL,
    table_name text GENERATED ALWAYS AS ('stk_system_config'::text) STORED,
    created timestamp with time zone DEFAULT now() NOT NULL,
    created_by_uu uuid NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_uu uuid NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_valid boolean DEFAULT true NOT NULL,
    type_uu uuid NOT NULL,
    record_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    search_key text DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text
);




COMMENT ON TABLE private.stk_system_config IS 'Holds the system configuration records that dictates how the system behaves. Configuration column holds the actual json configuration values used to describe the system configuration.';



CREATE TABLE private.stk_system_config_type (
    uu uuid DEFAULT gen_random_uuid() NOT NULL,
    table_name text GENERATED ALWAYS AS ('stk_system_config_type'::text) STORED,
    created timestamp with time zone DEFAULT now() NOT NULL,
    created_by_uu uuid NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_uu uuid NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    type_enum private.stk_system_config_type_enum NOT NULL,
    record_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    search_key text DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text
);




COMMENT ON TABLE private.stk_system_config_type IS 'Holds the types of stk_system_config records. Configuration column holds a json template to be used when creating a new stk_system_config record.';



CREATE TABLE private.stk_attribute_tag_part_default (
    uu uuid NOT NULL,
    table_name text GENERATED ALWAYS AS ('stk_attribute_tag'::text) STORED,
    stk_entity_uu uuid NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    created_by_uu uuid NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_uu uuid NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_template boolean DEFAULT false NOT NULL,
    is_valid boolean DEFAULT true NOT NULL,
    type_uu uuid NOT NULL,
    record_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    date_processed timestamp with time zone,
    is_processed boolean GENERATED ALWAYS AS ((date_processed IS NOT NULL)) STORED,
    search_key text DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text
);




CREATE TABLE private.stk_change_log_exclude (
    uu uuid DEFAULT gen_random_uuid() NOT NULL,
    table_name text GENERATED ALWAYS AS ('stk_change_log_exclude'::text) STORED,
    created timestamp with time zone DEFAULT now() NOT NULL,
    created_by_uu uuid NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_uu uuid NOT NULL,
    table_name_exclude text
);




COMMENT ON TABLE private.stk_change_log_exclude IS 'table identifyinig all table_names that should not maintain change logs. Note: that normally a table like stk_change_log_exclude is not needed because you can simply hide a table from triggers using the private.stk_trigger_mgt table and the private.stk_trigger_create() function; however, we will eventually update this table to also be able to ignore columns (like passwords and other sensitive data) as well.';



CREATE TABLE private.stk_trigger_mgt (
    uu uuid DEFAULT gen_random_uuid() NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    created_by_uu uuid,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    updated_by_uu uuid,
    is_include boolean DEFAULT false NOT NULL,
    is_exclude boolean DEFAULT false NOT NULL,
    table_name text[],
    function_name_prefix integer NOT NULL,
    function_name_root text NOT NULL,
    function_event text NOT NULL
);




COMMENT ON TABLE private.stk_trigger_mgt IS '`stk_trigger_mgt` is a table used to create triggers across mutiple tables. 

- Case when `is_include` and `is_exclude` are both false (default) then `table_name` is ignored and triggers are created on all tables in the `private` schema.
- Case when `is_include` = true then only create triggers for the tables in `table_name` array.
- Case when `is_exclude` = true then create the trigger for the `private` schema tables in `table_name` array.

Here is an example that will result in creating table triggers named stk_"table_name"_tgr_t10100 that call on a function named t10100_stk_change_log() for all tables:

```sql
insert into private.stk_trigger_mgt (function_name_prefix,function_name_root,function_event) values (10100,''stk_change_log'',''BEFORE INSERT OR UPDATE OR DELETE'');
select private.stk_trigger_create();
```

Here is an example that will result in creating table triggers named stk_"table_name"_tgr_t10100 that call on a function named t10100_stk_change_log() for all tables except stk_change_log:

```sql
insert into private.stk_trigger_mgt (function_name_prefix,function_name_root,function_event,is_exclude,table_name) values (10100,''stk_change_log'',''AFTER INSERT OR UPDATE OR DELETE'',true,ARRAY[''stk_change_log'']);
select private.stk_trigger_create();
```

Note that triggers will be created with the `t` prefix because psql does not like it when you create objects that begin with numbers.

Note that triggers are executed in alphabetical order. This is why we have a 0000-9999 number convention to easily create logical regions/sequences of execution.
';




















































































CREATE UNIQUE INDEX stk_actor_psql_user_uidx ON private.stk_actor USING btree (lower(psql_user)) WHERE (psql_user IS NOT NULL);































































































































































































































































































































































































































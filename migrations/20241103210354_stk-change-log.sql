

-- set session to show stk_superuser as the actor performing all the tasks
SET stk.session = '{\"psql_user\": \"stk_superuser\"}';

CREATE TABLE private.stk_change_log (
  stk_change_log_uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu uuid NOT NULL,
  CONSTRAINT fk_some_table_createdby FOREIGN KEY (created_by_uu) REFERENCES private.stk_actor(stk_actor_uu),
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu uuid NOT NULL,
  CONSTRAINT fk_some_table_updatedby FOREIGN KEY (updated_by_uu) REFERENCES private.stk_actor(stk_actor_uu),
  table_name TEXT,
  record_uu UUID,
  column_name TEXT,
  batch_id TEXT,
  changes JSONB
);
COMMENT ON TABLE private.stk_change_log IS 'table to hold column level changes including inserts, updates and deletes to all table not in stk_change_log_exclude';

CREATE VIEW api.stk_change_log AS SELECT * FROM private.stk_change_log;
COMMENT ON VIEW api.stk_change_log IS 'Holds change_log records';

select private.stk_trigger_create();

CREATE TABLE private.stk_change_log_exclude (
  stk_change_log_exclude_uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu uuid NOT NULL,
  CONSTRAINT fk_some_table_createdby FOREIGN KEY (created_by_uu) REFERENCES private.stk_actor(stk_actor_uu),
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu uuid NOT NULL,
  CONSTRAINT fk_some_table_updatedby FOREIGN KEY (updated_by_uu) REFERENCES private.stk_actor(stk_actor_uu),
  table_name TEXT
);
COMMENT ON TABLE private.stk_change_log_exclude IS 'table identifyinig all table_names that should not maintain change logs. Note: that normally a table like stk_change_log_exclude is not needed because you can simply hide a table from triggers using the private.stk_trigger_mgt table and the private.stk_trigger_create() function; however, we will eventually update this table to also be able to ignore columns (like passwords and other sensitive data) as well.';

select private.stk_trigger_create();

insert into private.stk_change_log_exclude (table_name) values ('stk_change_log');

CREATE OR REPLACE FUNCTION private.t1000_change_log()
RETURNS TRIGGER AS $$
DECLARE
    old_row RECORD;
    new_row RECORD;
    column_name TEXT;
    json_output JSONB;
    column_value TEXT;
    is_different BOOLEAN;
    old_value TEXT;
    new_value TEXT;
    is_excluded BOOLEAN;
    table_pk_name TEXT;
    record_uu UUID;
    batch_id TEXT;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM private.stk_change_log_exclude
        WHERE table_name = TG_TABLE_NAME
    ) INTO is_excluded;

    -- If the table is excluded, exit the function
    IF is_excluded THEN
        RETURN NULL;
    END IF;

    SELECT TG_TABLE_NAME || '_uu' INTO table_pk_name;
    SELECT gen_random_uuid() INTO batch_id;

    IF TG_OP = 'INSERT' THEN
        EXECUTE format('SELECT ($1).%I', table_pk_name) INTO record_uu USING NEW;
        new_row := NEW;
        FOR column_name IN SELECT x.column_name FROM information_schema.columns x WHERE x.table_name = TG_TABLE_NAME LOOP
            EXECUTE format('SELECT ($1).%I::TEXT', column_name) INTO column_value USING new_row;
            json_output := json_build_object(
                'table', TG_TABLE_NAME,
                'schema', TG_TABLE_SCHEMA,
                'operation', TG_OP,
                'column', column_name,
                'new_value', column_value
            );
            INSERT INTO private.stk_change_log (batch_id, table_name, column_name, record_uu, changes)
                VALUES (batch_id, TG_TABLE_NAME, column_name, record_uu, json_output);
        END LOOP;
    ELSIF TG_OP = 'UPDATE' THEN
        EXECUTE format('SELECT ($1).%I', table_pk_name) INTO record_uu USING OLD;
        old_row := OLD;
        new_row := NEW;
        FOR column_name IN SELECT x.column_name FROM information_schema.columns x WHERE x.table_name = TG_TABLE_NAME LOOP
            EXECUTE format('SELECT ($1).%I::TEXT <> ($2).%I::TEXT OR (($1).%I IS NULL) <> (($2).%I IS NULL)',
                           column_name, column_name, column_name, column_name)
            INTO STRICT is_different USING old_row, new_row;

            IF is_different THEN
                EXECUTE format('SELECT ($1).%I::TEXT, ($2).%I::TEXT', column_name, column_name)
                INTO STRICT old_value, new_value USING old_row, new_row;
                json_output := json_build_object(
                    'table', TG_TABLE_NAME,
                    'schema', TG_TABLE_SCHEMA,
                    'operation', TG_OP,
                    'column', column_name,
                    'old_value', old_value,
                    'new_value', new_value
                );
                INSERT INTO private.stk_change_log (batch_id, table_name, column_name, record_uu, changes) 
                    VALUES (batch_id, TG_TABLE_NAME, column_name, record_uu, json_output);
            END IF;
        END LOOP;
    ELSIF TG_OP = 'DELETE' THEN
        EXECUTE format('SELECT ($1).%I', table_pk_name) INTO record_uu USING OLD;
        old_row := OLD;
        FOR column_name IN SELECT x.column_name FROM information_schema.columns x WHERE x.table_name = TG_TABLE_NAME LOOP
            EXECUTE format('SELECT ($1).%I::TEXT', column_name) INTO STRICT column_value USING old_row;
            json_output := json_build_object(
                'table', TG_TABLE_NAME,
                'schema', TG_TABLE_SCHEMA,
                'operation', TG_OP,
                'column', column_name,
                'old_value', column_value
            );
            INSERT INTO private.stk_change_log (batch_id, table_name, column_name, record_uu, changes) 
                VALUES (batch_id, TG_TABLE_NAME, column_name, record_uu, json_output);
        END LOOP;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER;
COMMENT ON FUNCTION private.t1000_change_log() IS 'create json object that highlight old vs new values when manipulating table records';

--no table exeption
insert into private.stk_trigger_mgt (function_name_prefix,function_name_root,function_event) values (1000,'change_log','AFTER INSERT OR UPDATE OR DELETE');

select private.stk_trigger_create();

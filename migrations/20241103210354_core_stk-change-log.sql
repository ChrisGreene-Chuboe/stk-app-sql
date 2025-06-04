

-- set session to show stk_superuser as the actor performing all the tasks
SET stk.session = '{\"psql_user\": \"stk_superuser\"}';

CREATE TABLE private.stk_change_log (
  uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT GENERATED ALWAYS AS ('stk_change_log') STORED,
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL, -- no FK by convention
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL, -- no FK by convention
  column_name TEXT,
  record_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  batch_id TEXT
);
COMMENT ON TABLE private.stk_change_log IS 'table to hold column level changes including inserts, updates and deletes to all table not in stk_change_log_exclude';

CREATE VIEW api.stk_change_log AS SELECT * FROM private.stk_change_log;
COMMENT ON VIEW api.stk_change_log IS 'Holds change_log records';

select private.stk_trigger_create();

CREATE TABLE private.stk_change_log_exclude (
  uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT generated always AS ('stk_change_log_exclude') stored,
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu uuid NOT NULL,
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu uuid NOT NULL,
  table_name_exclude TEXT
);
COMMENT ON TABLE private.stk_change_log_exclude IS 'table identifyinig all table_names that should not maintain change logs. Note: that normally a table like stk_change_log_exclude is not needed because you can simply hide a table from triggers using the private.stk_trigger_mgt table and the private.stk_trigger_create() function; however, we will eventually update this table to also be able to ignore columns (like passwords and other sensitive data) as well.';

select private.stk_trigger_create();

insert into private.stk_change_log_exclude (table_name_exclude) values ('stk_change_log');

CREATE OR REPLACE FUNCTION private.t10100_stk_change_log()
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
    batch_id_v TEXT;
    table_name_actual_parent_v TEXT; --this is the actual table name - needed to get columns in table (in case of partition)
    table_name_v TEXT; --this is the (generated) table_name returned from the table itself
    table_name_pk_v TEXT;
    record_uu_v UUID;
BEGIN

    -- Get the partition parent table name if exists
    -- split_part needed to remove schema prefix
    SELECT split_part(inhparent::regclass::text, '.', 2)
    INTO table_name_actual_parent_v
    FROM pg_inherits
    WHERE inhrelid = TG_RELID;

    IF table_name_actual_parent_v IS NULL THEN
        table_name_actual_parent_v := TG_TABLE_NAME;
    END IF;

    -- ask the table for its reporting table name - allows partitioned tables to report under uuid primary table
    BEGIN
        -- Try to access the column
        IF TG_OP IN ('INSERT','UPDATE') AND NEW.table_name IS NOT NULL AND NEW.uu IS NOT NULL THEN
            SELECT NEW.table_name INTO table_name_v;
            SELECT NEW.uu INTO record_uu_v;
            --RAISE NOTICE 't10100: insert-update table_name,uu %,%:',table_name_v,record_uu_v;
        ELSIF TG_OP IN ('DELETE') AND OLD.table_name IS NOT NULL AND OLD.uu IS NOT NULL THEN
            SELECT OLD.table_name INTO table_name_v;
            SELECT OLD.uu INTO record_uu_v;
            --RAISE NOTICE 't10100: delete table_name,uu %,%:',table_name_v,record_uu_v;
        ELSE
            SELECT table_name_actual_parent_v INTO table_name_v;
        END IF;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 't10100: table_name column does not exist table_name_v,record_uu_v: %,%:',table_name_v,record_uu_v;
        --TODO: need to return if table_name_v or record_uu_v do not exist
    END;

    SELECT EXISTS (
        SELECT 1
        FROM private.stk_change_log_exclude
        WHERE table_name_exclude in (table_name_actual_parent_v,table_name_v) 
    ) INTO is_excluded;

    -- If the table is excluded, exit the function
    IF is_excluded THEN
        RETURN NULL;
    END IF;

    SELECT 'uu' INTO table_name_pk_v; -- this is a relic of when the primary key included the table name
    --SELECT split_part(table_name_actual_parent_v, '.', 2) || '_uu' INTO table_name_pk_v;
    SELECT gen_random_uuid() INTO batch_id_v;

    --RAISE NOTICE 't10100 table_name_pk_v: %',table_name_pk_v;
    --RAISE NOTICE 't10100 table_name_actual_parent_v: %',table_name_actual_parent_v;


    IF TG_OP = 'INSERT' THEN
        --EXECUTE format('SELECT ($1).%I', table_name_pk_v) INTO record_uu USING NEW;
        new_row := NEW;
        FOR column_name IN SELECT x.column_name 
            FROM information_schema.columns x 
            WHERE x.table_name = table_name_actual_parent_v 
                AND x.table_schema = 'private'
        LOOP
            EXECUTE format('SELECT ($1).%I::TEXT', column_name) INTO column_value USING new_row;
            json_output := json_build_object(
                'table', table_name_v,
                'record_uu', record_uu_v,
                'schema', 'private',
                'operation', TG_OP,
                'column', column_name,
                'new_value', column_value
            );
            INSERT INTO private.stk_change_log (batch_id, column_name, record_json)
                VALUES (batch_id_v, column_name, json_output);
        END LOOP;
    ELSIF TG_OP = 'UPDATE' THEN
        --EXECUTE format('SELECT ($1).%I', table_name_pk_v) INTO record_uu USING OLD;
        old_row := OLD;
        new_row := NEW;
        FOR column_name IN SELECT x.column_name 
            FROM information_schema.columns x 
            WHERE x.table_name = table_name_actual_parent_v 
                AND x.table_schema = 'private'
        LOOP
            EXECUTE format('SELECT ($1).%I::TEXT <> ($2).%I::TEXT OR (($1).%I IS NULL) <> (($2).%I IS NULL)',
                           column_name, column_name, column_name, column_name)
            INTO STRICT is_different USING old_row, new_row;

            IF is_different THEN
                EXECUTE format('SELECT ($1).%I::TEXT, ($2).%I::TEXT', column_name, column_name)
                INTO STRICT old_value, new_value USING old_row, new_row;
                json_output := json_build_object(
                    'table', table_name_v,
                    'record_uu', record_uu_v,
                    'schema', 'private',
                    'operation', TG_OP,
                    'column', column_name,
                    'old_value', old_value,
                    'new_value', new_value
                );
                INSERT INTO private.stk_change_log (batch_id, column_name, record_json) 
                    VALUES (batch_id_v, column_name, json_output);
            END IF;
        END LOOP;
    ELSIF TG_OP = 'DELETE' THEN
        --EXECUTE format('SELECT ($1).%I', table_name_pk_v) INTO record_uu USING OLD;
        old_row := OLD;
        FOR column_name IN SELECT x.column_name 
            FROM information_schema.columns x 
            WHERE x.table_name = table_name_actual_parent_v 
                AND x.table_schema = 'private'
        LOOP
            EXECUTE format('SELECT ($1).%I::TEXT', column_name) INTO STRICT column_value USING old_row;
            json_output := json_build_object(
                'table', table_name_v,
                'record_uu', record_uu_v,
                'schema', 'private',
                'operation', TG_OP,
                'column', column_name,
                'old_value', column_value
            );
            INSERT INTO private.stk_change_log (batch_id, column_name, record_json) 
                VALUES (batch_id_v, column_name, json_output);
        END LOOP;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER;
COMMENT ON FUNCTION private.t10100_stk_change_log() IS 'create json object that highlight old vs new values when manipulating table records';

--no table exeption
insert into private.stk_trigger_mgt (function_name_prefix,function_name_root,function_event) values (10100,'stk_change_log','AFTER INSERT OR UPDATE OR DELETE');

select private.stk_trigger_create();

----sample data
--insert into api.stk_actor (name, type_uu) values ('delme1',(select uu from api.stk_actor_type limit 1));
--select * from api.stk_actor where name = 'delme1';
--update api.stk_actor set name = 'delme1a' where name = 'delme1';
--select * from api.stk_actor where name = 'delme1a';
--delete from api.stk_actor where name = 'delme1a';
--
--select * from api.stk_change_log;

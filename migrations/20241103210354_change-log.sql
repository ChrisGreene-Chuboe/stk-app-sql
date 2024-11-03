

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
BEGIN
    IF TG_OP = 'INSERT' THEN
        new_row := NEW;
        FOR column_name IN SELECT x.column_name FROM information_schema.columns x WHERE x.table_name = TG_TABLE_NAME LOOP
            IF new_row.* IS NOT NULL THEN
                EXECUTE format('SELECT ($1).%I::TEXT', column_name) INTO STRICT column_value USING new_row;
                IF column_value IS NOT NULL THEN
                    json_output := json_build_object(
                        'table', TG_TABLE_NAME,
                        'schema', TG_TABLE_SCHEMA,
                        'operation', TG_OP,
                        'column', column_name,
                        'new_value', column_value
                    );
                    RAISE NOTICE '%', json_output;
                END IF;
            END IF;
        END LOOP;
    ELSIF TG_OP = 'UPDATE' THEN
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
                RAISE NOTICE '%', json_output;
            END IF;
        END LOOP;
    ELSIF TG_OP = 'DELETE' THEN
        old_row := OLD;
        FOR column_name IN SELECT x.column_name FROM information_schema.columns x WHERE x.table_name = TG_TABLE_NAME LOOP
            IF old_row.* IS NOT NULL THEN
                EXECUTE format('SELECT ($1).%I::TEXT', column_name) INTO STRICT column_value USING old_row;
                IF column_value IS NOT NULL THEN
                    json_output := json_build_object(
                        'table', TG_TABLE_NAME,
                        'schema', TG_TABLE_SCHEMA,
                        'operation', TG_OP,
                        'column', column_name,
                        'old_value', column_value
                    );
                    RAISE NOTICE '%', json_output;
                END IF;
            END IF;
        END LOOP;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION private.stk_table_trigger_create()
RETURNS void AS $$
DECLARE
    table_record RECORD;
    trigger_name TEXT;
BEGIN
    FOR table_record IN
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'private'
          AND table_type = 'BASE TABLE'
    LOOP
        -- Derive the trigger name from the table name
        trigger_name := table_record.table_name || '_tgr_t1000';

        -- Check if the trigger already exists
        IF NOT EXISTS (
            SELECT 1
            FROM information_schema.triggers
            WHERE trigger_schema = 'private'
              AND event_object_table = table_record.table_name
              AND trigger_name = trigger_name
        ) THEN
            -- Create the trigger if it doesn't exist
            EXECUTE format(
                'CREATE TRIGGER %I
                 AFTER INSERT OR UPDATE OR DELETE ON private.%I
                 FOR EACH ROW EXECUTE FUNCTION private.t1000_change_log()',
                trigger_name,
                table_record.table_name
            );

            RAISE NOTICE 'Created trigger % on table private.%', trigger_name, table_record.table_name;
        ELSE
            RAISE NOTICE 'Trigger % already exists on table private.%', trigger_name, table_record.table_name;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;


--CREATE OR REPLACE FUNCTION private.stk_table_trigger_create()
--RETURNS event_trigger AS $$
--DECLARE
--    obj record;
--    trigger_name text;
--    current_db text;
--BEGIN
--    -- Get the current database name
--    SELECT current_database() INTO current_db;
--
--    FOR obj IN SELECT * FROM pg_event_trigger_ddl_commands()
--               WHERE command_tag = 'CREATE TABLE'
--                 AND (schema_name = 'private' OR schema_name IS NULL)
--    LOOP
--        -- Check if the table is in the current database and 'private' schema
--        IF obj.object_identity ~ ('^' || current_db || '\.private\.') THEN
--            ---- create change log ----
--            -- Derive the trigger name from the table name
--            trigger_name := obj.object_identity || '_tgr_t1000';
--
--            EXECUTE format(
--                'CREATE TRIGGER %I
--                 AFTER INSERT OR UPDATE OR DELETE ON %s
--                 FOR EACH ROW EXECUTE FUNCTION private.t1000_change_log()',
--                trigger_name,
--                obj.object_identity
--            );
--            ---- create change log ----
--        END IF;
--    END LOOP;
--END;
--$$ LANGUAGE plpgsql;

-- Create the event trigger
--CREATE EVENT TRIGGER stk_table_trigger_create_event ON ddl_command_end WHEN TAG IN ('CREATE TABLE') EXECUTE FUNCTION private.stk_table_trigger_create();

-- manual test
-- create table private.delme (name text, description text);
-- --create trigger delme_trg after insert or update or delete on private.delme for each row execute function private.t1000_change_log();
-- insert into private.delme values ('name1','desc1');
-- update private.delme set description = 'desc1 - updated';
-- delete from private.delme;



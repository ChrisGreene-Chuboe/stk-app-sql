

CREATE OR REPLACE FUNCTION private.t1010_created_updated()
RETURNS TRIGGER AS $$
DECLARE
    current_user_v uuid;
    psql_user_v text;
BEGIN

    BEGIN
        SELECT current_setting('stk.session', true)::json->>'psql_user' INTO psql_user_v;
    EXCEPTION
        WHEN OTHERS THEN
            psql_user_v := 'unknown';
    END;

    SELECT stk_actor_uu
    FROM private.stk_actor
    WHERE psql_user = psql_user_v
    INTO current_user_v;
    
    IF current_user_v IS NULL THEN 
        RAISE EXCEPTION 'no user found in session - current_user_v';
    END IF;

    IF TG_OP = 'INSERT' THEN
        NEW.created = now();
        NEW.updated = now();
        NEW.created_by_uu = current_user_v;
        NEW.updated_by_uu = current_user_v;
    ELSIF TG_OP = 'UPDATE' THEN
        NEW.created = OLD.created;
        NEW.updated = now();
        NEW.created_by_uu = OLD.created_by_uu;
        NEW.updated_by_uu = current_user_v;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER;
COMMENT ON FUNCTION private.t1010_created_updated() IS 'manages automatic updates to created,updated,created_by_uu and updated_by_uu';

--function to create all needed triggers
CREATE OR REPLACE FUNCTION private.stk_trigger_created_updated()
RETURNS void AS $$
DECLARE
    my_table_record RECORD;
    my_trigger_name TEXT;
BEGIN

    FOR my_table_record IN
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'private'
          AND table_type = 'BASE TABLE'
    LOOP
        -- START: create triggers for change_log (tgr_t1010)
        -- Derive the trigger name from the table name
        my_trigger_name := my_table_record.table_name || '_tgr_t1010';

        -- Check if the trigger already exists
        IF NOT EXISTS (
            SELECT 1
            FROM information_schema.triggers
            WHERE trigger_schema = 'private'
              AND event_object_table = my_table_record.table_name
              AND trigger_name = my_trigger_name
        ) THEN
            -- Create the trigger if it doesn't exist
            EXECUTE format(
                'CREATE TRIGGER %I
                 BEFORE INSERT OR UPDATE OR DELETE ON private.%I
                 FOR EACH ROW EXECUTE FUNCTION private.t1010_created_updated()',
                my_trigger_name,
                my_table_record.table_name
            );

            RAISE NOTICE 'Created trigger % on table private.%', my_trigger_name, my_table_record.table_name;
        ELSE
            --RAISE NOTICE 'Trigger % already exists on table private.%', my_trigger_name, my_table_record.table_name;
        END IF;
        -- END: create triggers for change_log (tgr_t1010)
    END LOOP;
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER;
COMMENT ON FUNCTION private.stk_trigger_created_updated() is 'Finds all tables that are missing created-updated triggers';

-- update all tables
select private.stk_trigger_created_updated();



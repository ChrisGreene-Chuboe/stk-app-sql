
-- needed for below NEW record manipulation
CREATE EXTENSION IF NOT EXISTS hstore;

-- generic view insert trigger function that be defined/associated with any partition table that resembles the convention above
CREATE OR REPLACE FUNCTION private.t00010_generic_partition_insert()
RETURNS TRIGGER AS $$
DECLARE
    table_name_primary_v TEXT;
    table_name_partition_v TEXT;
    key_column_primary_v TEXT;
    insert_columns_v TEXT[] := '{}';
    insert_values_v TEXT[] := '{}';
    sql_primary_v TEXT;
    sql_partition_v TEXT;
    column_name_v TEXT;
    column_value_v TEXT;
    record_uu_v UUID;
BEGIN
    -- Extract table names from TG_TABLE_NAME (assumes view name matches partition table base name)
    table_name_primary_v := 'private.' || TG_TABLE_NAME;
    table_name_partition_v := table_name_primary_v || '_part';
    key_column_primary_v := TG_TABLE_NAME || '_uu';

    -- Generate new UUID
    record_uu_v := gen_random_uuid();

    -- First insert into the primary table
    sql_primary_v := format(
        'INSERT INTO %s (%s) VALUES ($1) RETURNING %s',
        table_name_primary_v,
        key_column_primary_v,
        key_column_primary_v
    );

    EXECUTE sql_primary_v
    USING record_uu_v;

    -- Update NEW with the generated UUID
    -- Need to better understand how this works...
    NEW := NEW #= hstore(key_column_primary_v, record_uu_v::text);

    -- Dynamically build insert columns and values for partition table
    FOR column_name_v IN
        SELECT
            a.attname
        FROM pg_attribute a
        JOIN pg_class c ON c.oid = a.attrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'private'
        AND c.relname = TG_TABLE_NAME || '_part'
        AND a.attnum > 0
        AND NOT a.attisdropped
        AND a.attgenerated = ''  -- Skip generated columns
    LOOP
        -- Skip columns that should not be inserted directly
        IF column_name_v NOT IN ('table_name', 'record_uu') THEN
            -- Get the value of the column from NEW
            IF column_name_v = TG_TABLE_NAME || '_uu' THEN
                -- Use the record_uu_v value for the primary key reference
                column_value_v := record_uu_v::text;
            ELSE
                EXECUTE format('SELECT ($1).%I::text', column_name_v)
                INTO column_value_v
                USING NEW;
            END IF;

            IF column_value_v IS NOT NULL THEN
                insert_columns_v := array_append(insert_columns_v, column_name_v);
                insert_values_v := array_append(insert_values_v, format('%L', column_value_v));
            END IF;
        END IF;
    END LOOP;

    -- Build and execute the partition table insert
    sql_partition_v := format(
        'INSERT INTO %s (%s) VALUES (%s)',
        table_name_partition_v,
        array_to_string(insert_columns_v, ', '),
        array_to_string(insert_values_v, ', ')
    );

    EXECUTE sql_partition_v;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
COMMENT ON FUNCTION private.t00010_generic_partition_insert() IS 'Partition view generic insert trigger function';


CREATE OR REPLACE FUNCTION private.t00020_generic_partition_update()
RETURNS TRIGGER AS $$
DECLARE
    table_name_partition_v TEXT;
    update_set_clauses TEXT[] := '{}';
    sql_partition_v TEXT;
    column_name_v TEXT;
    old_value_v TEXT;
    new_value_v TEXT;
BEGIN
    -- Extract table name from TG_TABLE_NAME (assumes view name matches partition table base name)
    table_name_partition_v := 'private.' || TG_TABLE_NAME || '_part';

    -- Dynamically build update set clauses for partition table
    FOR column_name_v IN
        SELECT
            a.attname
        FROM pg_attribute a
        JOIN pg_class c ON c.oid = a.attrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'private'
        AND c.relname = TG_TABLE_NAME || '_part'
        AND a.attnum > 0
        AND NOT a.attisdropped
        AND a.attgenerated = ''  -- Skip generated columns
    LOOP
        -- Skip columns that should not be updated directly
        IF column_name_v NOT IN ('table_name', 'record_uu', TG_TABLE_NAME || '_uu') THEN
            -- Get the old and new values of the column
            EXECUTE format('SELECT ($1).%I::text', column_name_v)
            INTO old_value_v
            USING OLD;

            EXECUTE format('SELECT ($1).%I::text', column_name_v)
            INTO new_value_v
            USING NEW;

            -- Add to update clause if the value has changed
            IF new_value_v IS DISTINCT FROM old_value_v THEN
                update_set_clauses := array_append(
                    update_set_clauses,
                    format('%I = %L', column_name_v, new_value_v)
                );
            END IF;
        END IF;
    END LOOP;

    -- Only proceed if there are changes to make
    IF array_length(update_set_clauses, 1) > 0 THEN
        -- Build and execute the partition table update
        sql_partition_v := format(
            'UPDATE %s SET %s WHERE %I = %L',
            table_name_partition_v,
            array_to_string(update_set_clauses, ', '),
            TG_TABLE_NAME || '_uu',
            OLD.record_uu
        );

        EXECUTE sql_partition_v;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
COMMENT ON FUNCTION private.t00020_generic_partition_update() IS 'Partition view generic update trigger function';


CREATE OR REPLACE FUNCTION private.t00030_generic_partition_delete()
RETURNS TRIGGER AS $$
DECLARE
    table_name_primary_v TEXT;
    table_name_partition_v TEXT;
    sql_partition_v TEXT;
    sql_primary_v TEXT;
BEGIN
    -- Extract table names from TG_TABLE_NAME (assumes view name matches partition table base name)
    table_name_primary_v := 'private.' || TG_TABLE_NAME;
    table_name_partition_v := table_name_primary_v || '_part';

    -- First delete from the partition table
    sql_partition_v := format(
        'DELETE FROM %s WHERE %I = %L',
        table_name_partition_v,
        TG_TABLE_NAME || '_uu',
        OLD.record_uu
    );

    EXECUTE sql_partition_v;

    -- Then delete from the primary table
    sql_primary_v := format(
        'DELETE FROM %s WHERE %I = %L',
        table_name_primary_v,
        TG_TABLE_NAME || '_uu',
        OLD.record_uu
    );

    EXECUTE sql_primary_v;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
COMMENT ON FUNCTION private.t00030_generic_partition_delete() IS 'Partition view generic delete trigger function';


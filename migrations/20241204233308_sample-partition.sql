-- the purpose of this file is to hold a temporary example of creating a chuck-stack table with a partition by default
-- consider create update/delete trigger (like insert trigger)

-- set session to show stk_superuser as the actor performing all the tasks
SET stk.session = '{\"psql_user\": \"stk_superuser\"}';

CREATE TYPE private.stk_delme_type_enum AS ENUM (
    'NONE',
    'ACTION'
);
COMMENT ON TYPE private.stk_delme_type_enum IS 'Enum used in code to automate and validate delme types.';

INSERT INTO private.enum_comment (enum_type, enum_value, comment) VALUES
('stk_delme_type_enum', 'NONE', 'General purpose with no automation or validation'),
('stk_delme_type_enum', 'ACTION', 'Action purpose with no automation or validation')
;

CREATE TABLE private.stk_delme_type (
  stk_delme_type_uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT GENERATED ALWAYS AS ('stk_delme_type') STORED,
  record_uu UUID GENERATED ALWAYS AS (stk_delme_type_uu) STORED,
  stk_entity_uu UUID NOT NULL REFERENCES private.stk_entity(stk_entity_uu),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL,
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_default BOOLEAN NOT NULL DEFAULT false,
  stk_delme_type_enum private.stk_delme_type_enum NOT NULL,
  ----Prompt: ask the user if they need to store json
  --stk_delme_type_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  search_key TEXT NOT NULL DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT
);
COMMENT ON TABLE private.stk_delme_type IS 'Holds the types of stk_delme records. To see a list of all stk_delme_type_enum enums and their comments, select from api.enum_value where enum_name is stk_delme_type_enum.';

CREATE VIEW api.stk_delme_type AS SELECT * FROM private.stk_delme_type;
COMMENT ON VIEW api.stk_delme_type IS 'Holds the types of stk_delme records.';

-- delme primary table
-- this table is needed to support both (1) partitioning and (2) being able to maintain a single primary key and single foreign key references
CREATE TABLE private.stk_delme (
  stk_delme_uu UUID PRIMARY KEY DEFAULT gen_random_uuid()
);

-- delme partition table
CREATE TABLE private.stk_delme_part (
  stk_delme_uu UUID NOT NULL REFERENCES private.stk_delme(stk_delme_uu),
  table_name TEXT generated always AS ('stk_delme') stored,
  record_uu UUID GENERATED ALWAYS AS (stk_delme_uu) stored,
  stk_entity_uu UUID NOT NULL REFERENCES private.stk_entity(stk_entity_uu),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL,
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  ----Prompt: ask the user if they need to create templates
  is_template BOOLEAN NOT NULL DEFAULT false,
  ----Prompt: ask the user if they need validation
  is_valid BOOLEAN NOT NULL DEFAULT true,
  stk_delme_type_uu UUID NOT NULL REFERENCES private.stk_delme_type(stk_delme_type_uu),
  ----Prompt: ask the user if they need to create parent child relationships inside the table
  stk_delme_parent_uu UUID REFERENCES private.stk_delme(stk_delme_uu),
  ----Prompt: ask the user if they need to store json
  --stk_delme_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  ----Prompt: ask the user if they need to know when/if a record was processed
  --date_processed TIMESTAMPTZ,
  --is_processed BOOLEAN GENERATED ALWAYS AS (date_processed IS NOT NULL) STORED,
  search_key TEXT NOT NULL DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  primary key (stk_delme_uu, stk_delme_type_uu)
) PARTITION BY LIST (stk_delme_type_uu);
COMMENT ON TABLE private.stk_delme_part IS 'Holds delme records';

-- create the first partitioned table -- others can be created later
CREATE TABLE private.stk_delme_part_default PARTITION OF private.stk_delme_part DEFAULT;

CREATE VIEW api.stk_delme AS 
SELECT stkp.* 
FROM private.stk_delme stk
JOIN private.stk_delme_part stkp on stk.stk_delme_uu = stkp.stk_delme_uu
;
COMMENT ON VIEW api.stk_delme IS 'Holds delme records';

--TODO: We need a partition generic delete trigger similar to how t00010_generic_partition_insert() manages inserts
-- generic view insert trigger function that be defined/associated with any partition table that resembles the convention above
CREATE OR REPLACE FUNCTION api.t00010_generic_partition_insert()
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
BEGIN
    -- Extract table names from TG_TABLE_NAME (assumes view name matches partition table base name)
    table_name_primary_v := 'private.' || TG_TABLE_NAME;
    table_name_partition_v := table_name_primary_v || '_part';
    key_column_primary_v := TG_TABLE_NAME || '_uu';

    -- First insert into the primary table
    sql_primary_v := format(
        'INSERT INTO %s (%s) VALUES ($1) RETURNING %s',
        table_name_primary_v,
        key_column_primary_v,
        key_column_primary_v
    );

    EXECUTE sql_primary_v
    USING gen_random_uuid()
    INTO NEW.stk_delme_uu;

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
                -- Use the NEW.stk_delme_uu value for the primary key reference
                column_value_v := NEW.stk_delme_uu::text;
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
COMMENT ON FUNCTION api.t00010_generic_partition_insert() IS 'Partition view generic insert trigger function';

CREATE TRIGGER t00010_generic_partition_insert_tbl_stk_delme
    INSTEAD OF INSERT ON api.stk_delme
    FOR EACH ROW
    EXECUTE FUNCTION api.t00010_generic_partition_insert();




CREATE OR REPLACE FUNCTION api.t00020_generic_partition_update()
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
COMMENT ON FUNCTION api.t00020_generic_partition_update() IS 'Partition view generic update trigger function';

-- Create the update trigger for stk_delme
CREATE TRIGGER t00020_generic_partition_update_tbl_stk_delme
    INSTEAD OF UPDATE ON api.stk_delme
    FOR EACH ROW
    EXECUTE FUNCTION api.t00020_generic_partition_update();




CREATE OR REPLACE FUNCTION api.t00030_generic_partition_delete()
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
COMMENT ON FUNCTION api.t00030_generic_partition_delete() IS 'Partition view generic delete trigger function';

-- Create the delete trigger for stk_delme
CREATE TRIGGER t00030_generic_partition_delete_tbl_stk_delme
    INSTEAD OF DELETE ON api.stk_delme
    FOR EACH ROW
    EXECUTE FUNCTION api.t00030_generic_partition_delete();





-- create triggers for newly created tables
SELECT private.stk_trigger_create();
SELECT private.stk_table_type_create('stk_delme_type');

--insert into api.stk_delme (name, stk_delme_type_uu) values ('test1',(select stk_delme_type_uu from api.stk_delme_type limit 1)) returning stk_delme_uu;
--update api.stk_delme set name = 'test1a' where name = 'test1' returning stk_delme_uu;
--delete from api.stk_delme where name = 'test1a';

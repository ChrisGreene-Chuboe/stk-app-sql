-- The purpose of this script is to ensure the proper type and enaum values are set in a primary (non-type) table

CREATE OR REPLACE FUNCTION private.t10140_stk_type_default()
RETURNS TRIGGER AS $$
DECLARE
    has_type_column_v BOOLEAN;
    type_table_exists_v BOOLEAN;
    default_type_uu_v UUID;
BEGIN
    -- Check if the table has type_uu column
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = TG_TABLE_SCHEMA
        AND table_name = TG_TABLE_NAME
        AND column_name = 'type_uu'
    ) INTO has_type_column_v;
    --RAISE NOTICE 'table: %, has_column: %', TG_TABLE_NAME, has_type_column_v;

    -- If the table doesn't have type_uu column skip processing
    IF NOT has_type_column_v THEN
        RETURN NEW;
    END IF;

    -- If type_uu is not null, skip processing
    IF NEW.type_uu IS NOT NULL THEN
        RETURN NEW;
    END IF;

    -- Check if corresponding type table exists
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = TG_TABLE_SCHEMA
        AND table_name = TG_TABLE_NAME || '_type'
    ) INTO type_table_exists_v;

    -- If type table doesn't exist, skip processing
    IF NOT type_table_exists_v THEN
        RETURN NEW;
    END IF;

    -- Get default type from corresponding type table
    EXECUTE format('
        SELECT uu
        FROM %I.%I
        WHERE is_default = true
        LIMIT 1',
        TG_TABLE_SCHEMA,
        TG_TABLE_NAME || '_type'
    ) INTO default_type_uu_v;

    -- Set the type_uu to the default type
    IF default_type_uu_v IS NOT NULL THEN
        NEW.type_uu = default_type_uu_v;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER;
COMMENT ON FUNCTION private.t10140_stk_type_default() IS 'automatically sets type_uu to default type if null';

-- Register the trigger in the management table
INSERT INTO private.stk_trigger_mgt (function_name_prefix, function_name_root, function_event)
VALUES (10140, 'stk_type_default', 'BEFORE INSERT');

-- Create triggers for all applicable tables
SELECT private.stk_trigger_create();

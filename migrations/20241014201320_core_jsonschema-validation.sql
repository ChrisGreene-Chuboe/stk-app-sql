-- set session to show stk_superuser as the actor performing all the tasks
SET stk.session = '{"psql_user": "stk_superuser"}';

-- Create trigger function that validates record_json against corresponding _type table's jsonschema
-- This function follows the stk_trigger_create naming convention
CREATE OR REPLACE FUNCTION private.t10500_stk_validate_record_json_schema()
RETURNS TRIGGER AS $$
DECLARE
    v_schema jsonb;
    v_validation_result boolean;
    v_type_table_name text;
    v_base_table_name text;
    has_columns_v BOOLEAN;
BEGIN
    -- Skip validation for _type tables themselves (they store schemas, not data to validate)
    IF TG_TABLE_NAME LIKE '%_type' THEN
        RETURN NEW;
    END IF;
    
    -- Skip known tables that don't have the required columns
    IF TG_TABLE_NAME IN ('stk_change_log', 'stk_change_log_exclude', 'enum_comment') THEN
        RETURN NEW;
    END IF;
    
    -- Check if the table has both record_json and type_uu columns
    SELECT EXISTS (
        SELECT 1 
        FROM information_schema.columns c1
        JOIN information_schema.columns c2 
            ON c1.table_schema = c2.table_schema 
            AND c1.table_name = c2.table_name
        WHERE c1.table_schema = TG_TABLE_SCHEMA 
        AND c1.table_name = TG_TABLE_NAME 
        AND c1.column_name = 'record_json'
        AND c2.column_name = 'type_uu'
    ) INTO has_columns_v;
    
    -- If the table doesn't have the required columns, skip validation
    IF NOT has_columns_v THEN
        RETURN NEW;
    END IF;
    
    -- Extract base table name
    v_base_table_name := TG_TABLE_NAME;
    
    -- Determine the type table name by appending _type
    v_type_table_name := v_base_table_name || '_type';
    
    -- Get the schema from the corresponding _type table (always in private schema)
    -- Schema is now nested under json_schema key
    EXECUTE format('SELECT record_json->''json_schema'' FROM private.%I WHERE uu = $1', v_type_table_name)
    INTO v_schema
    USING NEW.type_uu;
    
    -- If no schema is defined (empty object, NULL, or missing json_schema key), allow any JSON
    IF v_schema IS NULL OR v_schema = 'null'::jsonb OR v_schema = '{}'::jsonb THEN
        RETURN NEW;
    END IF;
    
    -- Validate the record_json against the schema (using jsonb_matches_schema)
    v_validation_result := jsonb_matches_schema(v_schema::json, NEW.record_json);
    
    IF NOT v_validation_result THEN
        -- Get detailed validation errors (returns text array)
        DECLARE
            v_errors text[];
        BEGIN
            v_errors := jsonschema_validation_errors(v_schema::json, NEW.record_json::json);
            RAISE EXCEPTION 'JSON Schema validation failed for %.record_json: %', 
                TG_TABLE_NAME, array_to_string(v_errors, ', ');
        END;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER;

COMMENT ON FUNCTION private.t10500_stk_validate_record_json_schema() IS 
'Trigger function to validate record_json against the jsonschema defined in the corresponding _type table. Works for any non-_type table with record_json and type_uu columns.';

-- Add jsonschema validation to trigger management system
-- This will be applied to all tables with record_json and type_uu columns
INSERT INTO private.stk_trigger_mgt (
    is_include,
    is_exclude,
    table_name,
    function_name_prefix,
    function_name_root,
    function_event
) VALUES (
    false,  -- not include mode
    true,   -- exclude mode - we're excluding specific tables
    ARRAY['stk_change_log'],  -- exclude stk_change_log from this trigger
    10500,  -- using proper 5-digit sequence per convention
    'stk_validate_record_json_schema',
    'BEFORE INSERT OR UPDATE'
);

-- Now run stk_trigger_create to apply the new trigger
SELECT private.stk_trigger_create();
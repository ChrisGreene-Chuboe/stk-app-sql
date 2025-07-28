-- Create a trigger function to handle NULL search_key values
-- This ensures database defaults (gen_random_uuid()) work when search_key is explicitly NULL
CREATE OR REPLACE FUNCTION private.t10110_stk_search_key_default()
RETURNS TRIGGER AS $$
DECLARE
    has_column_v BOOLEAN;
BEGIN
    -- Only process INSERT operations
    IF TG_OP = 'INSERT' THEN
        
        -- Check if the table has search_key column
        SELECT EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = TG_TABLE_SCHEMA
            AND table_name = TG_TABLE_NAME
            AND column_name = 'search_key'
        ) INTO has_column_v;
        
        -- If the table doesn't have search_key column, return
        IF NOT has_column_v THEN
            RETURN NEW;
        END IF;
        
        -- Check if search_key is explicitly NULL
        -- The database default only applies when the column is not specified
        -- This trigger handles when the column IS specified but with NULL value
        IF NEW.search_key IS NULL THEN
            -- Generate a new UUID for search_key
            NEW.search_key = gen_random_uuid()::text;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION private.t10110_stk_search_key_default() IS 
'Handles explicit NULL values for search_key column by generating a UUID.
This complements the column DEFAULT constraint which only works when 
the column is not specified in the INSERT statement.
Only applies to tables that have a search_key column.';

-- Register this trigger function to be applied to all tables
-- The trigger function will check if search_key column exists
INSERT INTO private.stk_trigger_mgt (
    function_name_prefix,
    function_name_root,
    function_event
) VALUES (
    10110,
    'stk_search_key_default',
    'BEFORE INSERT'
);

-- Create triggers for all tables
-- The function will only act on tables with search_key column
SELECT private.stk_trigger_create();
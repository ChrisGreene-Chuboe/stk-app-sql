-- Create a trigger function to automatically generate line numbers
-- Used with tables with header_uu and sets search_key column
CREATE OR REPLACE FUNCTION private.t10120_stk_line_number()
RETURNS TRIGGER AS $$
DECLARE
    next_line_number_v INTEGER;
    has_column_v BOOLEAN;
BEGIN

    -- Only process INSERT operations
    IF TG_OP = 'INSERT' THEN

        -- Check if the table has the correct columns
        SELECT EXISTS (
            SELECT COUNT(*) = 2
            FROM information_schema.columns
            WHERE table_schema = TG_TABLE_SCHEMA
            AND table_name = TG_TABLE_NAME
            AND column_name in ('header_uu','search_key')
        ) INTO has_column_v;

        -- If the table doesn't have the correct columns, return
        IF NOT has_column_v THEN
            RETURN NEW;
        END IF;

        -- Check if search_key needs to be generated
        -- This handles: NULL, empty string, UUID pattern, or any non-numeric value
        IF NEW.search_key IS NULL OR 
           NEW.search_key = '' OR
           length(NEW.search_key) = 36 THEN --uuid auto-assigned
            -- Find the highest line number for this header
            EXECUTE format('
                SELECT COALESCE(MAX(CAST(search_key AS INTEGER)), 0) + 10
                FROM %I.%I
                WHERE header_uu = $1
                AND search_key ~ ''^[0-9]+$''
            ', TG_TABLE_SCHEMA, TG_TABLE_NAME)
            INTO next_line_number_v
            USING NEW.header_uu;

            -- Set the search_key to the next line number
            NEW.search_key = next_line_number_v::text;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION private.t10120_stk_line_number() IS 
'Automatically generates line numbers (10, 20, 30...) for tables with header_uu column.
Only applies when search_key is not manually provided.
Allows for manual override by providing a specific search_key value.';

-- Register this trigger function to be applied only to specific tables
INSERT INTO private.stk_trigger_mgt (
    is_include,
    table_name,
    function_name_prefix,
    function_name_root,
    function_event
) VALUES (
    true,  -- only apply to specified tables
    ARRAY['stk_invoice_line', 'stk_project_line'],  -- specific tables
    10120,
    'stk_line_number',
    'BEFORE INSERT'
);

-- Create triggers for specified tables
SELECT private.stk_trigger_create();


-- set session to show stk_superuser as the actor performing all the tasks
SET stk.session = '{"psql_user": "stk_superuser"}';

-- Function to find table_name for any UUID and return formatted table_name_uu_json
-- This enables easy request attachment by automatically discovering which table contains a UUID
CREATE OR REPLACE FUNCTION private.get_table_name_uu_json(target_uu UUID)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
    found_table_name TEXT;
    table_rec RECORD;
    sql_query TEXT;
    result_count INTEGER;
BEGIN
    -- Search through all tables that follow chuck-stack conventions
    -- (have uu primary key and table_name column)
    FOR table_rec IN 
        SELECT schemaname, tablename 
        FROM pg_tables 
        WHERE schemaname IN ('private', 'api')
        AND tablename NOT LIKE '%_part_%'  -- Skip partition tables
        ORDER BY schemaname, tablename
    LOOP
        -- Check if table has both uu and table_name columns
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = table_rec.schemaname 
            AND table_name = table_rec.tablename 
            AND column_name = 'uu'
        ) AND EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = table_rec.schemaname 
            AND table_name = table_rec.tablename 
            AND column_name = 'table_name'
        ) THEN
            -- Build dynamic query to check for UUID
            sql_query := format(
                'SELECT COUNT(*) FROM %I.%I WHERE uu = $1',
                table_rec.schemaname, 
                table_rec.tablename
            );
            
            -- Execute query and get count
            EXECUTE sql_query INTO result_count USING target_uu;
            
            -- If UUID found, get the table_name and return result
            IF result_count > 0 THEN
                sql_query := format(
                    'SELECT table_name FROM %I.%I WHERE uu = $1 LIMIT 1',
                    table_rec.schemaname, 
                    table_rec.tablename
                );
                
                EXECUTE sql_query INTO found_table_name USING target_uu;
                
                RETURN jsonb_build_object(
                    'table_name', found_table_name,
                    'uu', target_uu::text
                );
            END IF;
        END IF;
    END LOOP;
    
    -- UUID not found in any table
    RETURN jsonb_build_object(
        'table_name', '',
        'uu', target_uu::text,
        'error', 'UUID not found in any table'
    );
END;
$$;

COMMENT ON FUNCTION private.get_table_name_uu_json(UUID) IS 
'Searches all chuck-stack tables to find which table contains the given UUID. Returns formatted table_name_uu_json object ready for use in service tables like stk_request and stk_attribute_tag. Returns error in JSON if UUID not found.';

-- Create API wrapper function for public access
CREATE OR REPLACE FUNCTION api.get_table_name_uu_json(target_uu UUID)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
AS $$
    SELECT private.get_table_name_uu_json(target_uu);
$$;

COMMENT ON FUNCTION api.get_table_name_uu_json(UUID) IS 
'Public API wrapper for UUID table lookup. Searches all chuck-stack tables to find which table contains the given UUID. Returns formatted table_name_uu_json object ready for use in service tables like stk_request and stk_attribute_tag.';

-- Test function with a known UUID (if any exist)
-- SELECT api.get_table_name_uu_json('00000000-0000-0000-0000-000000000000'::uuid);

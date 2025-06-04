

CREATE OR REPLACE FUNCTION private.t10130_stk_search_key_uppercase()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = TG_TABLE_SCHEMA
          AND table_name = TG_TABLE_NAME
          AND column_name = 'search_key'
    ) THEN
        NEW.search_key = UPPER(NEW.search_key);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION private.t10130_stk_search_key_uppercase() IS 'Utility function to make the search key column value upper case if the column exists';


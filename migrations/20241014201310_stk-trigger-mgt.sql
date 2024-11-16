

CREATE TABLE private.stk_trigger_mgt (
  stk_trigger_mgt_uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu uuid,
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu uuid,
  is_include BOOLEAN NOT NULL DEFAULT false,
  is_exclude BOOLEAN NOT NULL DEFAULT false,
  table_name TEXT NOT NULL,
  function_name_prefix INTEGER NOT NULL,
  function_name_root TEXT NOT NULL

);
COMMENT ON TABLE private.stk_trigger_mgt IS '`stk_trigger_mgt` is a table identifying all `table_name` that either need inclusion or exclusion when batch creating triggers for all listed functions.  

Setting `is_include` to true for a record automatically excludes all tables not already included for a given function. `is_include` and `is_exclude` must have different values for any given record. Said another way, either `is_include` or `is_exclude` must be set to true.

Here is an example that will result in creating table triggers named stk_"table_name"_tgr_t1000 that call on a function named t1000_change_log():

```sql
insert into private.stk_trigger_mgt (function_name_prefix,function_name_root,table_name,is_include,is_exclude) values (1000,''change_log'',''stk_change_log'',false,true);
select private.stk_trigger_create();
```
Note that triggers will be created with the `t` prefix because psql does not like it when you create objects that begin with numbers.

Note that triggers are executed in alphabetical order. This is why we have a 0000-9999 number convention to easily create logical regions of execution.
';

CREATE OR REPLACE FUNCTION private.stk_trigger_create()
RETURNS void AS $$
DECLARE
    table_record_p RECORD;
    trigger_name_p TEXT;
    function_root_p RECORD;
    include_exists_p BOOLEAN;
BEGIN
    -- Loop through all distinct function_name_root in stk_trigger_mgt
    FOR function_root_p IN (SELECT DISTINCT function_name_root,function_name_prefix FROM private.stk_trigger_mgt)
    LOOP
        -- Check if any records exist where is_include = true for this function_name_root
        SELECT EXISTS (
            SELECT 1 FROM private.stk_trigger_mgt
            WHERE function_name_root = function_root_p.function_name_root AND is_include = true
        ) INTO include_exists_p;

        -- Create triggers for tables based on include/exclude logic
        FOR table_record_p IN
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = 'private'
              AND table_type = 'BASE TABLE'
              AND (
                  (include_exists_p AND table_name IN (
                      SELECT table_name FROM private.stk_trigger_mgt
                      WHERE function_name_root = function_root_p.function_name_root AND is_include = true
                  ))
                  OR
                  (NOT include_exists_p AND table_name NOT IN (
                      SELECT table_name FROM private.stk_trigger_mgt
                      WHERE function_name_root = function_root_p.function_name_root AND is_exclude = true
                  ))
              )
        LOOP
            -- Get the function_name_prefix for the current function_name_root
            SELECT function_name_prefix
            INTO trigger_name_p
            FROM private.stk_trigger_mgt
            WHERE function_name_root = function_root_p.function_name_root
            LIMIT 1;

            -- Derive the trigger name from the table name and function prefix
            trigger_name_p := 'stk_' || table_record_p.table_name || '_tgr_t' || trigger_name_p::text;

            -- Check if the trigger already exists
            IF NOT EXISTS (
                SELECT 1
                FROM information_schema.triggers
                WHERE trigger_schema = 'private'
                  AND event_object_table = table_record_p.table_name
                  AND trigger_name = trigger_name_p
            ) THEN
                -- Create the trigger if it doesn't exist
                EXECUTE format(
                    'CREATE TRIGGER %I
                     AFTER INSERT OR UPDATE OR DELETE ON private.%I
                     FOR EACH ROW EXECUTE FUNCTION private.t%s_%s()',
                    trigger_name_p,
                    table_record_p.table_name,
                    function_root_p.function_name_prefix,
                    function_root_p.function_name_root
                );

                RAISE NOTICE 'Created trigger % on table private.%', trigger_name_p, table_record_p.table_name;
            ELSE
                RAISE NOTICE 'Trigger % already exists on table private.%', trigger_name_p, table_record_p.table_name;
            END IF;
        END LOOP;
    END LOOP;
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER;

COMMENT ON FUNCTION private.stk_trigger_create() IS 'Creates triggers for tables based on stk_trigger_mgt configuration';

select private.stk_trigger_create();




CREATE TABLE private.stk_trigger_mgt (
  stk_trigger_mgt_uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_include BOOLEAN NOT NULL DEFAULT false,
  is_exclude BOOLEAN NOT NULL DEFAULT false,
  table_name TEXT,
  function_name_prefix INTEGER,
  function_name_root TEXT

);
COMMENT ON TABLE private.stk_trigger_mgt IS '`stk_trigger_mgt` is a table identifying all `table_name` that either need inclusion or exclusion when batch creating triggers for all listed functions.  

Setting `is_include` to true for a record automatically excludes all tables not already included for a given function. `is_include` and `is_exclude` must have different values for any given record. Said another way, either `is_include` or `is_exclude` must be set to true.

Here is an example that will result in creating table triggers named stk_"table_name"_tgr_t1000 that call on a function named t1000_change_log():

```sql
insert into private.stk_trigger_mgt (trigger_name_prefix,trigger_name_root,table_name,is_include,is_exclude) values (1000,''change_log'',''stk_change_log'',false,true);
```
';
----function to create all needed triggers
--CREATE OR REPLACE FUNCTION private.stk_trigger_create()
--RETURNS void AS $$
--DECLARE
--    table_record_p RECORD;
--    trigger_name_p TEXT;
--BEGIN
--
--    -- TODO: need loop here that finds and iterates across all distinct `function_name_root` in stk_trigger_mgt
--    -- iterate across
--
--        --TODO: for each distinct `function_name_root` see if any records exist where `is_include` = true - if so, ignore `is_exclude` records
--
--        --In the case of no `is_include` = true records, create triggers for non-excluded tables
--        --TODO: this for-loop needs to be improved because the function names are hard-coded
--        FOR table_record_p IN
--            SELECT table_name
--            FROM information_schema.tables
--            WHERE table_schema = 'private'
--              AND table_type = 'BASE TABLE'
--        LOOP
--            -- START: create triggers for change_log (tgr_t1000)
--            -- Derive the trigger name from the table name
--            trigger_name_p := table_record_p.table_name || '_tgr_t1000';
--
--            -- Check if the trigger already exists
--            IF NOT EXISTS (
--                SELECT 1
--                FROM information_schema.triggers
--                WHERE trigger_schema = 'private'
--                  AND event_object_table = table_record_p.table_name
--                  AND trigger_name = trigger_name_p
--            ) THEN
--                -- Create the trigger if it doesn't exist
--                EXECUTE format(
--                    'CREATE TRIGGER %I
--                     AFTER INSERT OR UPDATE OR DELETE ON private.%I
--                     FOR EACH ROW EXECUTE FUNCTION private.t1000_change_log()',
--                    trigger_name_p,
--                    table_record_p.table_name
--                );
--
--                RAISE NOTICE 'Created trigger % on table private.%', trigger_name_p, table_record_p.table_name;
--            ELSE
--                --RAISE NOTICE 'Trigger % already exists on table private.%', trigger_name_p, table_record_p.table_name;
--            END IF;
--            -- END: create triggers for change_log (tgr_t1000)
--        END LOOP;
--END;
--$$ LANGUAGE plpgsql
--SECURITY DEFINER;
--COMMENT ON FUNCTION private.stk_trigger_create() is 'Finds all tables that are missing triggers - such as change log';
--
---- update all tables
--select private.stk_trigger_create();
--
------ manual test
---- create table private.delme_trigger (delme_trigger_uu UUID PRIMARY KEY DEFAULT gen_random_uuid(), name text, description text);
---- select private.stk_trigger_create();
---- insert into private.delme_trigger (name, description) values ('name1','desc1');
---- insert into private.delme_trigger (name, description) values ('name2',null);
---- update private.delme_trigger set description = 'desc1 - updated' where name='name1';
---- update private.delme_trigger set description = 'desc2 - updated' where name='name2';
---- update private.delme_trigger set description = null where name='name2';
---- delete from private.delme_trigger;
---- select batch_id, table_name, column_name, record_uu, changes from private.stk_change_log;

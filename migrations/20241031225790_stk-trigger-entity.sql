

CREATE OR REPLACE FUNCTION private.t10120_stk_entity()
RETURNS TRIGGER AS $$
DECLARE
    entity_uu_v UUID;
    has_entity_column BOOLEAN;
BEGIN
   
    -- Check if the table has stk_entity_uu column
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = TG_TABLE_SCHEMA
        AND table_name = TG_TABLE_NAME
        AND column_name = 'stk_entity_uu'
    ) INTO has_entity_column;

    -- If the table doesn't have stk_entity_uu column or is a stk_entity table itself, skip processing
    IF NOT has_entity_column OR TG_TABLE_NAME IN ('stk_entity','stk_entity_type') THEN
        RETURN NEW;
    END IF;

    -- get default entity from session
    BEGIN
        --SELECT current_setting('stk.session', true)::json->>'psql_user' INTO psql_user_v;
        SELECT current_setting('stk.session', true)::json->>'stk_entity_uu' INTO entity_uu_v;
    EXCEPTION
        WHEN OTHERS THEN
            entity_uu_v := NULL;
    END;

    IF entity_uu_v IS NULL THEN
        RAISE NOTICE 't10120: reverting to * entity';
        SELECT e.stk_entity_uu
        INTO entity_uu_v
        FROM private.stk_entity e
            JOIN private.stk_entity_type et ON e.stk_entity_type_uu = et.stk_entity_type_uu
        WHERE et.stk_entity_type_enum = '*'
        ;
    END IF;

    IF entity_uu_v IS NULL THEN 
        RAISE EXCEPTION 'no entity found in session and no default entity found';
    END IF;

    IF TG_OP IN ('INSERT', 'UPDATE') AND NEW.stk_entity_uu IS NULL THEN
        NEW.stk_entity_uu = entity_uu_v;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER;
COMMENT ON FUNCTION private.t10120_stk_entity() IS 'automatically sets entity if null';

insert into private.stk_trigger_mgt (function_name_prefix,function_name_root,function_event) values (10120,'stk_entity','BEFORE INSERT OR UPDATE');

select private.stk_trigger_create();

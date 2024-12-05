

-- set session to show stk_superuser as the actor performing all the tasks
SET stk.session = '{\"psql_user\": \"stk_superuser\"}';

CREATE TYPE private.stk_changeme_type_enum AS ENUM (
    'NONE',
    'ACTION'
);
COMMENT ON TYPE private.stk_changeme_type_enum IS 'Enum used in code to automate and validate changeme types.';

INSERT INTO private.enum_comment (enum_type, enum_value, comment) VALUES
('stk_changeme_type_enum', 'NONE', 'General purpose with no automation or validation'),
('stk_changeme_type_enum', 'ACTION', 'Action purpose with no automation or validation')
;

CREATE TABLE private.stk_changeme_type (
  stk_changeme_type_uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT GENERATED ALWAYS AS ('stk_changeme_type') STORED,
  record_uu UUID GENERATED ALWAYS AS (stk_changeme_type_uu) STORED,
  stk_entity_uu UUID NOT NULL REFERENCES private.stk_entity(stk_entity_uu),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL,
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_default BOOLEAN NOT NULL DEFAULT false,
  stk_changeme_type_enum private.stk_changeme_type_enum NOT NULL,
  ----Prompt: ask the user if they need to store json
  --stk_changeme_type_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  search_key TEXT NOT NULL DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT
);
COMMENT ON TABLE private.stk_changeme_type IS 'Holds the types of stk_changeme records. To see a list of all stk_changeme_type_enum enums and their comments, select from api.enum_value where enum_name is stk_changeme_type_enum.';

CREATE VIEW api.stk_changeme_type AS SELECT * FROM private.stk_changeme_type;
COMMENT ON VIEW api.stk_changeme_type IS 'Holds the types of stk_changeme records.';

-- changeme primary table
-- this table is needed to support both (1) partitioning and (2) being able to maintain a single primary key and single foreign key references
CREATE TABLE private.stk_changeme (
  stk_changeme_uu UUID PRIMARY KEY DEFAULT gen_random_uuid()
);

-- changeme partition table
CREATE TABLE private.stk_changeme_part (
  stk_changeme_part_uu UUID NOT NULL REFERENCES private.stk_changeme(stk_changeme_uu),
  table_name TEXT generated always AS ('stk_changeme') stored,
  record_uu UUID GENERATED ALWAYS AS (stk_changeme_part_uu) stored,
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
  stk_changeme_type_uu UUID NOT NULL REFERENCES private.stk_changeme_type(stk_changeme_type_uu),
  ----Prompt: ask the user if they need to create parent child relationships inside the table
  stk_changeme_parent_uu UUID REFERENCES private.stk_changeme(stk_changeme_uu),
  ----Prompt: ask the user if they need to store json
  --stk_changeme_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  ----Prompt: ask the user if they need to know when/if a record was processed
  --date_processed TIMESTAMPTZ,
  --is_processed BOOLEAN GENERATED ALWAYS AS (date_processed IS NOT NULL) STORED,
  search_key TEXT NOT NULL DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  primary key (stk_changeme_part_uu, stk_changeme_type_uu)
) PARTITION BY LIST (stk_changeme_type_uu);
COMMENT ON TABLE private.stk_changeme_part IS 'Holds changeme records';

-- create the first partitioned table -- others can be created later
CREATE TABLE private.stk_changeme_part_default PARTITION OF private.stk_changeme_part DEFAULT;

CREATE VIEW api.stk_changeme AS 
SELECT * 
FROM private.stk_changeme c
JOIN private.stk_changeme_part cp on c.stk_changeme_uu = cp.stk_changeme_part_uu
;
COMMENT ON VIEW api.stk_changeme IS 'Holds changeme records';

-- Because the view uses multiple tables, we need a special way to persist the data when inserting into a view
-- I am not happy with the stk_changeme_insert() for two reasons: 1) I do not want to list every column if I do not need to, and 2) I do not want to repeat default logic for columns that might be null during the insert. TODO: Will solve this later using AI ...
CREATE OR REPLACE FUNCTION api.stk_changeme_insert()
RETURNS TRIGGER AS $$
BEGIN
    -- First insert into the primary table
    INSERT INTO private.stk_changeme
        (stk_changeme_uu)
    VALUES
        (COALESCE(NEW.stk_changeme_uu, gen_random_uuid()))
    RETURNING stk_changeme_uu INTO NEW.stk_changeme_uu;

    -- Then insert into the partition table
    INSERT INTO private.stk_changeme_part
        (stk_changeme_part_uu,
         --stk_entity_uu,
         created_by_uu,
         updated_by_uu,
         is_active,
         is_template,
         is_valid,
         stk_changeme_type_uu,
         stk_changeme_parent_uu,
         search_key,
         name,
         description)
    VALUES
        (NEW.stk_changeme_uu,
         --NEW.stk_entity_uu,
         NEW.created_by_uu,
         NEW.updated_by_uu,
         COALESCE(NEW.is_active, true),
         COALESCE(NEW.is_template, false),
         COALESCE(NEW.is_valid, true),
         NEW.stk_changeme_type_uu,
         NEW.stk_changeme_parent_uu,
         COALESCE(NEW.search_key, gen_random_uuid()::text),
         NEW.name,
         NEW.description);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER stk_changeme_insert_trigger
    INSTEAD OF INSERT ON api.stk_changeme
    FOR EACH ROW
    EXECUTE FUNCTION api.stk_changeme_insert();

-- create triggers for newly created tables
SELECT private.stk_trigger_create();
SELECT private.stk_table_type_create('stk_changeme_type');

--insert into api.stk_changeme (name, stk_changeme_type_uu) values ('test',(select stk_changeme_type_uu from api.stk_changeme_type limit 1));

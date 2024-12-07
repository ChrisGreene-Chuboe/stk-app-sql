

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
  stk_changeme_uu UUID NOT NULL REFERENCES private.stk_changeme(stk_changeme_uu),
  table_name TEXT generated always AS ('stk_changeme') stored,
  record_uu UUID GENERATED ALWAYS AS (stk_changeme_uu) stored,
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
  primary key (stk_changeme_uu, stk_changeme_type_uu)
) PARTITION BY LIST (stk_changeme_type_uu);
COMMENT ON TABLE private.stk_changeme_part IS 'Holds changeme records';

-- create the first partitioned table -- others can be created later
CREATE TABLE private.stk_changeme_part_default PARTITION OF private.stk_changeme_part DEFAULT;

CREATE VIEW api.stk_changeme AS 
SELECT stkp.* 
FROM private.stk_changeme stk
JOIN private.stk_changeme_part stkp on stk.stk_changeme_uu = stkp.stk_changeme_uu
;
COMMENT ON VIEW api.stk_changeme IS 'Holds changeme records';

CREATE TRIGGER t00010_generic_partition_insert_tbl_stk_changeme
    INSTEAD OF INSERT ON api.stk_changeme
    FOR EACH ROW
    EXECUTE FUNCTION private.t00010_generic_partition_insert();

CREATE TRIGGER t00020_generic_partition_update_tbl_stk_changeme
    INSTEAD OF UPDATE ON api.stk_changeme
    FOR EACH ROW
    EXECUTE FUNCTION private.t00020_generic_partition_update();

CREATE TRIGGER t00030_generic_partition_delete_tbl_stk_changeme
    INSTEAD OF DELETE ON api.stk_changeme
    FOR EACH ROW
    EXECUTE FUNCTION private.t00030_generic_partition_delete();


-- create triggers for newly created tables
SELECT private.stk_trigger_create();
SELECT private.stk_table_type_create('stk_changeme_type');

--insert into api.stk_changeme (name, stk_changeme_type_uu) values ('test1',(select stk_changeme_type_uu from api.stk_changeme_type limit 1)) returning stk_changeme_uu;
--update api.stk_changeme set name = 'test1a' where name = 'test1' returning stk_changeme_uu;
--delete from api.stk_changeme where name = 'test1a';


---- compare this to another table that is not partitioned to evaluate performance:
--insert into api.stk_request (name, stk_request_type_uu) values ('test1',(select stk_request_type_uu from api.stk_request_type limit 1)) returning stk_request_uu;
--update api.stk_request set name = 'test1a' where name = 'test1' returning stk_request_uu;
--delete from api.stk_request where name = 'test1a';

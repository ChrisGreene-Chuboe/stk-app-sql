

-- set session to show stk_superuser as the actor performing all the tasks
SET stk.session = '{\"psql_user\": \"stk_superuser\"}';

---- type_section start ----
CREATE TYPE private.stk_attribute_tag_type_enum AS ENUM (
    'NONE',
    'CONTRACT',
    'EMAIL',
    'PHONE',
    'SNS',
    'NOTE',
    'TRANSLATION',
    'ACTIVITY',
    'INTEREST_AREA',
    'ATTACHMENT',
    'LOCATION',
    'DATE_START',
    'DATE_END',
    'DATE_RANGE',
    'SHARE',
    'ERROR',
    'TABLE',
    'COLUMN'
);
COMMENT ON TYPE private.stk_attribute_tag_type_enum IS 'Enum used in code to automate and validate attribute_tag types.';

INSERT INTO private.enum_comment (enum_type, enum_value, comment) VALUES
('stk_attribute_tag_type_enum', 'NONE', 'General purpose with no automation or validation'),
('stk_attribute_tag_type_enum', 'COLUMN', 'Column attributes with no automation or validation')
;

CREATE TABLE private.stk_attribute_tag_type (
  stk_attribute_tag_type_uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT GENERATED ALWAYS AS ('stk_attribute_tag_type') STORED,
  record_uu UUID GENERATED ALWAYS AS (stk_attribute_tag_type_uu) STORED,
  stk_entity_uu UUID NOT NULL REFERENCES private.stk_entity(stk_entity_uu),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL, -- no FK by convention
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL, -- no FK by convention
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_default BOOLEAN NOT NULL DEFAULT false,
  is_singleton BOOLEAN NOT NULL DEFAULT false,
  stk_attribute_tag_type_enum private.stk_attribute_tag_type_enum NOT NULL,
  stk_attribute_tag_type_json JSONB NOT NULL DEFAULT '{"table_name": null, "record_uu": null, "value": {}}'::jsonb, -- just placeholder json for now
  search_key TEXT NOT NULL DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT
);
COMMENT ON TABLE private.stk_attribute_tag_type IS 'Holds the types of stk_attribute_tag records. To see a list of all stk_attribute_tag_type_enum enums and their comments, select from api.enum_value where enum_name is stk_attribute_tag_type_enum.';

CREATE VIEW api.stk_attribute_tag_type AS SELECT * FROM private.stk_attribute_tag_type;
COMMENT ON VIEW api.stk_attribute_tag_type IS 'Holds the types of stk_attribute_tag records.';

-- create triggers and type records for newly created tables
SELECT private.stk_trigger_create();
SELECT private.stk_table_type_create('stk_attribute_tag_type');
---- type_section end ----

---- primary_section start ----
-- primary table
-- this table is needed to support both (1) partitioning and (2) being able to maintain a single primary key and single foreign key references
CREATE TABLE private.stk_attribute_tag (
  stk_attribute_tag_uu UUID PRIMARY KEY DEFAULT gen_random_uuid()
);

-- partition table
CREATE TABLE private.stk_attribute_tag_part (
  stk_attribute_tag_uu UUID NOT NULL REFERENCES private.stk_attribute_tag(stk_attribute_tag_uu),
  table_name TEXT generated always AS ('stk_attribute_tag') stored,
  record_uu UUID GENERATED ALWAYS AS (stk_attribute_tag_uu) stored,
  stk_entity_uu UUID NOT NULL REFERENCES private.stk_entity(stk_entity_uu),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL, -- no FK by convention
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL, -- no FK by convention
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_template BOOLEAN NOT NULL DEFAULT false,
  is_valid BOOLEAN NOT NULL DEFAULT true,
  stk_attribute_tag_type_uu UUID NOT NULL REFERENCES private.stk_attribute_tag_type(stk_attribute_tag_type_uu),
  ----Prompt: ask the user if they need to create parent child relationships inside the table
  --stk_attribute_tag_parent_uu UUID REFERENCES private.stk_attribute_tag(stk_attribute_tag_uu),
  stk_attribute_tag_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  date_processed TIMESTAMPTZ,
  is_processed BOOLEAN GENERATED ALWAYS AS (date_processed IS NOT NULL) STORED,
  search_key TEXT NOT NULL DEFAULT gen_random_uuid(),
  description TEXT,
  primary key (stk_attribute_tag_uu, stk_attribute_tag_type_uu)
) PARTITION BY LIST (stk_attribute_tag_type_uu);
COMMENT ON TABLE private.stk_attribute_tag_part IS 'Holds attribute_tag records';

-- first partitioned table to hold the actual data -- others can be created later
CREATE TABLE private.stk_attribute_tag_part_default PARTITION OF private.stk_attribute_tag_part DEFAULT;

CREATE VIEW api.stk_attribute_tag AS
SELECT stkp.* -- note all values reside in and are pulled from the stk_attribute_tag_part table (not the primary stk_attribute_tag table)
FROM private.stk_attribute_tag stk
JOIN private.stk_attribute_tag_part stkp on stk.stk_attribute_tag_uu = stkp.stk_attribute_tag_uu
;
COMMENT ON VIEW api.stk_attribute_tag IS 'Holds attribute_tag records';

CREATE TRIGGER t00010_generic_partition_insert
    INSTEAD OF INSERT ON api.stk_attribute_tag
    FOR EACH ROW
    EXECUTE FUNCTION private.t00010_generic_partition_insert();

CREATE TRIGGER t00020_generic_partition_update
    INSTEAD OF UPDATE ON api.stk_attribute_tag
    FOR EACH ROW
    EXECUTE FUNCTION private.t00020_generic_partition_update();

CREATE TRIGGER t00030_generic_partition_delete
    INSTEAD OF DELETE ON api.stk_attribute_tag
    FOR EACH ROW
    EXECUTE FUNCTION private.t00030_generic_partition_delete();
---- primary_section end ----

-- create triggers for newly created tables
SELECT private.stk_trigger_create();


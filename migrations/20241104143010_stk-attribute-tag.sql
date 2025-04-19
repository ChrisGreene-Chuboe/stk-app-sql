

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

INSERT INTO private.enum_comment (enum_type, enum_value, comment, is_default) VALUES
('stk_attribute_tag_type_enum', 'NONE', 'General purpose with no automation or validation', true),
('stk_attribute_tag_type_enum', 'COLUMN', 'Column attributes with no automation or validation', false)
;

CREATE TABLE private.stk_attribute_tag_type (
  uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT GENERATED ALWAYS AS ('stk_attribute_tag_type') STORED,
  stk_entity_uu UUID NOT NULL REFERENCES private.stk_entity(uu),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL, -- no FK by convention
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL, -- no FK by convention
  revoked TIMESTAMPTZ,
  is_revoked BOOLEAN GENERATED ALWAYS AS (revoked IS NOT NULL) STORED,
  is_default BOOLEAN NOT NULL DEFAULT false,
  is_singleton BOOLEAN NOT NULL DEFAULT false,
  type_enum private.stk_attribute_tag_type_enum NOT NULL,
  record_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  search_key TEXT NOT NULL UNIQUE DEFAULT gen_random_uuid(),
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
  uu UUID PRIMARY KEY DEFAULT gen_random_uuid()
);

-- partition table
CREATE TABLE private.stk_attribute_tag_part (
  uu UUID NOT NULL REFERENCES private.stk_attribute_tag(uu),
  table_name TEXT generated always AS ('stk_attribute_tag') stored,
  stk_entity_uu UUID NOT NULL REFERENCES private.stk_entity(uu),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL, -- no FK by convention
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL, -- no FK by convention
  revoked TIMESTAMPTZ,
  is_revoked BOOLEAN GENERATED ALWAYS AS (revoked IS NOT NULL) STORED,
  is_template BOOLEAN NOT NULL DEFAULT false,
  is_valid BOOLEAN NOT NULL DEFAULT true,
  type_uu UUID NOT NULL REFERENCES private.stk_attribute_tag_type(uu),
  ----Prompt: ask the user if they need to create parent child relationships inside the table
  --parent_uu UUID REFERENCES private.stk_attribute_tag(uu),
  record_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  processed TIMESTAMPTZ,
  is_processed BOOLEAN GENERATED ALWAYS AS (processed IS NOT NULL) STORED,
  search_key TEXT NOT NULL DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  primary key (uu, type_uu)
) PARTITION BY LIST (type_uu);
COMMENT ON TABLE private.stk_attribute_tag_part IS 'Holds attribute_tag records';

-- first partitioned table to hold the actual data -- others can be created later
CREATE TABLE private.stk_attribute_tag_part_default PARTITION OF private.stk_attribute_tag_part DEFAULT;


CREATE VIEW api.stk_attribute_tag AS
SELECT stkp.* -- note all values reside in and are pulled from the stk_attribute_tag_part table (not the primary stk_attribute_tag table)
FROM private.stk_attribute_tag stk
JOIN private.stk_attribute_tag_part stkp on stk.uu = stkp.uu
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


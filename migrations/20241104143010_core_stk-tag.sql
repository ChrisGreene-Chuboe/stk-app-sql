

-- set session to show stk_superuser as the actor performing all the tasks
SET stk.session = '{\"psql_user\": \"stk_superuser\"}';

---- type_section start ----
CREATE TYPE private.stk_tag_type_enum AS ENUM (
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
    'ADDRESS',
    'DATE_START',
    'DATE_END',
    'DATE_RANGE',
    'SHARE',
    'ERROR',
    'TABLE',
    'COLUMN'
);
COMMENT ON TYPE private.stk_tag_type_enum IS 'Enum used in code to automate and validate tag types.';

INSERT INTO private.enum_comment (enum_type, enum_value, comment, is_default, record_json) VALUES
('stk_tag_type_enum', 'NONE', 'General purpose with no automation or validation', true, NULL),
('stk_tag_type_enum', 'COLUMN', 'Column attributes with no automation or validation', false, NULL),
('stk_tag_type_enum', 'ADDRESS', 'Physical or mailing address information including street, city, postal code', false, 
    '{
        "$schema": "http://json-schema.org/draft-07/schema#",
        "type": "object",
        "properties": {
            "address1": {"type": "string"},
            "address2": {"type": "string"},
            "city": {"type": "string"},
            "state": {"type": "string"},
            "postal": {"type": "string"},
            "country": {"type": "string"}
        },
        "required": ["address1", "city", "postal"]
    }'::jsonb)
;

CREATE TABLE private.stk_tag_type (
  uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT GENERATED ALWAYS AS ('stk_tag_type') STORED,
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL, -- no FK by convention
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL, -- no FK by convention
  revoked TIMESTAMPTZ,
  is_revoked BOOLEAN GENERATED ALWAYS AS (revoked IS NOT NULL) STORED,
  is_default BOOLEAN NOT NULL DEFAULT false,
  is_singleton BOOLEAN NOT NULL DEFAULT false,
  type_enum private.stk_tag_type_enum NOT NULL,
  record_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  search_key TEXT NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT
);
COMMENT ON TABLE private.stk_tag_type IS 'Holds the types of stk_tag records. To see a list of all stk_tag_type_enum enums and their comments, select from api.enum_value where enum_name is stk_tag_type_enum.';

CREATE VIEW api.stk_tag_type AS SELECT * FROM private.stk_tag_type;
COMMENT ON VIEW api.stk_tag_type IS 'Holds the types of stk_tag records.';

-- create triggers and type records for newly created tables
SELECT private.stk_trigger_create();
SELECT private.stk_table_type_create('stk_tag_type');
---- type_section end ----

---- primary_section start ----
CREATE TABLE private.stk_tag (
  uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT generated always AS ('stk_tag') stored,
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL, -- no FK by convention
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL, -- no FK by convention
  revoked TIMESTAMPTZ,
  is_revoked BOOLEAN GENERATED ALWAYS AS (revoked IS NOT NULL) STORED,
  table_name_uu_json JSONB NOT NULL DEFAULT '{"table_name": "","uu": ""}'::jsonb,
  is_template BOOLEAN NOT NULL DEFAULT false,
  is_valid BOOLEAN NOT NULL DEFAULT true,
  type_uu UUID NOT NULL REFERENCES private.stk_tag_type(uu),
  record_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  processed TIMESTAMPTZ,
  is_processed BOOLEAN GENERATED ALWAYS AS (processed IS NOT NULL) STORED,
  search_key TEXT NOT NULL DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT
);
COMMENT ON TABLE private.stk_tag IS 'Holds tag records that can be attached to any table to provide flexible metadata and attributes';

CREATE VIEW api.stk_tag AS SELECT * FROM private.stk_tag;
COMMENT ON VIEW api.stk_tag IS 'Holds tag records that can be attached to any table to provide flexible metadata and attributes';
---- primary_section end ----

-- create triggers for newly created tables
SELECT private.stk_trigger_create();


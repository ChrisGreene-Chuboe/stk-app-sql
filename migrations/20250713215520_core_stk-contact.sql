-- set session to show stk_superuser as the actor performing all the tasks
SET stk.session = '{\"psql_user\": \"stk_superuser\"}';

---- type_section start ----
CREATE TYPE private.stk_contact_type_enum AS ENUM (
    'GENERAL'
);
COMMENT ON TYPE private.stk_contact_type_enum IS 'Enum used in code to automate and validate contact types.';

INSERT INTO private.enum_comment (enum_type, enum_value, comment, is_default, record_json) VALUES
('stk_contact_type_enum', 'GENERAL', 'General purpose contact with no specific code automation', true,
    '{
        "json_schema": {
            "$schema": "http://json-schema.org/draft-07/schema#",
            "type": "object",
            "properties": {
                "email": {"type": "string", "format": "email"},
                "phone": {"type": "string"},
                "mobile": {"type": "string"},
                "fax": {"type": "string"},
                "website": {"type": "string", "format": "uri"},
                "title": {"type": "string"},
                "department": {"type": "string"}
            },
            "required": []
        }
    }'::jsonb)
;

CREATE TABLE private.stk_contact_type (
  uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT GENERATED ALWAYS AS ('stk_contact_type') STORED,
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL, -- no FK by convention
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL, -- no FK by convention
  revoked TIMESTAMPTZ,
  is_revoked BOOLEAN GENERATED ALWAYS AS (revoked IS NOT NULL) STORED,
  is_default BOOLEAN NOT NULL DEFAULT false,
  type_enum private.stk_contact_type_enum NOT NULL,
  record_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  search_key TEXT NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT
);
COMMENT ON TABLE private.stk_contact_type IS 'Holds the types of stk_contact records. To see a list of all stk_contact_type_enum enums and their comments, select from api.enum_value where enum_name is stk_contact_type_enum.';

CREATE VIEW api.stk_contact_type AS SELECT * FROM private.stk_contact_type;
COMMENT ON VIEW api.stk_contact_type IS 'Holds the types of stk_contact records.';

-- create triggers and type records for newly created tables
SELECT private.stk_trigger_create();
SELECT private.stk_table_type_create('stk_contact_type');
---- type_section end ----

---- primary_section start ----
----partition: insert_primary
CREATE TABLE private.stk_contact ( ----partition: rename_table
  uu UUID PRIMARY KEY DEFAULT gen_random_uuid(), ----partition: change_uu
  table_name TEXT generated always AS ('stk_contact') stored,
  ----Prompt: ask the user if they need to assign this record to a specific entity
  --stk_entity_uu UUID NOT NULL REFERENCES private.stk_entity(uu),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL, -- no FK by convention
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL, -- no FK by convention
  revoked TIMESTAMPTZ,
  is_revoked BOOLEAN GENERATED ALWAYS AS (revoked IS NOT NULL) STORED,
  ----Prompt: ask the user if this table needs to reference another table's record
  --table_name_uu_json JSONB NOT NULL DEFAULT '{"table_name": "","uu": ""}'::jsonb,
  ----Prompt: ask the user if they need to create templates
  --is_template BOOLEAN NOT NULL DEFAULT false,
  ----Prompt: ask the user if they need validation
  is_valid BOOLEAN NOT NULL DEFAULT true, -- Contact data should be validated
  type_uu UUID NOT NULL REFERENCES private.stk_contact_type(uu),
  stk_business_partner_uu UUID REFERENCES private.stk_business_partner(uu), -- Link to business partner when applicable
  ----Prompt: ask the user if they need to create parent child relationships inside the table
  --parent_uu UUID REFERENCES private.stk_contact(uu),
  ----Prompt: ask the user if this table represents lines that belong to a header record
  --header_uu UUID NOT NULL REFERENCES private.stk_contact(uu),
  ----Prompt: ask the user if they need to store json
  record_json JSONB NOT NULL DEFAULT '{}'::jsonb, -- Store flexible contact attributes
  ----Prompt: ask the user if they need to know when/if a record was processed
  --processed TIMESTAMPTZ,
  --is_processed BOOLEAN GENERATED ALWAYS AS (processed IS NOT NULL) STORED,
  search_key TEXT NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT ----partition: add_pk
); ----partition: add_partition_by
COMMENT ON TABLE private.stk_contact IS 'Holds contact records';
----partition: insert_default

CREATE VIEW api.stk_contact AS SELECT * FROM private.stk_contact;
COMMENT ON VIEW api.stk_contact IS 'Holds contact records';
----partition: insert_triggers
---- primary_section end ----

-- create triggers for newly created tables
SELECT private.stk_trigger_create();

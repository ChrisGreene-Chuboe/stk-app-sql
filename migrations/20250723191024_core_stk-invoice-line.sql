-- set session to show stk_superuser as the actor performing all the tasks
SET stk.session = '{\"psql_user\": \"stk_superuser\"}';

---- type_section start ----
CREATE TYPE private.stk_invoice_line_type_enum AS ENUM (
    'ITEM',
    'DESCRIPTION',
    'DISCOUNT'
);
COMMENT ON TYPE private.stk_invoice_line_type_enum IS 'Enum used in code to automate and validate invoice_line types.';

INSERT INTO private.enum_comment (enum_type, enum_value, comment, is_default) VALUES
('stk_invoice_line_type_enum', 'ITEM', 'Item being invoiced (product or service)', true),
('stk_invoice_line_type_enum', 'DESCRIPTION', 'Descriptive line with no monetary value', false),
('stk_invoice_line_type_enum', 'DISCOUNT', 'Discount applied to invoice', false)
;

CREATE TABLE private.stk_invoice_line_type (
  uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT GENERATED ALWAYS AS ('stk_invoice_line_type') STORED,
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL, -- no FK by convention
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL, -- no FK by convention
  revoked TIMESTAMPTZ,
  is_revoked BOOLEAN GENERATED ALWAYS AS (revoked IS NOT NULL) STORED,
  is_default BOOLEAN NOT NULL DEFAULT false,
  type_enum private.stk_invoice_line_type_enum NOT NULL,
  record_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  search_key TEXT NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT
);
COMMENT ON TABLE private.stk_invoice_line_type IS 'Holds the types of stk_invoice_line records. To see a list of all stk_invoice_line_type_enum enums and their comments, select from api.enum_value where enum_name is stk_invoice_line_type_enum.';

CREATE VIEW api.stk_invoice_line_type AS SELECT * FROM private.stk_invoice_line_type;
COMMENT ON VIEW api.stk_invoice_line_type IS 'Holds the types of stk_invoice_line records.';

-- create triggers and type records for newly created tables
SELECT private.stk_trigger_create();
SELECT private.stk_table_type_create('stk_invoice_line_type');
---- type_section end ----

---- primary_section start ----
----partition: insert_primary
CREATE TABLE private.stk_invoice_line ( ----partition: rename_table
  uu UUID PRIMARY KEY DEFAULT gen_random_uuid(), ----partition: change_uu
  table_name TEXT generated always AS ('stk_invoice_line') stored,
  ----Prompt: ask the user if they need to assign this record to a specific entity
  --stk_entity_uu UUID NOT NULL REFERENCES private.stk_entity(uu), -- NO - inherits from header
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL, -- no FK by convention
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL, -- no FK by convention
  revoked TIMESTAMPTZ,
  is_revoked BOOLEAN GENERATED ALWAYS AS (revoked IS NOT NULL) STORED,
  ----Prompt: ask the user if this table needs to reference another table's record
  --table_name_uu_json JSONB NOT NULL DEFAULT '{"table_name": "","uu": ""}'::jsonb, -- NO - using direct stk_item_uu
  ----Prompt: ask the user if they need to create templates
  --is_template BOOLEAN NOT NULL DEFAULT false, -- NO - lines aren't templated
  ----Prompt: ask the user if they need validation
  is_valid BOOLEAN NOT NULL DEFAULT true, -- YES - for line validation
  type_uu UUID NOT NULL REFERENCES private.stk_invoice_line_type(uu),
  ----Prompt: ask the user if they need to create parent child relationships inside the table
  --parent_uu UUID REFERENCES private.stk_invoice_line(uu), -- NO - uses header_uu instead
  ----Prompt: ask the user if this table represents lines that belong to a header record
  header_uu UUID NOT NULL REFERENCES private.stk_invoice(uu), -- YES - references stk_invoice
  ----Prompt: ask the user if they need to store json
  record_json JSONB NOT NULL DEFAULT '{}'::jsonb, -- YES - for line details
  ----Prompt: ask the user if they need to know when/if a record was processed
  --processed TIMESTAMPTZ, -- NO - header tracks this
  --is_processed BOOLEAN GENERATED ALWAYS AS (processed IS NOT NULL) STORED,
  -- Add direct foreign key to item (optional)
  stk_item_uu UUID REFERENCES private.stk_item(uu), -- Optional FK for item references
  search_key TEXT NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT ----partition: add_pk
); ----partition: add_partition_by
COMMENT ON TABLE private.stk_invoice_line IS 'Holds invoice_line records';
----partition: insert_default

CREATE VIEW api.stk_invoice_line AS SELECT * FROM private.stk_invoice_line;
COMMENT ON VIEW api.stk_invoice_line IS 'Holds invoice_line records';
----partition: insert_triggers
---- primary_section end ----

-- create triggers for newly created tables
SELECT private.stk_trigger_create();
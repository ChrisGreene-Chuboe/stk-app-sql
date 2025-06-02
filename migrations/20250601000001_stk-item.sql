-- set session to show stk_superuser as the actor performing all the tasks
SET stk.session = '{"psql_user": "stk_superuser"}';

---- type_section start ----
CREATE TYPE private.stk_item_type_enum AS ENUM (
    'PRODUCT-STOCKED',
    'PRODUCT-NONSTOCKED',
    'ACCOUNT',
    'SERVICE'
);
COMMENT ON TYPE private.stk_item_type_enum IS 'Enum used in code to automate and validate item types.';

INSERT INTO private.enum_comment (enum_type, enum_value, comment, is_default) VALUES
('stk_item_type_enum', 'PRODUCT-STOCKED', 'Physical product that is tracked in inventory', false),
('stk_item_type_enum', 'PRODUCT-NONSTOCKED', 'Physical product that is not tracked in inventory', false),
('stk_item_type_enum', 'ACCOUNT', 'Used by accounting to represent a type of charge or account', false),
('stk_item_type_enum', 'SERVICE', 'Service item for labor or consulting', true)
;

CREATE TABLE private.stk_item_type (
  uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT GENERATED ALWAYS AS ('stk_item_type') STORED,
  stk_entity_uu UUID NOT NULL REFERENCES private.stk_entity(uu),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL, -- no FK by convention
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL, -- no FK by convention
  revoked TIMESTAMPTZ,
  is_revoked BOOLEAN GENERATED ALWAYS AS (revoked IS NOT NULL) STORED,
  is_default BOOLEAN NOT NULL DEFAULT false,
  type_enum private.stk_item_type_enum NOT NULL,
  record_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  search_key TEXT NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT
);
COMMENT ON TABLE private.stk_item_type IS 'Holds the types of stk_item records. To see a list of all stk_item_type_enum enums and their comments, select from api.enum_value where enum_name is stk_item_type_enum.';

CREATE VIEW api.stk_item_type AS SELECT * FROM private.stk_item_type;
COMMENT ON VIEW api.stk_item_type IS 'Holds the types of stk_item records.';

-- create triggers and type records for newly created tables
SELECT private.stk_trigger_create();
SELECT private.stk_table_type_create('stk_item_type');
---- type_section end ----

---- primary_section start ----
CREATE TABLE private.stk_item (
  uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT generated always AS ('stk_item') stored,
  stk_entity_uu UUID NOT NULL REFERENCES private.stk_entity(uu),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL, -- no FK by convention
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL, -- no FK by convention
  revoked TIMESTAMPTZ,
  is_revoked BOOLEAN GENERATED ALWAYS AS (revoked IS NOT NULL) STORED,
  is_template BOOLEAN NOT NULL DEFAULT false,
  is_valid BOOLEAN NOT NULL DEFAULT true,
  type_uu UUID NOT NULL REFERENCES private.stk_item_type(uu),
  record_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  search_key TEXT NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT
);
COMMENT ON TABLE private.stk_item IS 'Holds item records similar to products or services in an ERP. Items can be products (stocked/non-stocked), charges, or services.';

CREATE VIEW api.stk_item AS SELECT * FROM private.stk_item;
COMMENT ON VIEW api.stk_item IS 'Holds item records similar to products or services in an ERP. Items can be products (stocked/non-stocked), charges, or services.';
---- primary_section end ----

-- create triggers for newly created tables
SELECT private.stk_trigger_create();

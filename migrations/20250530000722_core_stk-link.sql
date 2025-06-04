-- set session to show stk_superuser as the actor performing all the tasks
SET stk.session = '{"psql_user": "stk_superuser"}';

---- type_section start ----
CREATE TYPE private.stk_link_type_enum AS ENUM (
    'BIDIRECTIONAL',
    'UNIDIRECTIONAL'
);
COMMENT ON TYPE private.stk_link_type_enum IS 'Enum used in code to automate and validate link types.';

INSERT INTO private.enum_comment (enum_type, enum_value, comment, is_default) VALUES
('stk_link_type_enum', 'BIDIRECTIONAL', 'Link works in both directions between records', true),
('stk_link_type_enum', 'UNIDIRECTIONAL', 'Link works in one direction only from source to target', false)
;

CREATE TABLE private.stk_link_type (
  uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT GENERATED ALWAYS AS ('stk_link_type') STORED,
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL, -- no FK by convention
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL, -- no FK by convention
  revoked TIMESTAMPTZ,
  is_revoked BOOLEAN GENERATED ALWAYS AS (revoked IS NOT NULL) STORED,
  is_default BOOLEAN NOT NULL DEFAULT false,
  type_enum private.stk_link_type_enum NOT NULL,
  record_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  search_key TEXT NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT
);
COMMENT ON TABLE private.stk_link_type IS 'Holds the types of stk_link records. To see a list of all stk_link_type_enum enums and their comments, select from api.enum_value where enum_name is stk_link_type_enum.';

CREATE VIEW api.stk_link_type AS SELECT * FROM private.stk_link_type;
COMMENT ON VIEW api.stk_link_type IS 'Holds the types of stk_link records.';

-- create triggers and type records for newly created tables
SELECT private.stk_trigger_create();
SELECT private.stk_table_type_create('stk_link_type');
---- type_section end ----

---- primary_section start ----
CREATE TABLE private.stk_link (
  uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT generated always AS ('stk_link') stored,
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL, -- no FK by convention
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL, -- no FK by convention
  revoked TIMESTAMPTZ,
  is_revoked BOOLEAN GENERATED ALWAYS AS (revoked IS NOT NULL) STORED,
  source_table_name_uu_json JSONB NOT NULL DEFAULT '{"table_name": "","uu": ""}'::jsonb,
  target_table_name_uu_json JSONB NOT NULL DEFAULT '{"table_name": "","uu": ""}'::jsonb,
  type_uu UUID NOT NULL REFERENCES private.stk_link_type(uu),
  record_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  search_key TEXT NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  description TEXT
);
COMMENT ON TABLE private.stk_link IS 'Holds link records between different table records';

CREATE VIEW api.stk_link AS SELECT * FROM private.stk_link;
COMMENT ON VIEW api.stk_link IS 'Holds link records between different table records';
---- primary_section end ----

-- create triggers for newly created tables
SELECT private.stk_trigger_create();

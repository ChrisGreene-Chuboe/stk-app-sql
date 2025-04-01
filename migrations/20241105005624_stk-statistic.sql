

-- set session to show stk_superuser as the actor performing all the tasks
SET stk.session = '{\"psql_user\": \"stk_superuser\"}';

---- type_section start ----
CREATE TYPE private.stk_statistic_type_enum AS ENUM (
    'RECORD_SUMMARY',
    'GRAND_TOTAL',
    'TAX_TOTAL',
    'LIFETIME_REVENUE',
    'YTD_REVENUE'
);
COMMENT ON TYPE private.stk_statistic_type_enum IS 'Enum used in code to automate and validate statistic types.';

INSERT INTO private.enum_comment (enum_type, enum_value, comment) VALUES
  ('stk_statistic_type_enum', 'RECORD_SUMMARY', 'Provides a summary of the record for easy lookup')
;

CREATE TABLE private.stk_statistic_type (
  uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT GENERATED ALWAYS AS ('stk_statistic_type') STORED,
  stk_entity_uu UUID NOT NULL REFERENCES private.stk_entity(uu),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL, -- no FK by convention
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL, -- no FK by convention
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_default BOOLEAN NOT NULL DEFAULT false,
  type_enum private.stk_statistic_type_enum NOT NULL,
  record_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  search_key TEXT NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT
);
COMMENT ON TABLE private.stk_statistic_type IS 'Holds the types of stk_statistic records. To see a list of all stk_statistic_type_enum enums and their comments, select from api.enum_value where enum_name is stk_statistic_type_enum.';

CREATE VIEW api.stk_statistic_type AS SELECT * FROM private.stk_statistic_type;
COMMENT ON VIEW api.stk_statistic_type IS 'Holds the types of stk_statistic records.';

-- create triggers and type records for newly created tables
SELECT private.stk_trigger_create();
SELECT private.stk_table_type_create('stk_statistic_type');
---- type_section end ----

---- primary_section start ----
CREATE TABLE private.stk_statistic (
  uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT generated always AS ('stk_statistic') stored,
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL, -- no FK by convention
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL, -- no FK by convention
  is_active BOOLEAN NOT NULL DEFAULT true,
  type_uu UUID NOT NULL REFERENCES private.stk_statistic_type(uu),
  record_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  search_key TEXT NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT
);
COMMENT ON TABLE private.stk_statistic IS 'Holds the system statistic records that make retriving cached calculations easier and faster without changing the actual table. Statistic column holds the actual json values used to describe the statistic.';

CREATE VIEW api.stk_statistic AS SELECT * FROM private.stk_statistic;
COMMENT ON VIEW api.stk_statistic IS 'Holds the system statistic records that make retriving cached calculations easier and faster without changing the actual table. Statistic column holds the actual json values used to describe the statistic.';
---- primary_section end ----

-- create triggers for newly created tables
SELECT private.stk_trigger_create();


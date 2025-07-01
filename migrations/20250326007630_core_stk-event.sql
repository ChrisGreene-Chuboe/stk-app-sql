-- set session to show stk_superuser as the actor performing all the tasks
SET stk.session = '{\"psql_user\": \"stk_superuser\"}';

---- type_section start ----
CREATE TYPE private.stk_event_type_enum AS ENUM (
    'NONE',
    'ACTION',
    'TIMESHEET'
);
COMMENT ON TYPE private.stk_event_type_enum IS 'Enum used in code to automate and validate event types.';

INSERT INTO private.enum_comment (enum_type, enum_value, comment, is_default, record_json) VALUES
('stk_event_type_enum', 'NONE', 'General purpose with no automation or validation', true, NULL),
('stk_event_type_enum', 'ACTION', 'Action purpose with no automation or validation', false, NULL),
('stk_event_type_enum', 'TIMESHEET', 'Time entry record with minutes worked and optional description', false,
    '{
        "$schema": "http://json-schema.org/draft-07/schema#",
        "type": "object",
        "required": ["start_date", "minutes"],
        "properties": {
            "start_date": {
                "type": "string",
                "format": "date-time",
                "description": "The start date and time of the work period"
            },
            "minutes": {
                "type": "integer",
                "minimum": 0,
                "maximum": 1440,
                "description": "Duration of work in minutes (max 24 hours = 1440 minutes)"
            },
            "description": {
                "type": "string",
                "description": "Optional description of the work performed"
            }
        },
        "additionalProperties": false
    }'::jsonb)
;

CREATE TABLE private.stk_event_type (
  uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT GENERATED ALWAYS AS ('stk_event_type') STORED,
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL, -- no FK by convention
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL, -- no FK by convention
  revoked TIMESTAMPTZ,
  is_revoked BOOLEAN GENERATED ALWAYS AS (revoked IS NOT NULL) STORED,
  is_default BOOLEAN NOT NULL DEFAULT false,
  type_enum private.stk_event_type_enum NOT NULL,
  record_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  search_key TEXT NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT
);
COMMENT ON TABLE private.stk_event_type IS 'Holds the types of stk_event records. To see a list of all stk_event_type_enum enums and their comments, select from api.enum_value where enum_name is stk_event_type_enum.';

CREATE VIEW api.stk_event_type AS SELECT * FROM private.stk_event_type;
COMMENT ON VIEW api.stk_event_type IS 'Holds the types of stk_event records.';

-- create triggers and type records for newly created tables
SELECT private.stk_trigger_create();
SELECT private.stk_table_type_create('stk_event_type');
---- type_section end ----

---- primary_section start ----
CREATE TABLE private.stk_event (
  uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT generated always AS ('stk_event') stored,
  stk_entity_uu UUID NOT NULL REFERENCES private.stk_entity(uu),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL, -- no FK by convention
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL, -- no FK by convention
  revoked TIMESTAMPTZ,
  is_revoked BOOLEAN GENERATED ALWAYS AS (revoked IS NOT NULL) STORED,
  table_name_uu_json JSONB NOT NULL DEFAULT '{"table_name": "","uu": ""}'::jsonb,
  is_valid BOOLEAN NOT NULL DEFAULT true,
  type_uu UUID NOT NULL REFERENCES private.stk_event_type(uu),
  record_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  processed TIMESTAMPTZ,
  is_processed BOOLEAN GENERATED ALWAYS AS (processed IS NOT NULL) STORED,
  search_key TEXT NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT
);
COMMENT ON TABLE private.stk_event IS 'Holds event records';

CREATE VIEW api.stk_event AS SELECT * FROM private.stk_event;
COMMENT ON VIEW api.stk_event IS 'Holds event records';
---- primary_section end ----

-- create triggers for newly created tables
SELECT private.stk_trigger_create();

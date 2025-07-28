-- set session to show stk_superuser as the actor performing all the tasks
SET stk.session = '{"psql_user": "stk_superuser"}';

---- type_section start ----
CREATE TYPE private.stk_project_line_type_enum AS ENUM (
    'TASK',
    'MILESTONE',
    'DELIVERABLE',
    'RESOURCE'
);
COMMENT ON TYPE private.stk_project_line_type_enum IS 'Enum used in code to automate and validate project line types.';

INSERT INTO private.enum_comment (enum_type, enum_value, comment, is_default) VALUES
('stk_project_line_type_enum', 'TASK', 'Project task or work item', true),
('stk_project_line_type_enum', 'MILESTONE', 'Project milestone or checkpoint', false),
('stk_project_line_type_enum', 'DELIVERABLE', 'Project deliverable or output', false),
('stk_project_line_type_enum', 'RESOURCE', 'Project resource allocation', false)
;

CREATE TABLE private.stk_project_line_type (
  uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT GENERATED ALWAYS AS ('stk_project_line_type') STORED,
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL, -- no FK by convention
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL, -- no FK by convention
  revoked TIMESTAMPTZ,
  is_revoked BOOLEAN GENERATED ALWAYS AS (revoked IS NOT NULL) STORED,
  is_default BOOLEAN NOT NULL DEFAULT false,
  type_enum private.stk_project_line_type_enum NOT NULL,
  record_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  search_key TEXT NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT
);
COMMENT ON TABLE private.stk_project_line_type IS 'Holds the types of stk_project_line records. To see a list of all stk_project_line_type_enum enums and their comments, select from api.enum_value where enum_name is stk_project_line_type_enum.';

CREATE VIEW api.stk_project_line_type AS SELECT * FROM private.stk_project_line_type;
COMMENT ON VIEW api.stk_project_line_type IS 'Holds the types of stk_project_line records.';

-- create triggers and type records for newly created tables
SELECT private.stk_trigger_create();
SELECT private.stk_table_type_create('stk_project_line_type');
---- type_section end ----

---- primary_section start ----
CREATE TABLE private.stk_project_line (
  uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT generated always AS ('stk_project_line') stored,
  stk_entity_uu UUID NOT NULL REFERENCES private.stk_entity(uu),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL, -- no FK by convention
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL, -- no FK by convention
  revoked TIMESTAMPTZ,
  is_revoked BOOLEAN GENERATED ALWAYS AS (revoked IS NOT NULL) STORED,
  is_template BOOLEAN NOT NULL DEFAULT false,
  is_valid BOOLEAN NOT NULL DEFAULT true,
  type_uu UUID NOT NULL REFERENCES private.stk_project_line_type(uu),
  header_uu UUID NOT NULL REFERENCES private.stk_project(uu),
  record_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  search_key TEXT NOT NULL DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  UNIQUE(header_uu, search_key)
);
COMMENT ON TABLE private.stk_project_line IS 'Holds project line items for tasks, milestones, deliverables, and resources. Lines can be tagged with stk_item for billing purposes.';

CREATE VIEW api.stk_project_line AS SELECT * FROM private.stk_project_line;
COMMENT ON VIEW api.stk_project_line IS 'Holds project line items for tasks, milestones, deliverables, and resources. Lines can be tagged with stk_item for billing purposes.';
---- primary_section end ----

-- create triggers for newly created tables
SELECT private.stk_trigger_create();

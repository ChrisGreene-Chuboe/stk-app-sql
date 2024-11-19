

-- set session to show stk_superuser as the actor performing all the tasks
SET stk.session = '{\"psql_user\": \"stk_superuser\"}';

CREATE TYPE private.wf_request_type AS ENUM (
    'NOTE',
    'DISCUSS',
    'NOTICE',
    'ACTION',
    'TODO',
    'CHECKLIST'
);
COMMENT ON TYPE private.wf_request_type IS 'Enum used in code to automate and validate wf_request types.';

INSERT INTO private.enum_comment (enum_type, enum_value, comment) VALUES 
('wf_request_type', 'NOTE', 'Action purpose with no automation or validation'),
('wf_request_type', 'CHECKLIST', 'Action purpose with no automation or validation')
;

CREATE TABLE private.stk_wf_request_type (
  stk_wf_request_type_uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu uuid NOT NULL,
  CONSTRAINT fk_some_table_createdby FOREIGN KEY (created_by_uu) REFERENCES private.stk_actor(stk_actor_uu),
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu uuid NOT NULL,
  CONSTRAINT fk_some_table_updatedby FOREIGN KEY (updated_by_uu) REFERENCES private.stk_actor(stk_actor_uu),
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_default BOOLEAN NOT NULL DEFAULT false,
  wf_request_type private.wf_request_type NOT NULL,
  search_key TEXT NOT NULL DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT
);
COMMENT ON TABLE private.stk_wf_request_type IS 'Holds the types of stk_wf_request records. To see a list of all wf_request_type enums and their comments, select from api.enum_value where enum_name is wf_request_type.';

CREATE VIEW api.stk_wf_request_type AS SELECT * FROM private.stk_wf_request_type;
COMMENT ON VIEW api.stk_wf_request_type IS 'Holds the types of stk_wf_request records.';

CREATE TABLE private.stk_wf_request (
  stk_wf_request_uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu uuid NOT NULL,
  CONSTRAINT fk_some_table_createdby FOREIGN KEY (created_by_uu) REFERENCES private.stk_actor(stk_actor_uu),
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu uuid NOT NULL,
  CONSTRAINT fk_some_table_updatedby FOREIGN KEY (updated_by_uu) REFERENCES private.stk_actor(stk_actor_uu),
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_template BOOLEAN NOT NULL DEFAULT false,
  is_valid BOOLEAN NOT NULL DEFAULT true,
  stk_wf_request_type_uu UUID NOT NULL,
  CONSTRAINT fk_stk_wf_request_type FOREIGN KEY (stk_wf_request_type_uu) REFERENCES private.stk_wf_request_type(stk_wf_request_type_uu),
  stk_wf_request_parent_uu UUID,
  CONSTRAINT fk_stk_wf_request_parent FOREIGN KEY (stk_wf_request_parent_uu) REFERENCES private.stk_wf_request(stk_wf_request_uu),
  name TEXT NOT NULL,
  description TEXT
);
COMMENT ON TABLE private.stk_wf_request IS 'Holds wf_request records';

CREATE VIEW api.stk_wf_request AS SELECT * FROM private.stk_wf_request;
COMMENT ON VIEW api.stk_wf_request IS 'Holds wf_request records';

--select private.stk_table_trigger_create();
select private.stk_trigger_create();

--INSERT INTO api.stk_wf_request_type (wf_request_type, name, description)
--VALUES 
--('NOTE', 'Note', 'General purpose with no automation or validation'),
--('DISCUSS', 'Discuss', 'Action is to support multi-part, multi-actor discussion'),
--('NOTICE', 'Notice', 'Action is to notify')
--;

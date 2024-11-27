

-- set session to show stk_superuser as the actor performing all the tasks
SET stk.session = '{\"psql_user\": \"stk_superuser\"}';

CREATE TYPE private.stk_async_type_enum AS ENUM (
    'NONE',
    'NOTIFY'
);
COMMENT ON TYPE private.stk_async_type_enum IS 'Enum used in code to automate and validate async types.';

INSERT INTO private.enum_comment (enum_type, enum_value, comment) VALUES
('stk_async_type_enum', 'NONE', 'General purpose with no automation or validation'),
('stk_async_type_enum', 'NOTIFY', 'Notify actors or services outside of the database')
;

CREATE TABLE private.stk_async_type (
  stk_async_type_uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT GENERATED ALWAYS AS ('stk_async_type') STORED,
  record_uu UUID GENERATED ALWAYS AS (stk_async_type_uu) STORED,
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL,
  CONSTRAINT fk_stk_async_type_createdby FOREIGN KEY (created_by_uu) REFERENCES private.stk_actor(stk_actor_uu),
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL,
  CONSTRAINT fk_stk_async_type_updatedby FOREIGN KEY (updated_by_uu) REFERENCES private.stk_actor(stk_actor_uu),
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_default BOOLEAN NOT NULL DEFAULT false,
  stk_async_type_enum private.stk_async_type_enum NOT NULL,
  ----Prompt: ask the user if they need to store json
  --stk_async_type_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  search_key TEXT NOT NULL DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT
);
COMMENT ON TABLE private.stk_async_type IS 'Holds the types of stk_async records. To see a list of all stk_async_type_enum enums and their comments, select from api.enum_value where enum_name is stk_async_type_enum.';

CREATE VIEW api.stk_async_type AS SELECT * FROM private.stk_async_type;
COMMENT ON VIEW api.stk_async_type IS 'Holds the types of stk_async records.';

CREATE TABLE private.stk_async (
  stk_async_uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT generated always AS ('stk_async') stored,
  record_uu UUID GENERATED ALWAYS AS (stk_async_uu) stored,
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL,
  CONSTRAINT fk_stk_async_createdby FOREIGN KEY (created_by_uu) REFERENCES private.stk_actor(stk_actor_uu),
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL,
  CONSTRAINT fk_stk_async_updatedby FOREIGN KEY (updated_by_uu) REFERENCES private.stk_actor(stk_actor_uu),
  is_active BOOLEAN NOT NULL DEFAULT true,
  ----Prompt: ask the user if they need to create templates
  --is_template BOOLEAN NOT NULL DEFAULT false,
  ----Prompt: ask the user if they need validation
  --is_valid BOOLEAN NOT NULL DEFAULT true,
  stk_async_type_uu UUID NOT NULL,
  CONSTRAINT fk_stk_async_type FOREIGN KEY (stk_async_type_uu) REFERENCES private.stk_async_type(stk_async_type_uu),
  ----Prompt: ask the user if they need to create parent child relationships inside the table
  --stk_async_parent_uu UUID,
  --CONSTRAINT fk_stk_async_parent FOREIGN KEY (stk_async_parent_uu) REFERENCES private.stk_async(stk_async_uu),
  ----Prompt: ask the user if they need to store json
  --stk_async_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  search_key TEXT NOT NULL DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT
);
COMMENT ON TABLE private.stk_async IS 'Holds async records';

CREATE VIEW api.stk_async AS SELECT * FROM private.stk_async;
COMMENT ON VIEW api.stk_async IS 'Holds async records';

-- create triggers for newly created tables
SELECT private.stk_trigger_create();
SELECT private.stk_table_type_create('stk_async_type');


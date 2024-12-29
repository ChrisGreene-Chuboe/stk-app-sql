

-- set session to show stk_superuser as the actor performing all the tasks
SET stk.session = '{\"psql_user\": \"stk_superuser\"}';

---- type_section start ----
CREATE TYPE private.stk_system_config_type_enum AS ENUM (
    'SYSTEM',
    'ENTITY',
    'ROLE',
    'USER'
);
COMMENT ON TYPE private.stk_system_config_type_enum IS 'used in code to drive system configuration visibility and functionality';

INSERT INTO private.enum_comment (enum_type, enum_value, comment, is_default) VALUES
('stk_system_config_type_enum', 'SYSTEM', 'System-wide configuration across all Tenants',true),
('stk_system_config_type_enum', 'ENTITY', 'Entity-wide configuration across all Roles',false),
('stk_system_config_type_enum', 'ROLE', 'Role-wide configuration across all Users',false),
('stk_system_config_type_enum', 'USER', 'User-specific configuration',false)
;

CREATE TABLE private.stk_system_config_type (
  uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT GENERATED ALWAYS AS ('stk_system_config_type') STORED,
  --stk_entity_uu UUID NOT NULL REFERENCES private.stk_entity(uu),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL, -- no FK by convention
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL, -- no FK by convention
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_default BOOLEAN NOT NULL DEFAULT false,
  type_enum private.stk_system_config_type_enum NOT NULL,
  record_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  search_key TEXT NOT NULL DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  UNIQUE (search_key)
);
COMMENT ON TABLE private.stk_system_config_type IS 'Holds the types of stk_system_config records. Configuration column holds a json template to be used when creating a new stk_system_config record.';

CREATE VIEW api.stk_system_config_type AS SELECT * FROM private.stk_system_config_type;
COMMENT ON VIEW api.stk_system_config_type IS 'Holds the types of stk_system_config records. Configuration column holds a json template to be used when creating a new stk_system_config record.';

-- create triggers and type records for newly created tables
SELECT private.stk_trigger_create();
SELECT private.stk_table_type_create('stk_system_config_type');

-- Trigger for stk_system_config_type table
CREATE TRIGGER t10130_stk_search_key_uppercase
BEFORE INSERT OR UPDATE ON private.stk_system_config_type
FOR EACH ROW
EXECUTE FUNCTION private.t10130_stk_search_key_uppercase();
---- type_section end ----

---- primary_section start ----
CREATE TABLE private.stk_system_config (
  uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT generated always AS ('stk_system_config') stored,
  --stk_entity_uu UUID NOT NULL REFERENCES private.stk_entity(uu),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL, -- no FK by convention
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL, -- no FK by convention
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_valid BOOLEAN NOT NULL DEFAULT true,
  type_uu UUID NOT NULL REFERENCES private.stk_system_config_type(uu),
  record_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  search_key TEXT NOT NULL DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  UNIQUE (search_key)
);
COMMENT ON TABLE private.stk_system_config IS 'Holds the system configuration records that dictates how the system behaves. Configuration column holds the actual json configuration values used to describe the system configuration.';

CREATE VIEW api.stk_system_config AS SELECT * FROM private.stk_system_config;
COMMENT ON VIEW api.stk_system_config IS 'Holds the system configuration records that dictates how the system behaves. Configuration column holds the actual json configuration values used to describe the system configuration.';
---- primary_section end ----

-- create triggers for newly created tables
SELECT private.stk_trigger_create();


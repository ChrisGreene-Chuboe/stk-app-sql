

-- set session to show stk_superuser as the actor performing all the tasks
SET stk.session = '{\"psql_user\": \"stk_superuser\"}';

CREATE TYPE private.system_config_level_type AS ENUM (
    'SYSTEM',
    'TENANT',
    'ENTITY',
    'ROLE',
    'USER'
);
COMMENT ON TYPE private.system_config_level_type IS 'used in code to drive system configuration visibility and functionality';

CREATE TABLE private.stk_system_config_type (
  stk_system_config_type_uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu uuid NOT NULL,
  CONSTRAINT fk_stk_system_config_type_createdby FOREIGN KEY (created_by_uu) REFERENCES private.stk_actor(stk_actor_uu),
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu uuid NOT NULL,
  CONSTRAINT fk_stk_system_config_type_updatedby FOREIGN KEY (updated_by_uu) REFERENCES private.stk_actor(stk_actor_uu),
  is_active BOOLEAN NOT NULL DEFAULT true,
  system_config_level_type private.system_config_level_type NOT NULL,
  search_key TEXT NOT NULL DEFAULT gen_random_uuid(),
  description TEXT,
  configuration JSONB NOT NULL, -- used to hold a template json object. Used as the source when creating a new stk_system_config record.
  CONSTRAINT stk_system_config_type_search_key_uidx UNIQUE (search_key)
);
COMMENT ON TABLE private.stk_system_config_type IS 'Holds the types of stk_system_config records. Configuration column holds a json template to be used when creating a new stk_system_config record.';

CREATE VIEW api.stk_system_config_type AS SELECT * FROM private.stk_system_config_type;
COMMENT ON VIEW api.stk_system_config_type IS 'Holds the types of stk_system_config records. Configuration column holds a json template to be used when creating a new stk_system_config record.';

-- Trigger for stk_system_config_type table
CREATE TRIGGER stk_system_config_type_search_key_uppercase
BEFORE INSERT OR UPDATE ON private.stk_system_config_type
FOR EACH ROW
EXECUTE FUNCTION private.text_search_key_uppercase();

CREATE TABLE private.stk_system_config (
  stk_system_config_uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu uuid NOT NULL,
  CONSTRAINT fk_stk_system_config_createdby FOREIGN KEY (created_by_uu) REFERENCES private.stk_actor(stk_actor_uu),
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu uuid NOT NULL,
  CONSTRAINT fk_stk_system_config_updatedby FOREIGN KEY (updated_by_uu) REFERENCES private.stk_actor(stk_actor_uu),
  is_active BOOLEAN NOT NULL DEFAULT true,
  stk_system_config_type_uu UUID DEFAULT gen_random_uuid(),
  CONSTRAINT fk_stk_system_config_sysconfigtype FOREIGN KEY (stk_system_config_type_uu) REFERENCES private.stk_system_config_type(stk_system_config_type_uu),
  search_key TEXT NOT NULL DEFAULT gen_random_uuid(),
  description TEXT,
  configuration JSONB NOT NULL, -- settings and configuration
  CONSTRAINT stk_system_config_search_key_uidx UNIQUE (search_key)
);
COMMENT ON TABLE private.stk_system_config IS 'Holds the system configuration records that dictates how the system behaves. Configuration column holds the actual json configuration values used to describe the system configuration.';

CREATE VIEW api.stk_system_config AS SELECT * FROM private.stk_system_config;
COMMENT ON VIEW api.stk_system_config IS 'Holds the system configuration records that dictates how the system behaves. Configuration column holds the actual json configuration values used to describe the system configuration.';

--select private.stk_table_trigger_create();
select private.stk_trigger_create();

----sample data for stk_system_config_type
--INSERT INTO private.stk_system_config_type (system_config_level_type, search_key, description, configuration) VALUES
--('SYSTEM', 'system_config', 'System-wide configuration', '{"theme": "default", "language": "en", "timezone": "UTC"}'), --test uppercase search_key
--('TENANT', 'TENANT_CONFIG', 'Tenant-specific configuration', '{"name": "", "domain": "", "max_users": 100}'),
--('ENTITY', 'ENTITY_CONFIG', 'Entity-level configuration', '{"entity_type": "", "custom_fields": {}}'),
--('ROLE', 'ROLE_CONFIG', 'Role-based configuration', '{"permissions": [], "access_level": "standard"}'),
--('USER', 'USER_CONFIG', 'User-specific configuration', '{"theme_preference": "default", "notification_settings": {}}');
--
----sample data for stk_system_config
---- System configuration
--INSERT INTO private.stk_system_config (
--    stk_system_config_type_uu,
--    search_key,
--    description,
--    configuration
--) VALUES (
--    (SELECT stk_system_config_type_uu FROM private.stk_system_config_type WHERE system_config_level_type = 'SYSTEM'),
--    'GLOBAL_SYSTEM_CONFIG',
--    'Global system-wide configuration',
--    '{
--        "theme": "dark",
--        "language": "en",
--        "timezone": "UTC",
--        "max_file_upload_size": 10,
--        "session_timeout": 30
--    }'
--);
--
---- Tenant configuration 1
--INSERT INTO private.stk_system_config (
--    stk_system_config_type_uu,
--    search_key,
--    description,
--    configuration
--) VALUES (
--    (SELECT stk_system_config_type_uu FROM private.stk_system_config_type WHERE system_config_level_type = 'TENANT'),
--    'TENANT_CONFIG_ACME',
--    'Configuration for Acme Corporation',
--    '{
--        "name": "Acme Corporation",
--        "domain": "acme.com",
--        "max_users": 500,
--        "storage_limit": 1000,
--        "features_enabled": ["analytics", "integrations"]
--    }'
--);
--
---- Tenant configuration 2
--INSERT INTO private.stk_system_config (
--    stk_system_config_type_uu,
--    search_key,
--    description,
--    configuration
--) VALUES (
--    (SELECT stk_system_config_type_uu FROM private.stk_system_config_type WHERE system_config_level_type = 'TENANT'),
--    'TENANT_CONFIG_GLOBEX',
--    'Configuration for Globex Corporation',
--    '{
--        "name": "Globex Corporation",
--        "domain": "globex.com",
--        "max_users": 250,
--        "storage_limit": 500,
--        "features_enabled": ["reporting", "custom_branding"]
--    }'
--);

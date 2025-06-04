

CREATE TYPE private.stk_actor_type_enum AS ENUM (
    'NONE'
);
COMMENT ON TYPE private.stk_actor_type_enum IS 'Enum used in code to automate and validate actor types.';

INSERT INTO private.enum_comment (enum_type, enum_value, comment, is_default) VALUES
('stk_actor_type_enum', 'NONE', 'General purpose with no automation or validation', true)
;

CREATE TABLE private.stk_actor_type (
  uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT GENERATED ALWAYS AS ('stk_actor_type') STORED,
  --stk_entity_uu UUID NOT NULL REFERENCES private.stk_entity(uu), -- does not exist yet
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID, -- no FK by convention
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID, -- no FK by convention
  revoked TIMESTAMPTZ,
  is_revoked BOOLEAN GENERATED ALWAYS AS (revoked IS NOT NULL) STORED,
  is_default BOOLEAN NOT NULL DEFAULT false,
  type_enum private.stk_actor_type_enum NOT NULL,
  ----Prompt: ask the user if they need to store json
  --record_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  search_key TEXT NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT
);
COMMENT ON TABLE private.stk_actor_type IS 'Holds the types of stk_actor records. To see a list of all actor_type enums and their comments, select from api.enum_value where enum_name is actor_type.';

CREATE VIEW api.stk_actor_type AS SELECT * FROM private.stk_actor_type;
COMMENT ON VIEW api.stk_actor_type IS 'Holds the types of stk_actor records.';

CREATE TABLE private.stk_actor (
  uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT generated always AS ('stk_actor') stored,
  --stk_entity_uu UUID NOT NULL REFERENCES private.stk_entity(uu), -- does not exist yet
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID, -- no FK by convention
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID, -- no FK by convention
  revoked TIMESTAMPTZ,
  is_revoked BOOLEAN GENERATED ALWAYS AS (revoked IS NOT NULL) STORED,
  is_template BOOLEAN NOT NULL DEFAULT false,
  is_valid BOOLEAN NOT NULL DEFAULT true,
  type_uu UUID NOT NULL REFERENCES private.stk_actor_type(uu),
  parent_uu UUID REFERENCES private.stk_actor(uu),
  search_key TEXT NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  name TEXT,
  name_first TEXT,
  name_middle TEXT,
  name_last TEXT,
  description TEXT,
  psql_user TEXT
);
COMMENT ON TABLE private.stk_actor IS 'Holds actor records';

-- do not allow multiple users to share the same psql user reference
CREATE UNIQUE INDEX stk_actor_psql_user_uidx ON private.stk_actor (lower(psql_user)) WHERE psql_user IS NOT NULL;

CREATE VIEW api.stk_actor AS SELECT * FROM private.stk_actor;
COMMENT ON VIEW api.stk_actor IS 'Holds actor records';

INSERT INTO private.stk_actor_type (type_enum, name, is_default) VALUES 
( 'NONE', 'NONE', true);

INSERT INTO private.stk_actor ( type_uu, name, psql_user) VALUES 
( (SELECT uu FROM private.stk_actor_type LIMIT 1), 'stk_login', 'stk_login'),
( (SELECT uu FROM private.stk_actor_type LIMIT 1), 'stk_superuser', 'stk_superuser'),
( (SELECT uu FROM private.stk_actor_type LIMIT 1), 'unknown', 'unknown')
;

UPDATE private.stk_actor
SET created_by_uu = (SELECT uu FROM private.stk_actor WHERE name = 'stk_superuser'),
updated_by_uu = (SELECT uu FROM private.stk_actor WHERE name = 'stk_superuser')
;

ALTER TABLE private.stk_actor
ALTER COLUMN created_by_uu SET NOT NULL,
ALTER COLUMN updated_by_uu SET NOT NULL
;

-- do the same for _type
UPDATE private.stk_actor_type
SET created_by_uu = (SELECT uu FROM private.stk_actor WHERE name = 'stk_superuser'),
updated_by_uu = (SELECT uu FROM private.stk_actor WHERE name = 'stk_superuser')
;

ALTER TABLE private.stk_actor_type
ALTER COLUMN created_by_uu SET NOT NULL,
ALTER COLUMN updated_by_uu SET NOT NULL
;

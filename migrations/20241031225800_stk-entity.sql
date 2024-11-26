

-- set session to show stk_superuser as the actor performing all the tasks
SET stk.session = '{\"psql_user\": \"stk_superuser\"}';

CREATE TYPE private.stk_entity_type_enum AS ENUM (
    '*',
    'TRX'
);
COMMENT ON TYPE private.stk_entity_type_enum IS 'Enum used in code to automate and validate entity types.';

INSERT INTO private.enum_comment (enum_type, enum_value, comment) VALUES
('stk_entity_type_enum', '*', 'General purpose non-transactional entity'),
('stk_entity_type_enum', 'TRX', 'Transactional entity that supports financial entries')
;

CREATE TABLE private.stk_entity_type (
  stk_entity_type_uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT GENERATED ALWAYS AS ('stk_entity_type') STORED,
  record_uu UUID GENERATED ALWAYS AS (stk_entity_type_uu) STORED,
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu uuid NOT NULL,
  CONSTRAINT fk_stk_entity_type_createdby FOREIGN KEY (created_by_uu) REFERENCES private.stk_actor(stk_actor_uu),
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu uuid NOT NULL,
  CONSTRAINT fk_stk_entity_type_updatedby FOREIGN KEY (updated_by_uu) REFERENCES private.stk_actor(stk_actor_uu),
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_default BOOLEAN NOT NULL DEFAULT false,
  stk_entity_type_enum private.stk_entity_type_enum NOT NULL,
  search_key TEXT NOT NULL DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT
);
COMMENT ON TABLE private.stk_entity_type IS 'Holds the types of stk_entity records. To see a list of all stk_entity_type_enum enums and their comments, select from api.enum_value where enum_name is stk_entity_type_enum.';

CREATE VIEW api.stk_entity_type AS SELECT * FROM private.stk_entity_type;
COMMENT ON VIEW api.stk_entity_type IS 'Holds the types of stk_entity records.';

CREATE TABLE private.stk_entity (
  stk_entity_uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT GENERATED ALWAYS AS ('stk_entity') STORED,
  record_uu UUID GENERATED ALWAYS AS (stk_entity_uu) STORED,
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu uuid NOT NULL,
  CONSTRAINT fk_stk_entity_createdby FOREIGN KEY (created_by_uu) REFERENCES private.stk_actor(stk_actor_uu),
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu uuid NOT NULL,
  CONSTRAINT fk_stk_entity_updatedby FOREIGN KEY (updated_by_uu) REFERENCES private.stk_actor(stk_actor_uu),
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_template BOOLEAN NOT NULL DEFAULT false,
  is_valid BOOLEAN NOT NULL DEFAULT true,
  stk_entity_type_uu UUID NOT NULL,
  CONSTRAINT fk_stk_entity_type FOREIGN KEY (stk_entity_type_uu) REFERENCES private.stk_entity_type(stk_entity_type_uu),
  stk_entity_parent_uu UUID,
  CONSTRAINT fk_stk_entity_parent FOREIGN KEY (stk_entity_parent_uu) REFERENCES private.stk_entity(stk_entity_uu),
  search_key TEXT NOT NULL DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT
);
COMMENT ON TABLE private.stk_entity IS 'Holds entity records';

CREATE VIEW api.stk_entity AS SELECT * FROM private.stk_entity;
COMMENT ON VIEW api.stk_entity IS 'Holds entity records';

-- create triggers for newly created tables
SELECT private.stk_trigger_create();
SELECT private.stk_table_type_create('stk_entity_type');

-- create first stk_entity
INSERT INTO private.stk_entity (stk_entity_type_uu, name, description)
SELECT stk_entity_type_uu, name, description
FROM private.stk_entity_type
WHERE stk_entity_type_enum = '*'
;

-- alter stk_actor_type table to reflect the newly created entities
ALTER TABLE private.stk_actor_type
ADD COLUMN stk_entity_uu UUID,
ADD CONSTRAINT fk_stk_actor_type_entity FOREIGN KEY (stk_entity_uu) REFERENCES private.stk_entity(stk_entity_uu)
;
-- set values
UPDATE private.stk_actor_type SET stk_entity_uu = (
    SELECT stk_entity_uu 
    FROM private.stk_entity e
    JOIN private.stk_entity_type et ON e.stk_entity_type_uu = et.stk_entity_type_uu
    WHERE et.stk_entity_type_enum = '*'
    LIMIT 1
);
-- set stk_actor_type.entity_uu to not null
ALTER TABLE private.stk_actor_type
ALTER COLUMN stk_entity_uu SET NOT NULL
;
-- drop and recreate api view
DROP VIEW api.stk_actor_type;
CREATE VIEW api.stk_actor_type AS SELECT * FROM private.stk_actor_type;

-- alter stk_actor table to reflect the newly created entities
ALTER TABLE private.stk_actor
ADD COLUMN stk_entity_uu UUID,
ADD CONSTRAINT fk_stk_actor_entity FOREIGN KEY (stk_entity_uu) REFERENCES private.stk_entity(stk_entity_uu)
;
-- set values
UPDATE private.stk_actor SET stk_entity_uu = (
    SELECT stk_entity_uu 
    FROM private.stk_entity e
    JOIN private.stk_entity_type et ON e.stk_entity_type_uu = et.stk_entity_type_uu
    WHERE et.stk_entity_type_enum = '*'
    LIMIT 1
);
-- set stk_actor.entity_uu to not null
ALTER TABLE private.stk_actor
ALTER COLUMN stk_entity_uu SET NOT NULL
;
-- drop and recreate api view
DROP VIEW api.stk_actor;
CREATE VIEW api.stk_actor AS SELECT * FROM private.stk_actor;

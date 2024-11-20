

-- set session to show stk_superuser as the actor performing all the tasks
SET stk.session = '{\"psql_user\": \"stk_superuser\"}';

CREATE TYPE private.stk_statistic_type_enum AS ENUM (
    'RECORD_SUMMARY',
    'GRAND_TOTAL',
    'TAX_TOTAL',
    'LIFETIME_REVENUE',
    'YTD_REVENUE'
);
COMMENT ON TYPE private.stk_statistic_type_enum IS 'used in code to drive statistic visibility and functionality';

INSERT INTO private.enum_comment (enum_type, enum_value, comment) VALUES
('stk_statistic_type_enum', 'RECORD_SUMMARY', 'Provides a summary of the record for easy lookup')
;

CREATE TABLE private.stk_statistic_type (
  stk_statistic_type_uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu uuid NOT NULL,
  CONSTRAINT fk_stk_statistic_type_createdby FOREIGN KEY (created_by_uu) REFERENCES private.stk_actor(stk_actor_uu),
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu uuid NOT NULL,
  CONSTRAINT fk_stk_statistic_type_updatedby FOREIGN KEY (updated_by_uu) REFERENCES private.stk_actor(stk_actor_uu),
  is_active BOOLEAN NOT NULL DEFAULT true,
  stk_statistic_type_enum private.stk_statistic_type_enum NOT NULL,
  search_key TEXT NOT NULL DEFAULT gen_random_uuid(),
  description TEXT,
  statistic_json JSONB NOT NULL -- used to hold a template json object. Used as the source when creating a new stk_statistic record.
);
COMMENT ON TABLE private.stk_statistic_type IS 'Holds the types of stk_statistic records. Statistic column holds a json template to be used when creating a new stk_statistic record.';

CREATE VIEW api.stk_statistic_type AS SELECT * FROM private.stk_statistic_type;
COMMENT ON VIEW api.stk_statistic_type IS 'Holds the types of stk_statistic records.';

-- note: unlogged because this is de-normalized data - it can be re-calculated if lost during database crash
CREATE UNLOGGED TABLE private.stk_statistic (
  stk_statistic_uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu uuid NOT NULL,
  CONSTRAINT fk_stk_statistic_createdby FOREIGN KEY (created_by_uu) REFERENCES private.stk_actor(stk_actor_uu),
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu uuid NOT NULL,
  CONSTRAINT fk_stk_statistic_updatedby FOREIGN KEY (updated_by_uu) REFERENCES private.stk_actor(stk_actor_uu),
  is_active BOOLEAN NOT NULL DEFAULT true,
  table_name TEXT,
  record_uu UUID,
  stk_statistic_type_uu UUID DEFAULT gen_random_uuid(),
  CONSTRAINT fk_stk_statistic_stattype FOREIGN KEY (stk_statistic_type_uu) REFERENCES private.stk_statistic_type(stk_statistic_type_uu),
  search_key TEXT NOT NULL DEFAULT gen_random_uuid(),
  description TEXT,
  statistic_json JSONB NOT NULL
);
COMMENT ON TABLE private.stk_statistic IS 'Holds the system statistic records that make retriving cached calculations easier and faster without changing the actual table. Statistic column holds the actual json values used to describe the statistic.';

CREATE VIEW api.stk_statistic AS SELECT * FROM private.stk_statistic;
COMMENT ON VIEW api.stk_statistic IS 'Holds statistic records';

insert into private.stk_change_log_exclude (table_name) values ('stk_statistic');

select private.stk_trigger_create();

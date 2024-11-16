

-- set session to show stk_superuser as the actor performing all the tasks
SET stk.session = '{\"psql_user\": \"stk_superuser\"}';

CREATE TYPE private.statistic_type AS ENUM (
    'RECORD_SUMMARY',
    'GRAND_TOTAL',
    'TAX_TOTAL',
    'LIFETIME_REVENUE',
    'YTD_REVENUE'
);
COMMENT ON TYPE private.statistic_type IS 'used in code to drive statistic visibility and functionality';

INSERT INTO private.enum_comment (enum_type, enum_value, comment) VALUES
('statistic_type', 'RECORD_SUMMARY', 'Provides a summary of the record for easy lookup')
;

CREATE TABLE private.stk_statistic_type (
  stk_statistic_type_uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu uuid NOT NULL,
  CONSTRAINT fk_some_table_createdby FOREIGN KEY (created_by_uu) REFERENCES private.stk_actor(stk_actor_uu),
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu uuid NOT NULL,
  CONSTRAINT fk_some_table_updatedby FOREIGN KEY (updated_by_uu) REFERENCES private.stk_actor(stk_actor_uu),
  is_active BOOLEAN NOT NULL DEFAULT true,
  statistic_type private.statistic_type NOT NULL,
  search_key TEXT NOT NULL DEFAULT gen_random_uuid(),
  description TEXT,
  statistic JSONB NOT NULL -- used to hold a template json object. Used as the source when creating a new stk_statistic record.
);
COMMENT ON TABLE private.stk_statistic_type IS 'Holds the types of stk_statistic records. Statistic column holds a json template to be used when creating a new stk_statistic record.';

CREATE VIEW api.stk_statistic_type AS SELECT * FROM private.stk_statistic_type;
COMMENT ON VIEW api.stk_statistic_type IS 'Holds the types of stk_statistic records.';

-- note: unlogged because this is de-normalized data - it can be re-calculated if lost during database crash
CREATE UNLOGGED TABLE private.stk_statistic (
  stk_statistic_uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu uuid NOT NULL,
  CONSTRAINT fk_some_table_createdby FOREIGN KEY (created_by_uu) REFERENCES private.stk_actor(stk_actor_uu),
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu uuid NOT NULL,
  CONSTRAINT fk_some_table_updatedby FOREIGN KEY (updated_by_uu) REFERENCES private.stk_actor(stk_actor_uu),
  is_active BOOLEAN NOT NULL DEFAULT true,
  table_name TEXT,
  record_uu UUID,
  stk_statistic_type_uu UUID DEFAULT gen_random_uuid(),
  CONSTRAINT fk_stk_statistic_stattype FOREIGN KEY (stk_statistic_type_uu) REFERENCES private.stk_statistic_type(stk_statistic_type_uu),
  search_key TEXT NOT NULL DEFAULT gen_random_uuid(),
  description TEXT,
  statistic JSONB NOT NULL
);
COMMENT ON TABLE private.stk_statistic IS 'Holds the system statistic records that make retriving cached calculations easier and faster without changing the actual table. Statistic column holds the actual json values used to describe the statistic.';

CREATE VIEW api.stk_statistic AS SELECT * FROM private.stk_statistic;
COMMENT ON VIEW api.stk_statistic IS 'Holds statistic records';

--ignore in changelog
--insert into private.stk_change_log_exclude (table_name) values ('stk_statistic');
--select private.stk_table_trigger_create();

--select private.stk_table_trigger_create();
--select private.stk_trigger_created_updated();
select private.stk_trigger_create();

----sample data for stk_statistic_type
--INSERT INTO private.stk_statistic_type (statistic_type, search_key, description, statistic) VALUES
--('GRAND_TOTAL', 'GRAND_TOTAL_STAT', null, '{"total_order": 0, "total_lines": 0}'),
--('TAX_TOTAL', 'TAX_TOTAL_STAT', null, '{"total": 0}'),
--('LIFETIME_REVENUE', 'LIFETIME_REVENUE_STAT', null, '{"total": 0}'),
--('YTD_REVENUE', 'YTD_REVENUE_STAT', null, '{"total": 0}');
--
----sample data for stk_statistic
--INSERT INTO private.stk_statistic (
--    table_name,
--    record_uu,
--    stk_statistic_type_uu,
--    search_key,
--    description,
--    statistic
--) VALUES (
--    'stk_order',
--    gen_random_uuid(),
--    (SELECT stk_statistic_type_uu FROM private.stk_statistic_type WHERE statistic_type = 'GRAND_TOTAL'),
--    'ORDER_12345_GRAND_TOTAL',
--    'Grand total for order #12345',
--    '{"total_order": 1500.00, "total_lines": 5}'
--);
--
---- Sample record 2: Tax Total statistic for a specific order
--INSERT INTO private.stk_statistic (
--    table_name,
--    record_uu,
--    stk_statistic_type_uu,
--    search_key,
--    description,
--    statistic
--) VALUES (
--    'stk_order',
--    gen_random_uuid(),
--    (SELECT stk_statistic_type_uu FROM private.stk_statistic_type WHERE statistic_type = 'TAX_TOTAL'),
--    'ORDER_67890_TAX_TOTAL',
--    'Tax total for order #67890',
--    '{"total": 87.50}'
--);
--
---- Sample record 3: Lifetime Revenue statistic for a specific customer
--INSERT INTO private.stk_statistic (
--    table_name,
--    record_uu,
--    stk_statistic_type_uu,
--    search_key,
--    description,
--    statistic
--) VALUES (
--    'stk_customer',
--    gen_random_uuid(),
--    (SELECT stk_statistic_type_uu FROM private.stk_statistic_type WHERE statistic_type = 'LIFETIME_REVENUE'),
--    'CUSTOMER_1001_LIFETIME_REVENUE',
--    'Lifetime revenue for customer #1001',
--    '{"total": 25000.00}'
--);

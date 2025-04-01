

-- set session to show stk_superuser as the actor performing all the tasks
SET stk.session = '{\"psql_user\": \"stk_superuser\"}';

---- type_section start ----
CREATE TYPE private.stk_async_type_enum AS ENUM (
    'NONE',
    'NOTIFY'
);
COMMENT ON TYPE private.stk_async_type_enum IS 'Enum used in code to automate and validate async types.';

INSERT INTO private.enum_comment (enum_type, enum_value, comment, is_default) VALUES
('stk_async_type_enum', 'NONE', 'General purpose with no automation or validation', false),
('stk_async_type_enum', 'NOTIFY', 'Notify actors or services outside of the database', true)
;

CREATE TABLE private.stk_async_type (
  uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT GENERATED ALWAYS AS ('stk_async_type') STORED,
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL, -- no FK by convention
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL, -- no FK by convention
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_default BOOLEAN NOT NULL DEFAULT false,
  type_enum private.stk_async_type_enum NOT NULL,
  search_key TEXT NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT
);
COMMENT ON TABLE private.stk_async_type IS 'Holds the types of stk_async records. To see a list of all stk_async_type_enum enums and their comments, select from api.enum_value where enum_name is stk_async_type_enum.';

CREATE VIEW api.stk_async_type AS SELECT * FROM private.stk_async_type;
COMMENT ON VIEW api.stk_async_type IS 'Holds the types of stk_async records.';

-- create triggers and type records for newly created tables
SELECT private.stk_trigger_create();
SELECT private.stk_table_type_create('stk_async_type');
---- type_section end ----

---- primary_section start ----
CREATE TABLE private.stk_async (
  uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT generated always AS ('stk_async') stored,
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL, -- no FK by convention
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL, -- no FK by convention
  is_active BOOLEAN NOT NULL DEFAULT true,
  type_uu UUID NOT NULL REFERENCES private.stk_async_type(uu),
  date_processed TIMESTAMPTZ,
  is_processed BOOLEAN GENERATED ALWAYS AS (date_processed IS NOT NULL) STORED,
  search_key TEXT NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  batch_id TEXT
);
COMMENT ON TABLE private.stk_async IS 'Holds async records';

CREATE VIEW api.stk_async AS SELECT * FROM private.stk_async;
COMMENT ON VIEW api.stk_async IS 'Holds async records';

---- primary_section end ----

---- in psql execute: listen stk_async_type_notify;
----                  insert into api.stk_async_type (name,stk_async_type_enum) values ('test01','NONE') returning stk_async_type_uu;
----                  update api.stk_async_type set description = 'test01' where name = 'test01';
----                  delete from api.stk_async_type where name = 'test01';
----
---- also note that you can from command line (tmux) execute:  psql -c "LISTEN stk_async_notify;" -f /dev/stdin 2>&1
------ also note that you will need to enter ";" to see the notifications - they will not update automatically and I cannot get the "\watch 1" to work
------ This allows you to test from two different sessions

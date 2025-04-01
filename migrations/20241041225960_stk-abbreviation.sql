

-- set session to show stk_superuser as the actor performing all the tasks
SET stk.session = '{\"psql_user\": \"stk_superuser\"}';

CREATE TABLE private.stk_abbreviation (
  uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT GENERATED ALWAYS AS ('stk_appreviation') STORED,
  stk_entity_uu UUID NOT NULL REFERENCES private.stk_entity(uu),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL, -- no FK by convention
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL, -- no FK by convention
  is_active BOOLEAN NOT NULL DEFAULT true,
  search_key TEXT NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT
);
COMMENT ON TABLE private.stk_abbreviation IS 'Holds stk_abbreviation records';

CREATE VIEW api.stk_abbreviation AS SELECT * FROM private.stk_abbreviation;
COMMENT ON VIEW api.stk_abbreviation IS 'Holds stk_abbreviation records';

-- create triggers for newly created tables
select private.stk_trigger_create();

INSERT INTO private.stk_abbreviation (search_key, name) VALUES
('bp','business partner'),
('config','configuration'),
('doc','document'),
('docno','document number'),
('id','identifier'),
('idx','index'),
('fk','foreign key'),
('lnk','link'),
('loc','location'),
('mgt','management'),
('ptn','partition'),
('psql','postgresql'),
('pk','primary key'),
('salesrep','sales representative'),
('stk','stack'),
('trx','transaction'),
('uu','universal unique identifier'),
('wf','workflow'),
('wfi','workflow instance')
;

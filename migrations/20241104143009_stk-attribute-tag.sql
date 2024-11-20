

-- set session to show stk_superuser as the actor performing all the tasks
SET stk.session = '{\"psql_user\": \"stk_superuser\"}';

CREATE TYPE private.stk_attribute_tag_type_enum AS ENUM (
    'NONE',
    'CONTRACT',
    'EMAIL',
    'PHONE',
    'SNS',
    'NOTE',
    'TRANSLATION',
    'ACTIVITY',
    'INTEREST_AREA',
    'ATTACHMENT',
    'LOCATION',
    'DATE_START',
    'DATE_END',
    'DATE_RANGE',
    'SHARE',
    'ERROR',
    'TABLE',
    'COLUMN'
);
COMMENT ON TYPE private.stk_attribute_tag_type_enum IS 'used in code to automate attribute tag types';

INSERT INTO private.enum_comment (enum_type, enum_value, comment) VALUES
('stk_attribute_tag_type_enum', 'NONE', 'General purpose with no automation or validation'),
('stk_attribute_tag_type_enum', 'COLUMN', 'Column attributes with no automation or validation')
;

CREATE TABLE private.stk_attribute_tag_type (
  stk_attribute_tag_type_uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu uuid NOT NULL,
  CONSTRAINT fk_stk_attribute_tag_type_createdby FOREIGN KEY (created_by_uu) REFERENCES private.stk_actor(stk_actor_uu),
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu uuid NOT NULL,
  CONSTRAINT fk_stk_attribute_tag_type_updatedby FOREIGN KEY (updated_by_uu) REFERENCES private.stk_actor(stk_actor_uu),
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_default BOOLEAN NOT NULL DEFAULT false,
  stk_attribute_tag_type_enum private.stk_attribute_tag_type_enum NOT NULL,
  search_key TEXT NOT NULL DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  attribute_json JSONB NOT NULL -- used to hold a template json object. used as the source when creating a new stk_attribute_tag
);
COMMENT ON TABLE private.stk_attribute_tag_type IS 'Holds the types of stk_attribute_tag records. Attributes column holds a json template to be used when creating a new skt_attribute_tag record.';

CREATE VIEW api.stk_attribute_tag_type AS SELECT * FROM private.stk_attribute_tag_type;
COMMENT ON VIEW api.stk_wf_request_type IS 'Holds the types of stk_attribute_tag records. Attributes column holds a json template to be used when creating a new skt_attribute_tag record.';

CREATE TABLE private.stk_attribute_tag (
  stk_attribute_tag_uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu uuid NOT NULL,
  CONSTRAINT fk_stk_attribute_tag_createdby FOREIGN KEY (created_by_uu) REFERENCES private.stk_actor(stk_actor_uu),
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu uuid NOT NULL,
  CONSTRAINT fk_stk_attribute_tag_updatedby FOREIGN KEY (updated_by_uu) REFERENCES private.stk_actor(stk_actor_uu),
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_template BOOLEAN NOT NULL DEFAULT false,
  is_valid BOOLEAN NOT NULL DEFAULT true,
  table_name TEXT,
  record_uu UUID,
  stk_attribute_tag_type_uu UUID,
  CONSTRAINT fk_stk_attribute_tag_tagtype FOREIGN KEY (stk_attribute_tag_type_uu) REFERENCES private.stk_attribute_tag_type(stk_attribute_tag_type_uu),
  attribute_json JSONB
);
COMMENT ON TABLE private.stk_attribute_tag IS 'Holds attribute tag records that describe other records in the system as referenced by table_name and record_uu. The attributes column holds the actual json attribute tag values used to describe the foreign record.';

CREATE VIEW api.stk_attribute_tag AS SELECT * FROM private.stk_attribute_tag;
COMMENT ON VIEW api.stk_attribute_tag IS 'Holds attribute tag records that describe other records in the system as referenced by table_name and record_uu. The attributes column holds the actual json attribute tag values used to describe the foreign record.';

--select private.stk_table_trigger_create();
select private.stk_trigger_create();




CREATE TYPE private.attribute_tag_type AS ENUM (
    'NONE',
    'CONTRACT',
    'ATTACHMENT',
    'LOCATION',
    'TABLE',
    'COLUMN'
);
COMMENT ON TYPE private.attribute_tag_type IS 'used in code to automate attribute tag types';

INSERT INTO private.enum_comment (enum_type, enum_value, comment) VALUES
('attribute_tag_type', 'NONE', 'General purpose with no automation or validation'),
('attribute_tag_type', 'CONTRACT', 'Contract with limited automation or validation'),
('attribute_tag_type', 'ATTACHMENT', 'Attachment with no automation or validation'),
('attribute_tag_type', 'LOCATION', 'Location with no automation or validation'),
('attribute_tag_type', 'TABLE', 'Table attributes with no automation or validation'),
('attribute_tag_type', 'COLUMN', 'Column attributes with no automation or validation')
;

CREATE TABLE private.stk_attribute_tag_type (
  stk_attribute_tag_type_uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  --created_by_uu uuid NOT NULL,
  --CONSTRAINT fk_some_table_createdby FOREIGN KEY (created_by_uu) REFERENCES stk_user(stk_user_uu),
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  --updated_by_uu uuid NOT NULL,
  --CONSTRAINT fk_some_table_updatedby FOREIGN KEY (updated_by_uu) REFERENCES stk_user(stk_user_uu),
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_default BOOLEAN NOT NULL DEFAULT false,
  attribute_tag_type private.attribute_tag_type NOT NULL,
  search_key TEXT NOT NULL DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  attributes JSONB NOT NULL -- used to hold a template json object. used as the source when creating a new stk_attribute_tag
);
COMMENT ON TABLE private.stk_attribute_tag_type IS 'Holds the types of stk_attribute_tag records. Attributes column holds a json template to be used when creating a new skt_attribute_tag record.';

CREATE VIEW api.stk_attribute_tag_type AS SELECT * FROM private.stk_attribute_tag_type;
COMMENT ON VIEW api.stk_wf_request_type IS 'Holds the types of stk_attribute_tag records. Attributes column holds a json template to be used when creating a new skt_attribute_tag record.';

CREATE TABLE private.stk_attribute_tag (
  stk_attribute_tag_uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  --created_by_uu uuid NOT NULL,
  --CONSTRAINT fk_some_table_createdby FOREIGN KEY (created_by_uu) REFERENCES stk_user(stk_user_uu),
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  --updated_by_uu uuid NOT NULL,
  --CONSTRAINT fk_some_table_updatedby FOREIGN KEY (updated_by_uu) REFERENCES stk_user(stk_user_uu),
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_template BOOLEAN NOT NULL DEFAULT false,
  is_valid BOOLEAN NOT NULL DEFAULT true,
  table_name TEXT,
  record_uu UUID,
  stk_attribute_tag_type_uu UUID,
  CONSTRAINT fk_stk_attribute_tag_tagtype FOREIGN KEY (stk_attribute_tag_type_uu) REFERENCES private.stk_attribute_tag_type(stk_attribute_tag_type_uu),
  attributes JSONB
);
COMMENT ON TABLE private.stk_attribute_tag IS 'Holds attribute tag records that describe other records in the system as referenced by table_name and record_uu. The attributes column holds the actual json attribute tag values used to describe the foreign record.';

CREATE VIEW api.stk_attribute_tag AS SELECT * FROM private.stk_attribute_tag;
COMMENT ON VIEW api.stk_attribute_tag IS 'Holds attribute tag records that describe other records in the system as referenced by table_name and record_uu. The attributes column holds the actual json attribute tag values used to describe the foreign record.';


---- test attribute tag type values
--INSERT INTO private.stk_attribute_tag_type (name, description, attributes, attribute_tag_type) VALUES
--('Color Tag', 'Defines color attributes for items', '{"color": null, "shade": null, "intensity": null}','NONE'),
--('Size Tag', 'Defines size attributes for items', '{"width": 0, "height": 0, "depth": 0, "unit": "cm"}','NONE'),
--('Material Tag', 'Defines material attributes for items', '{"primary_material": null, "secondary_material": null, "finish": null}','NONE'),
--('Condition Tag', 'Defines condition attributes for used items', '{"overall_condition": null, "wear_level": null, "defects": []}','NONE');
--
---- test attribute tag values
--INSERT INTO private.stk_attribute_tag (table_name, record_uu, stk_attribute_tag_type_uu, attributes)
--VALUES
--('stk_inventory', gen_random_uuid(), (SELECT stk_attribute_tag_type_uu FROM private.stk_attribute_tag_type WHERE name = 'Color Tag'), '{"color": "red", "shade": "bright", "intensity": "high"}'),
--('stk_inventory', gen_random_uuid(), (SELECT stk_attribute_tag_type_uu FROM private.stk_attribute_tag_type WHERE name = 'Size Tag'), '{"width": 50, "height": 30, "depth": 20, "unit": "cm"}'),
--('stk_inventory', gen_random_uuid(), (SELECT stk_attribute_tag_type_uu FROM private.stk_attribute_tag_type WHERE name = 'Material Tag'), '{"primary_material": "wood", "secondary_material": "metal", "finish": "polished"}'),
--('stk_inventory', gen_random_uuid(), (SELECT stk_attribute_tag_type_uu FROM private.stk_attribute_tag_type WHERE name = 'Condition Tag'), '{"overall_condition": "good", "wear_level": "light", "defects": ["small scratch on surface"]}');

-- set session to show stk_superuser as the actor performing all the tasks
SET stk.session = '{"psql_user": "stk_superuser"}';

---- type_section start ----
CREATE TYPE private.stk_business_partner_type_enum AS ENUM (
    'ORGANIZATION',  -- Company/Corporation
    'INDIVIDUAL',    -- Person
    'GROUP'          -- Group of related entities
);
COMMENT ON TYPE private.stk_business_partner_type_enum IS 'Enum used in code to automate and validate business partner types. This defines the entity structure, not the business role.';

INSERT INTO private.enum_comment (enum_type, enum_value, comment, is_default, record_json) VALUES
('stk_business_partner_type_enum', 'ORGANIZATION', 'Company, corporation, or other legal entity', true, 
    '{
        "pg_jsonschema": {
            "$schema": "http://json-schema.org/draft-07/schema#",
            "type": "object",
            "properties": {
                "tax_id": {"type": "string"},
                "legal_name": {"type": "string"},
                "registration_number": {"type": "string"},
                "dba_name": {"type": "string"},
                "website": {"type": "string"}
            },
            "required": ["legal_name"]
        }
    }'::jsonb),
('stk_business_partner_type_enum', 'INDIVIDUAL', 'Individual person or sole proprietor', false,
    '{
        "pg_jsonschema": {
            "$schema": "http://json-schema.org/draft-07/schema#",
            "type": "object",
            "properties": {
                "tax_id": {"type": "string"},
                "legal_name": {"type": "string"},
                "first_name": {"type": "string"},
                "last_name": {"type": "string"},
                "date_of_birth": {"type": "string", "format": "date"}
            },
            "required": ["legal_name"]
        }
    }'::jsonb),
('stk_business_partner_type_enum', 'GROUP', 'Group of related entities or consolidated partners', false,
    '{
        "pg_jsonschema": {
            "$schema": "http://json-schema.org/draft-07/schema#",
            "type": "object",
            "properties": {
                "group_type": {"type": "string"},
                "legal_name": {"type": "string"},
                "consolidated": {"type": "boolean"}
            },
            "required": ["legal_name"]
        }
    }'::jsonb)
;

CREATE TABLE private.stk_business_partner_type (
  uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT GENERATED ALWAYS AS ('stk_business_partner_type') STORED,
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL, -- no FK by convention
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL, -- no FK by convention
  revoked TIMESTAMPTZ,
  is_revoked BOOLEAN GENERATED ALWAYS AS (revoked IS NOT NULL) STORED,
  is_default BOOLEAN NOT NULL DEFAULT false,
  type_enum private.stk_business_partner_type_enum NOT NULL,
  record_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  search_key TEXT NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT
);
COMMENT ON TABLE private.stk_business_partner_type IS 'Holds the types of stk_business_partner records. Business roles (customer, vendor, employee) are handled via tags, not types.';

CREATE VIEW api.stk_business_partner_type AS SELECT * FROM private.stk_business_partner_type;
COMMENT ON VIEW api.stk_business_partner_type IS 'Holds the types of stk_business_partner records.';

-- create triggers and type records for newly created tables
SELECT private.stk_trigger_create();
SELECT private.stk_table_type_create('stk_business_partner_type');
---- type_section end ----

---- primary_section start ----
CREATE TABLE private.stk_business_partner (
  uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT generated always AS ('stk_business_partner') stored,
  -- Following the prompting process from bp-invoice.md:
  -- 1. Normal table (not partitioned) - BPs are moderate volume
  -- 2. stk_entity_uu? Yes, BPs belong to specific entities
  stk_entity_uu UUID NOT NULL REFERENCES private.stk_entity(uu),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu UUID NOT NULL, -- no FK by convention
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu UUID NOT NULL, -- no FK by convention
  revoked TIMESTAMPTZ,
  is_revoked BOOLEAN GENERATED ALWAYS AS (revoked IS NOT NULL) STORED,
  -- 4. table_name_uu_json? No, BPs are primary records
  -- 5. is_template? Yes, for BP templates
  is_template BOOLEAN NOT NULL DEFAULT false,
  -- 6. is_valid? Yes, for active/inactive status
  is_valid BOOLEAN NOT NULL DEFAULT true,
  type_uu UUID NOT NULL REFERENCES private.stk_business_partner_type(uu),
  -- 7. parent_uu? Yes, for BP hierarchies (subsidiaries)
  parent_uu UUID REFERENCES private.stk_business_partner(uu),
  -- 8. header_uu? No, BPs are not line items
  -- 3. record_json? Yes, for flexible BP-specific data
  record_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  -- 9. processed/is_processed? No, not needed for BPs
  search_key TEXT NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT
);
COMMENT ON TABLE private.stk_business_partner IS 'Holds business partner records - anyone you engage with financially (customers, vendors, employees, contractors, partners)';

CREATE VIEW api.stk_business_partner AS SELECT * FROM private.stk_business_partner;
COMMENT ON VIEW api.stk_business_partner IS 'Holds business partner records';
---- primary_section end ----

-- create triggers for newly created tables
SELECT private.stk_trigger_create();

-- Create Business Partner Role Tag Type Enums
-- These need to be added to the existing stk_tag_type_enum
ALTER TYPE private.stk_tag_type_enum ADD VALUE IF NOT EXISTS 'BP_CUSTOMER';
ALTER TYPE private.stk_tag_type_enum ADD VALUE IF NOT EXISTS 'BP_VENDOR';
ALTER TYPE private.stk_tag_type_enum ADD VALUE IF NOT EXISTS 'BP_EMPLOYEE';
ALTER TYPE private.stk_tag_type_enum ADD VALUE IF NOT EXISTS 'BP_CONTRACTOR';

-- Add BP role enums to enum_comment with their schemas
INSERT INTO private.enum_comment (enum_type, enum_value, comment, is_default, record_json) VALUES
('stk_tag_type_enum', 'BP_CUSTOMER', 'Business Partner customer role with payment terms and credit information', false,
    '{
        "pg_jsonschema": {
            "$schema": "http://json-schema.org/draft-07/schema#",
            "type": "object",
            "properties": {
                "payment_terms_days": {"type": "integer", "default": 30},
                "credit_limit": {"type": "number", "default": 50000},
                "currency": {"type": "string", "default": "USD"},
                "price_list": {"type": "string", "default": "STANDARD"},
                "discount_percent": {"type": "number", "default": 0, "minimum": 0, "maximum": 100}
            }
        }
    }'::jsonb),
('stk_tag_type_enum', 'BP_VENDOR', 'Business Partner vendor role with payment terms and vendor categories', false,
    '{
        "pg_jsonschema": {
            "$schema": "http://json-schema.org/draft-07/schema#",
            "type": "object",
            "properties": {
                "payment_terms_days": {"type": "integer", "default": 45},
                "currency": {"type": "string", "default": "USD"},
                "vendor_category": {"type": "string"},
                "preferred_vendor": {"type": "boolean", "default": false},
                "min_order_amount": {"type": "number", "default": 0}
            }
        }
    }'::jsonb),
('stk_tag_type_enum', 'BP_EMPLOYEE', 'Business Partner employee role with employment information', false,
    '{
        "pg_jsonschema": {
            "$schema": "http://json-schema.org/draft-07/schema#",
            "type": "object",
            "properties": {
                "hire_date": {"type": "string", "format": "date"},
                "department": {"type": "string"},
                "position": {"type": "string"},
                "employee_id": {"type": "string"},
                "employment_status": {"type": "string", "enum": ["ACTIVE", "INACTIVE", "TERMINATED"]}
            }
        }
    }'::jsonb),
('stk_tag_type_enum', 'BP_CONTRACTOR', 'Business Partner contractor role with contract terms', false,
    '{
        "pg_jsonschema": {
            "$schema": "http://json-schema.org/draft-07/schema#",
            "type": "object",
            "properties": {
                "contract_start": {"type": "string", "format": "date"},
                "contract_end": {"type": "string", "format": "date"},
                "hourly_rate": {"type": "number"},
                "currency": {"type": "string", "default": "USD"},
                "contract_type": {"type": "string"}
            }
        }
    }'::jsonb);

-- Create the tag type records for the BP role tags
SELECT private.stk_table_type_create('stk_tag_type');
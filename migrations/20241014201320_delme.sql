-- Add migration script here
CREATE TABLE private.stk_delme (
  stk_delme_uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_uu uuid,
  updated TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by_uu uuid,
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_default BOOLEAN NOT NULL DEFAULT false,
  search_key TEXT NOT NULL DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT
);
COMMENT ON TABLE private.stk_delme IS 'delete this table!!!';

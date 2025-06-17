-- set session to show stk_superuser as the actor performing all the tasks
SET stk.session = '{"psql_user": "stk_superuser"}';

-- Create pg_jsonschema extension for JSON Schema validation
CREATE EXTENSION IF NOT EXISTS pg_jsonschema;


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA api;




COMMENT ON SCHEMA api IS 'schema used to create a public interface to the private schema';



CREATE FUNCTION api.html_sanitize(text[]) RETURNS text[]
    LANGUAGE sql
    AS $_$
  select array(
    select api.html_sanitize(t)
    from unnest($1) as t
  )
$_$;




COMMENT ON FUNCTION api.html_sanitize(text[]) IS 'pass through function to accept an array input';



CREATE FUNCTION api.html_sanitize(text) RETURNS text
    LANGUAGE sql
    AS $_$
  select replace(replace(replace(replace(replace($1, '&', '&amp;'), '"', '&quot;'),'>', '&gt;'),'<', '&lt;'), '''', '&apos;')
$_$;




COMMENT ON FUNCTION api.html_sanitize(text) IS 'utility function to safely accept function parameters';



CREATE FUNCTION api.html_table(p_schemaname text, p_tablename text, p_columnnames text[]) RETURNS text
    LANGUAGE plpgsql
    AS $_$

DECLARE
  schemaname TEXT := api.html_sanitize(p_schemaname);
  tablename TEXT := api.html_sanitize(p_tablename);
  columnnames TEXT[] := api.html_sanitize(p_columnnames);
  result TEXT := '';
  searchsql TEXT := '';
  var_match TEXT := '';
  col TEXT;
  header TEXT;
  column_exists BOOLEAN;
  tabletype TEXT;

BEGIN
  -- Determine the table type (table or view)
  SELECT CASE WHEN table_type = 'BASE TABLE' THEN 'r' ELSE 'v' END
  INTO tabletype
  FROM information_schema.tables
  WHERE table_schema = schemaname
    AND table_name = tablename;

  IF tabletype IS NULL THEN
    RAISE EXCEPTION 'Table or view %.% does not exist', schemaname, tablename;
  END IF;

  header := '<thead>' || E'\n' || E'\t' || '<tr>' || E'\n';
  searchsql := 'SELECT ';

  -- Loop through the provided column names
  FOREACH col IN ARRAY columnnames
  LOOP
    -- Check if the column exists in the table
    SELECT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = schemaname
        AND table_name = tablename
        AND column_name = col
    ) INTO column_exists;

    IF column_exists THEN
      header := header || E'\t\t' || '<th>' ||  upper(col) || '</th>' || E'\n';
      searchsql := searchsql || $QUERY$ '<td>' || coalesce($QUERY$ || col || $QUERY$::text,'') || '</td>' ||$QUERY$ ;
    ELSE
      RAISE WARNING 'Column % does not exist in table %.%', col, schemaname, tablename;
    END IF;
  END LOOP;

  searchsql := substring(searchsql from 1 for length(searchsql) - 2); --remove last concatenate
  header := header || E'\t' || '</tr>' || E'\n' || '</thead>' || E'\n';

  searchsql := searchsql || ' FROM ' || schemaname || '.' || tablename;

  --RAISE NOTICE 'Debug: header is %', header;
  --RAISE NOTICE 'Debug: searchsql is %', searchsql;

  result := '<table>' || E'\n';
  result := result || header || '<tbody>' || E'\n';
  FOR var_match IN EXECUTE(searchsql) LOOP
    IF result > '' THEN
      result := result || E'\t' || '<tr>' || var_match || E'\n\t' || '</tr>' || E'\n';
    END IF;
  END LOOP;
  result :=  result || '</tbody>' || E'\n' || '</table>' || E'\n';

  RETURN result;

END;
$_$;




COMMENT ON FUNCTION api.html_table(p_schemaname text, p_tablename text, p_columnnames text[]) IS 'convert psql table to html table';



CREATE FUNCTION api.index() RETURNS public."text/html"
    LANGUAGE sql
    AS $_$
  select $html$
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>PostgREST + HTMX To-Do List</title>
      <!-- Pico CSS for CSS styling -->
      <link href="https://cdn.jsdelivr.net/npm/@picocss/pico@next/css/pico.min.css" rel="stylesheet"/>
      <!-- htmx for AJAX requests -->
      <script src="https://unpkg.com/htmx.org"></script>
    </head>
    <body>
      <main class="container"
            hx-headers='{"Accept": "text/html"}'>
        <article>
          <h5 style="text-align: center;">
            PostgREST + HTMX To-Do List
          </h5>
          <form hx-post="/rpc/add_request"
                hx-target="#request-list-area"
                hx-trigger="submit"
                hx-on="htmx:afterRequest: this.reset()">
            <input type="text" name="_task" placeholder="Add a request...">
          </form>
          <div id="request-list-area">
            $html$
              || api.html_table('api','stk_wf_request',array['name','description','is_active']) ||
            $html$
          <div>
        </article>
      </main>
      <!-- Script for Ionicons icons -->
      <script type="module" src="https://unpkg.com/ionicons@7.1.0/dist/ionicons/ionicons.esm.js"></script>
      <script nomodule src="https://unpkg.com/ionicons@7.1.0/dist/ionicons/ionicons.js"></script>
    </body>
    </html>
  $html$;
$_$;




COMMENT ON FUNCTION api.index() IS 'function to support PostgREST that acts like a homepage index dynamic page';



CREATE FUNCTION api.stk_form_post_fn(jsonb) RETURNS public."text/html"
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
BEGIN
    INSERT INTO private.stk_form_post (form_data)
    VALUES ($1);
    RETURN 'Submitted - Thank you!!';
END;
$_$;




COMMENT ON FUNCTION api.stk_form_post_fn(jsonb) IS 'api function used to write to stk_form_post table';



CREATE VIEW api.enum_value AS
 SELECT t.typname AS enum_name,
    e.enumlabel AS enum_value,
    ec.comment
   FROM (((pg_type t
     JOIN pg_enum e ON ((t.oid = e.enumtypid)))
     JOIN pg_namespace n ON ((n.oid = t.typnamespace)))
     LEFT JOIN private.enum_comment ec ON (((ec.enum_type = t.typname) AND (ec.enum_value = e.enumlabel))))
  WHERE ((t.typtype = 'e'::"char") AND (n.nspname = 'private'::name))
  ORDER BY t.typname, e.enumsortorder;




COMMENT ON VIEW api.enum_value IS 'Shows all `api` schema enum types in the database with their values and comments';



CREATE VIEW api.stk_actor AS
 SELECT stk_actor_uu,
    created,
    updated,
    is_active,
    is_template,
    is_valid,
    stk_actor_type_uu,
    stk_actor_parent_uu,
    search_key,
    name,
    name_first,
    name_middle,
    name_last,
    description,
    psql_user
   FROM private.stk_actor;




COMMENT ON VIEW api.stk_actor IS 'Holds actor records';



CREATE VIEW api.stk_actor_type AS
 SELECT stk_actor_type_uu,
    created,
    updated,
    is_active,
    is_default,
    actor_type,
    search_key,
    name,
    description
   FROM private.stk_actor_type;




COMMENT ON VIEW api.stk_actor_type IS 'Holds the types of stk_actor records.';



CREATE VIEW api.stk_attribute_tag AS
 SELECT stk_attribute_tag_uu,
    created,
    updated,
    is_active,
    is_template,
    is_valid,
    table_name,
    record_uu,
    stk_attribute_tag_type_uu,
    attributes
   FROM private.stk_attribute_tag;




COMMENT ON VIEW api.stk_attribute_tag IS 'Holds attribute tag records that describe other records in the system as referenced by table_name and record_uu. The attributes column holds the actual json attribute tag values used to describe the foreign record.';



CREATE VIEW api.stk_attribute_tag_type AS
 SELECT stk_attribute_tag_type_uu,
    created,
    updated,
    is_active,
    is_default,
    attribute_tag_type,
    search_key,
    name,
    description,
    attributes
   FROM private.stk_attribute_tag_type;




CREATE VIEW api.stk_change_log AS
 SELECT stk_change_log_uu,
    created,
    created_by_uu,
    updated,
    updated_by_uu,
    table_name,
    record_uu,
    column_name,
    batch_id,
    changes
   FROM private.stk_change_log;




COMMENT ON VIEW api.stk_change_log IS 'Holds change_log records';



CREATE VIEW api.stk_statistic AS
 SELECT stk_statistic_uu,
    created,
    created_by_uu,
    updated,
    updated_by_uu,
    is_active,
    table_name,
    record_uu,
    stk_statistic_type_uu,
    search_key,
    description,
    statistic
   FROM private.stk_statistic;




COMMENT ON VIEW api.stk_statistic IS 'Holds statistic records';



CREATE VIEW api.stk_statistic_type AS
 SELECT stk_statistic_type_uu,
    created,
    created_by_uu,
    updated,
    updated_by_uu,
    is_active,
    statistic_type,
    search_key,
    description,
    statistic
   FROM private.stk_statistic_type;




COMMENT ON VIEW api.stk_statistic_type IS 'Holds the types of stk_statistic records.';



CREATE VIEW api.stk_system_config AS
 SELECT stk_system_config_uu,
    created,
    updated,
    is_active,
    stk_system_config_type_uu,
    search_key,
    description,
    configuration
   FROM private.stk_system_config;




COMMENT ON VIEW api.stk_system_config IS 'Holds the system configuration records that dictates how the system behaves. Configuration column holds the actual json configuration values used to describe the system configuration.';



CREATE VIEW api.stk_system_config_type AS
 SELECT stk_system_config_type_uu,
    created,
    updated,
    is_active,
    system_config_level_type,
    search_key,
    description,
    configuration
   FROM private.stk_system_config_type;




COMMENT ON VIEW api.stk_system_config_type IS 'Holds the types of stk_system_config records. Configuration column holds a json template to be used when creating a new stk_system_config record.';



CREATE VIEW api.stk_wf_request AS
 SELECT stk_wf_request_uu,
    created,
    updated,
    is_active,
    is_template,
    is_valid,
    stk_wf_request_type_uu,
    stk_wf_request_parent_uu,
    name,
    description
   FROM private.stk_wf_request;




COMMENT ON VIEW api.stk_wf_request IS 'Holds wf_request records';



CREATE VIEW api.stk_wf_request_type AS
 SELECT stk_wf_request_type_uu,
    created,
    updated,
    is_active,
    is_default,
    wf_request_type,
    search_key,
    name,
    description
   FROM private.stk_wf_request_type;




COMMENT ON VIEW api.stk_wf_request_type IS 'Holds the types of stk_attribute_tag records. Attributes column holds a json template to be used when creating a new skt_attribute_tag record.';




















































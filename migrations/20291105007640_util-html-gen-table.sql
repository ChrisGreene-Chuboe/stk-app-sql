
--create domain "text/html" as text;

create or replace function api.html_sanitize(text) returns text as $$
  select replace(replace(replace(replace(replace($1, '&', '&amp;'), '"', '&quot;'),'>', '&gt;'),'<', '&lt;'), '''', '&apos;')
$$ language sql;
COMMENT ON FUNCTION api.html_sanitize(text) IS 'utility function to safely accept function parameters';

create or replace function api.html_sanitize(text[]) returns text[] as $$
  select array(
    select api.html_sanitize(t)
    from unnest($1) as t
  )
$$ language sql;
COMMENT ON FUNCTION api.html_sanitize(text[]) IS 'pass through function to accept an array input';

-- generic function to return data from any table or view
-- example usage:
  -- select api.genhtml('api','stk_request' , 'v', array['name']);
-- Notes:
  -- this function seems to be in a good state
  -- there is no way to specify where or order
-- reference: https://stackoverflow.com/questions/4265155/generate-html-from-postgresql-function
CREATE OR REPLACE FUNCTION api.html_table(
    p_schemaname text,
    p_tablename text,
    p_columnnames text[]
)
  RETURNS text AS $BODY$

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
$BODY$
  LANGUAGE 'plpgsql' VOLATILE;
COMMENT ON FUNCTION api.html_table(text, text, text[]) IS 'convert psql table to html table'; 

-- example function that acts like a web server and returns an index - home page showing request
-- Notes:
  -- incomplete: request_add not yet supported
  -- incomplete: would be nice to have delete and edit icons
-- reference: https://docs.postgrest.org/en/v12/how-tos/providing-html-content-using-htmx.html#providing-html-content-using-htmx
create or replace function api.index() returns "text/html" as $$
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
              || api.html_table('api','stk_request',array['name','description','is_active']) ||
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
$$ language sql;
COMMENT ON FUNCTION api.index() IS 'function to support PostgREST that acts like a homepage index dynamic page';

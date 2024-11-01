
--create domain "text/html" as text;

create or replace function api.html_sanitize(text) returns text as $$
  select replace(replace(replace(replace(replace($1, '&', '&amp;'), '"', '&quot;'),'>', '&gt;'),'<', '&lt;'), '''', '&apos;')
$$ language sql;

-- generic function to return data from any table or view
-- example usage:
  -- select api.genhtml('api','stk_todo' , 'v', array['name']);
CREATE OR REPLACE FUNCTION api.html_table(text, text, text, text[])
  RETURNS text AS $BODY$

DECLARE
  schemaname ALIAS FOR $1;
  tablename ALIAS FOR $2;
  tabletype ALIAS FOR $3; -- r for table and v for view
  columnnames ALIAS FOR $4;
  result TEXT := '';
  searchsql TEXT := '';
  var_match TEXT := '';
  col RECORD;
  header TEXT;

BEGIN

  header := '<thead>' || E'\n' || E'\t' || '<tr>' || E'\n';
  searchsql := 'SELECT ';
  FOR col IN SELECT attname
    FROM pg_attribute AS a
    JOIN pg_class AS c ON a.attrelid = c.oid
    JOIN pg_namespace AS n on c.relnamespace = n.oid
    WHERE c.relname = tablename
        AND n.nspname = schemaname
        AND c.relkind = tabletype
        AND attnum > 0
        AND attname = ANY(columnnames)
  LOOP
    header := header || E'\t\t' || '<th>' ||  upper(col.attname) || '</th>' || E'\n';
    searchsql := searchsql || $QUERY$ '<td>' || $QUERY$ || col.attname || $QUERY$ || '</td>' $QUERY$ ;
  END LOOP;
  header := header || E'\t' || '</tr>' || E'\n' || '</thead>' || E'\n';
  RAISE NOTICE 'Debug: header is %', header;
  RAISE NOTICE 'Debug: searchsql is %', searchsql;

  searchsql := searchsql || ' FROM ' || schemaname || '.' || tablename;

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

-- example function that acts like a web server and returns an index - home page showing todos
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
            style="max-width: 600px"
            hx-headers='{"Accept": "text/html"}'>
        <article>
          <h5 style="text-align: center;">
            PostgREST + HTMX To-Do List
          </h5>
          <form hx-post="/rpc/add_todo"
                hx-target="#todo-list-area"
                hx-trigger="submit"
                hx-on="htmx:afterRequest: this.reset()">
            <input type="text" name="_task" placeholder="Add a todo...">
          </form>
          <div id="todo-list-area">
            $html$
              || api.html_table('api','stk_todo','v',array['name']) ||
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

-- execute from test directory
  --psql -Aqt -v t="stk_actor" -f sql-templates/list.sql | grep -v 'SET\|Time:'
  --psql -Aqt -v l=1 -v t="stk_actor" -f sql-templates/list.sql | grep -v 'SET\|Time:' --limits results

SELECT :{?l} as is_limit
\gset

--\echo :is_limit

--\if :l
--\echo hey
--\endif
--;

SELECT name,search_key FROM api.:"t"
\if :is_limit
limit :'l'
\endif
;

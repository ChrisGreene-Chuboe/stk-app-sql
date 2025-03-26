
--SELECT :{?name} as is_name
--\gset

--SELECT :{?search_key} as is_search_key
--\gset

--works

INSERT INTO api.:"t"
(
  :cols
)
VALUES
(
  :vals
)
returning uu
;

--SELECT name,search_key
--FROM api.:"t"
--\if :is_where
--where :w
--\endif
--\if :is_first
--fetch first :f rows only
--\endif

;

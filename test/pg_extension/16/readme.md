# pg_jsonschema
https://github.com/supabase/pg_jsonschema
Used Release => installed deb => copied psql v16 files here using:

```bash
cp /var/lib/postgresql/extension/pg_jsonschema--0.3.3.sql pg_extension/16/.
cp /var/lib/postgresql/extension/pg_jsonschema.control pg_extension/16/.
cp /usr/lib/postgresql/lib/pg_jsonschema.so pg_extension/16/.
```

To use in nix... - already updated in shell.nix
.so to /nix/store/1gax5xs6h1b70gk7z274kx4qh04hsn96-postgresql-16.4/lib/
.control and .sql to /nix/store/1gax5xs6h1b70gk7z274kx4qh04hsn96-postgresql-16.4/share/postgresql/extension/

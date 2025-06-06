# pg_jsonschema for PostgreSQL 17
https://github.com/supabase/pg_jsonschema

## Extension Files Setup
Downloaded PostgreSQL 17 compatible files from GitHub release v0.3.3:

```bash
curl -L -o pg_jsonschema-v0.3.3-pg17-amd64-linux-gnu.deb \
  https://github.com/supabase/pg_jsonschema/releases/download/v0.3.3/pg_jsonschema-v0.3.3-pg17-amd64-linux-gnu.deb

dpkg -x pg_jsonschema-v0.3.3-pg17-amd64-linux-gnu.deb extracted

cp extracted/var/lib/postgresql/extension/pg_jsonschema--0.3.3.sql .
cp extracted/var/lib/postgresql/extension/pg_jsonschema.control .
cp extracted/usr/lib/postgresql/lib/pg_jsonschema.so .
```

## Nix Integration (CURRENT SOLUTION)
The extension is properly integrated using Nix's `buildEnv` pattern in shell.nix:

```nix
# Create pg_jsonschema extension package
pg_jsonschema_ext = pkgs.stdenv.mkDerivation {
  name = "pg_jsonschema-extension";
  src = ./pg_extension/17;
  installPhase = ''
    mkdir -p $out/lib $out/share/postgresql/extension
    cp pg_jsonschema.so $out/lib/
    cp pg_jsonschema.control $out/share/postgresql/extension/
    cp pg_jsonschema--0.3.3.sql $out/share/postgresql/extension/
  '';
};

# Combine PostgreSQL with extension using buildEnv (no rebuild)
postgresql-with-jsonschema = pkgs.buildEnv {
  name = "postgresql-with-jsonschema";
  paths = [ pkgs.postgresql pg_jsonschema_ext ];
};
```

This approach:
- ✅ Uses binary PostgreSQL from nixpkgs (no source compilation)
- ✅ Fast builds (~30 seconds vs 10+ minutes)
- ✅ Follows proper Nix patterns (declarative, reproducible)
- ✅ PostgreSQL 17 compatible extension files
- ✅ Eliminates manual file manipulation at runtime

## Version Compatibility
- **PostgreSQL Version**: 17.x
- **Extension Version**: 0.3.3
- **Platform**: amd64 Linux
- **Verified Working**: Yes ✅

## Files in this directory
- `pg_jsonschema.so` - Compiled extension library
- `pg_jsonschema.control` - Extension metadata
- `pg_jsonschema--0.3.3.sql` - Extension SQL definitions
- `readme.md` - This documentation
# STK PSQL Module

This module provides common commands for executing PostgreSQL queries within Nushell.

## Available Commands

### `psql exec`

Execute a SQL query using psql with the `.psqlrc-nu` configuration file.

```nu
psql exec "SELECT * FROM api.stk_event LIMIT 5"
```

### `psql exec-raw`

Execute a SQL query and return the raw results without special formatting.

```nu
psql exec-raw "SELECT uu FROM api.stk_event LIMIT 1"
```

## Usage Examples

```nu
# Import the module
use modules *

# Execute a query with nice formatting 
psql exec "SELECT uu, name, created FROM api.stk_event ORDER BY created DESC LIMIT 3"

# Execute a raw query for scripting
let event_id = (psql exec-raw "SELECT uu FROM api.stk_event LIMIT 1" | str trim)
```

## Implementation Details

The module uses the `.psqlrc-nu` configuration file to provide consistent output formatting. This is the same approach used in the `stk_event` module's `event list` command.

## PostgreSQL Development Guidelines & Gotchas

### JSON Column Handling - Critical Issue

**IMPORTANT**: JSON fields in chuck-stack return empty strings `''` instead of `NULL` for missing values.

**❌ Wrong - will not work:**
```nushell
# This fails because missing JSON fields return "" not null
| where ($it.table_name_uu_json?.api?.stk_request? | is-empty)  # Won't find parents
```
```sql
WHERE table_name_uu_json->>'uu' IS NULL          -- Won't find parents
```

**✅ Correct - handles empty strings:**
```nushell
# Use direct field access with is-empty which handles both null and empty strings
| where ($it.table_name_uu_json.uu | is-empty)
```
```sql
WHERE table_name_uu_json->>'uu' = ''             -- Check for empty string
```

This affects all JSON columns ending with `_json` and impacts parent/child relationship detection throughout chuck-stack modules.

### Data Type Conversion

The `psql exec` command automatically converts PostgreSQL data types to nushell types:
- **Datetime columns**: `created`, `updated`, and columns starting with `date_` 
- **JSON columns**: All columns ending with `_json` are parsed from JSON strings to nushell structures
- **Boolean columns**: Columns starting with `is_` are converted from PostgreSQL's `t`/`f` to nushell's `true`/`false`

### SQL in Nushell String Interpolation

**IMPORTANT**: In nushell string interpolation, opening parentheses `(` have special meaning and must be escaped in SQL:

**❌ Wrong - causes parse errors:**
```nushell
let sql = $"INSERT INTO table (column) VALUES ('value')"
```

**✅ Correct - escape opening parentheses:**
```nushell
let sql = $"INSERT INTO table \(column) VALUES \('value')"
```
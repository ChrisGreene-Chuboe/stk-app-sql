# STK PSQL Module

This module provides common commands for executing PostgreSQL queries within Nushell.

## Available Commands

### `psql exec`

Execute a SQL query using psql with the `.psqlrc-nu` configuration file.

```nu
psql exec "SELECT * FROM api.stk_event LIMIT 5"
```

### Generic Helper Commands

The module also provides generic commands for common database operations:
- `psql list-records` - SELECT with ordering and limits
- `psql get-record` - Single record by UUID
- `psql revoke-record` - Soft delete pattern
- `psql new-record` - Standard INSERT pattern
- `psql list-types` - Show available types for any concept
- `psql get-type` - Look up type by search key or name
- `psql detail-record` - Get record with type information
- `psql append-table-name-uu-json` - Generic enrichment for table_name_uu_json pattern

### Data Enrichment Commands

These commands add related data columns to records:
- `lines` - Add related line records (header-line pattern, e.g., project -> project_line)
- `children` - Add child records (parent-child pattern, e.g., sub-projects via parent_uu)

## Usage Examples

```nu
# Import the module
use modules *

# Execute a query with nice formatting 
psql exec "SELECT uu, name, created FROM api.stk_event ORDER BY created DESC LIMIT 3"

# Get a single value for scripting
let event_id = (psql exec "SELECT uu FROM api.stk_event LIMIT 1" | get uu.0)

# Use generic commands
psql list-records "api" "stk_event" "name, created, uu" 10
psql get-record "api" "stk_event" "name, created" "uu, description" $some_uuid
```

## Best Practices and Guidelines

For comprehensive nushell-PostgreSQL integration patterns, including:
- String interpolation and parentheses escaping
- Chuck-stack specific JSON column handling
- Data type conversion details
- Module architecture patterns
- psql advanced features

See: **https://www.chuck-stack.org/ls/postgres-convention/nushell.html**
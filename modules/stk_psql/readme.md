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
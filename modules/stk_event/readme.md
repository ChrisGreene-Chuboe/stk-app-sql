# STK Event Module

This Nushell module provides functionality for working with the `stk_event` table in the chuck-stack database.

## Installation

No installation is required. The module is available in the `modules/stk_event` directory and can be imported using:

```nu
use modules *
```

## Usage

### Append Event

The primary function of this module is to append text to the `stk_event` table with a specified name (topic).

```nu
# Using the custom .append command:
"this is a quick event test" | .append event "test"
```

This command performs the following actions:
1. Creates a JSON object with the text: `{"text": "this is a quick event test"}`
2. Inserts a record into the `api.stk_event` table with:
   - `name` = "test"
   - `record_json` = the JSON object
3. Returns the UUID of the created record

### List Events

List the 10 most recent events from the database:

```nu
event list
```

Returns columns: `uu`, `name`, `record_json`, `created`, `updated`, `is_revoked`

### Get Event

Retrieve a specific event by its UUID:

```nu
event get "uuid-goes-here"
```

Returns the same columns as `event list` but for a specific event.

## Requirements

This module requires:
- Nushell
- Access to a PostgreSQL database with the chuck-stack schema
- The `psql` command available in PATH
- Proper database connection configuration

## Implementation Details

The module uses the `psql exec` command to interact with the database. All commands work with the `api.stk_event` table and utilize PostgreSQL's `jsonb_build_object` function for JSON handling.
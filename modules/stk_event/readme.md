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
"this is a quick event test" | .append "test" 

# Using the traditional command approach:
"this is a quick event test" | stk_event append "test"
```

Both commands perform the same action:
1. Create a JSON object with the text: `{"text": "this is a quick event test"}`
2. Insert a record into the `api.stk_event` table with:
   - `name` = "test"
   - `record_json` = the JSON object

### List Events

List recent events from the database:

```nu
# List the 10 most recent events
stk_event list

# List a specific number of events
stk_event list --limit 5
```

### Get Event

Retrieve a specific event by its UUID:

```nu
stk_event get "uuid-goes-here"
```

## Requirements

This module requires:
- Nushell
- Access to a PostgreSQL database with the chuck-stack schema
- Environment variables set up by `test/shell.nix`

## Implementation Details

The module uses the `psql` command-line tool to interact with the database. The `--env` flag is used to create the `.append` command with custom syntax.
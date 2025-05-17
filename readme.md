# stk-app-sql 

The purpose of this repository is to create the application/framework aspect of the chuck-stack.

## Summary

There are two core components:

- PostgreSQL - used to persist an organizations shared and historical data
- Nushell - used to give users a cli environment to CRUD data and connect the chuck-stack with the outside world

## Current State

### PostgreSQL

The PostgreSQL aspect of this repository is usable and functioning. Here is what you can do today:

- Migration scripts can be found in ./migrations/
- We can insert a record into 'stk_event' with the following: `insert into api.stk_event (name) values ('test')`
- Note that all columns default accordingly (triggers and context variables are used to set the remaining columns)

### Nushell

We are starting to develop Nushell modules in the ./modules/ directory.

Please ignore all Nushell files in ./test/cli/

## Test

We actively run the test/shell.nix to play with the chuck-stack database DDL design. 

```bash
cd your-cloned-directory/test/
nix-shell
```

The `nix-shell` command will find the local shell.nix file, execute it, and drop you into a shell with proper tools and psql configuration.

When you exit the shell, the script's `trap` command will remove all shell artifacts (including removing psql).

## Deployment

One purpose of this repository is to support the [stk-todo-app.nix](https://github.com/chuckstack/chuck-stack-nix/blob/main/nixos/stk-todo-app.nix) chuck-stack application. 

The [stk-todo-app.nix](https://github.com/chuckstack/chuck-stack-nix/blob/main/nixos/stk-todo-app.nix) configuration file creates a services that clones and executes this repository every time the migration service is restarted.

## sqlx-cli

We use sqlx-cli to manage database migrations.

This repository relies on the [postgresql.nix](https://github.com/chuckstack/chuck-stack-nix/blob/main/nixos/postgresql.nix) to install [sqlx-cli](https://github.com/launchbadge/sqlx/tree/main/sqlx-cli). You can also install sqlx-cli locally using cargo.

Here is an example of creating a new migration. This will result in a new file created in the migration directory with a date stamp prefix.

```bash
sqlx migrate add test01
```

For more details about using sqlx-cli, visit the [sqlx-cli repo readme](https://github.com/launchbadge/sqlx/tree/main/sqlx-cli).

## Nushell Module CRUD

Nushell modules have been implemented to perform simple CRUD tasks on the stk_event table. The modules are located in the `./modules/` directory.

### Using the Event Module

You can use the Nushell modules to interact with the stk_event table. For example:

```nu
# Import the module
use modules *

# Add an event with a specific topic
"this is a quick event test" | .append event "test"
```

Let's break this statement down:

- "this is a quick event test" is the text to be added to the 'stk_event.record_json' --> text json object
- `.append` is the nushell command that performs the insert via `psql`
- "test" is the name of the event
  - note that when managing events, the 'name' is usually referred to as a 'topic'
  - in the database, we use 'name' so that the 'stk_event' table remains consistent with all other tables.

### Additional Event Commands

The module also provides these commands:

```nu
# List recent events (default: last 10)
event list

# List specific number of events
event list --limit 5

# Get event by UUID
event get "uuid-goes-here"
```

### Setup

To use these modules:

1. Start the development environment with `nix-shell` in the `test/` directory
2. Import the modules with `use modules *` in your Nushell session

## TODO Common psql Command

The next thing to do is create a common nushell module to execute psql. The current model/example (using .psqlrc-nu) is in ./modules/stk_event/mod.nu => `event list`.

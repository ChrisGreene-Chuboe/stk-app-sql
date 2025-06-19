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

See:

- ./modules/README.md
- ./modules/MODULE_DEVELOPMENT.md

### aichat

Aichat is installed in the test suite; however, the test suite does not configure the environment variables yet. It currently depends on ~/.config/aichat/config.yaml. Said another way, it depends on outside configuration.

See:

- ./modules/stk_ai/
- ./modules/stk_address/

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

## Migration

We use the following to support migration scripts. This script is especially designed to support ERP-style migrations where you have multiple 'targets' that reflect the major groups who contribute to a given deployment (core, integrator, customer, ...)

- https://github.com/chuckstack/chuck-stack-nushell-psql-migration

We previously used sqlx-cli to manage database migrations.

## Nushell Module CRUD

The ./modules/MODULE_DEVELOPMENT.md covers this topic extensively.

You can also reference the ./test/suite/* files for usage examples.

We have gone to great lengths to document commands in the command help (example: ./modules/stk_item/mod.nu)

## TODO


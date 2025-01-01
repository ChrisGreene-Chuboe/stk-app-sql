# stk-app-sql 

The purpose of this repository is to help deploy, play with, and test the chuck-stack PostgreSQL deployment.

## Summary

This repository is still alpha. The test/shell.nix is not fully self contained yet (example: does not install/configure aichat).

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

This repository relies on the [postgresql.nix](https://github.com/chuckstack/chuck-stack-nix/blob/main/nixos/postgresql.nix) to install [sqlx-cli](https://github.com/launchbadge/sqlx/tree/main/sqlx-cli). You can also install sqlx-cli locally using cargo.

Here is an example of creating a new migration. This will result in a new file created in the migration directory with a date stamp prefix.

```bash
sqlx migrate add test01
```

For more details about using sqlx-cli, visit the [sqlx-cli repo readme](https://github.com/launchbadge/sqlx/tree/main/sqlx-cli).

## Testing

The [shell.nix](./test/shell.nix) nix-shell helps you quickly test migrations as you make changes. Read the file's comments for details.

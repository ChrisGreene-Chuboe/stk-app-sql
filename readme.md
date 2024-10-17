# stk-todo-app-sql 

The purpose of this repository is to support the [stk-todo-app.nix](https://github.com/chuckstack/chuck-stack-nix/blob/main/nixos/stk-todo-app.nix) chuck-stack application. 

The [stk-todo-app.nix](https://github.com/chuckstack/chuck-stack-nix/blob/main/nixos/stk-todo-app.nix) configuration file creates a services that clones and executes this repository everytime the migration service is restarted.

## sqlx-cli

This repository relies on the [postgresql.nix](https://github.com/chuckstack/chuck-stack-nix/blob/main/nixos/postgresql.nix) to install [sqlx-cli](https://github.com/launchbadge/sqlx/tree/main/sqlx-cli). You can also install sqlx-cli locally using cargo.

Here is an example of creating a new migration. This will result in a new file created in the migration directory with a date stamp prefix.

```bash
sqlx migrate add test01
```

For more details about using sqlx-cli, visit the [sqlx-cli repo readme](https://github.com/launchbadge/sqlx/tree/main/sqlx-cli).

## Testing

The [shell.nix](./test/shell.nix) nix-shell helps you quickly test migrations as you make changes. Read the file's comments for details.

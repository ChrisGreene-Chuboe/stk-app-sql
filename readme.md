# chuck-stack-todo-app 

The purpose of this repository is to support the [stk-todo-app-install.nix](https://github.com/chuckstack/chuck-stack-nix/blob/main/stk-todo-app-install.nix) chuck-stack application. 

The [stk-todo-app-install.nix](https://github.com/chuckstack/chuck-stack-nix/blob/main/stk-todo-app-install.nix) configuration file creates a services that clones and executes this repository everytime the migration service is restarted.

## sqlx-cli

This repository relies on the [postgresql.nix](https://github.com/chuckstack/chuck-stack-nix/blob/main/postgresql.nix) to install [sqlx-cli](https://github.com/launchbadge/sqlx/tree/main/sqlx-cli). You can also install sqlx-cli locally using cargo.

Here is an example of creating a new migration:

```bash
sqlx migrate add test01
```

This will result in a new file created in the migration directory with a date stamp prefix.

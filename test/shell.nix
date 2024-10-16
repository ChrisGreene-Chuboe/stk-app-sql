{ pkgs ? import <nixpkgs> {} }:

# Prerequisites
  # install Nix package manager or be using NixOS

# The purpose of this shell is to:
  # install postgresql
  # install sqlx-cli
  # create a local psql cluster (in this directory)
  # run the migrations and report success or failure
  # allow you to view and interact with the results using 'psqlx'
  # destroy all artifacts upon leaving the shell

let
  # Function to run migrations
  runMigrations = pkgs.writeShellScriptBin "run-migrations" ''
    echo "Running migrations..."
    sqlx migrate run
  '';

in pkgs.mkShell {
  buildInputs = [
    pkgs.postgresql
    pkgs.sqlx-cli
    runMigrations
  ];

  shellHook = ''
    export PGDATA="$PWD/pgdata"
    export PGHOST="$PGDATA"
    export PGUSER=postgres
    export PGDATABASE=stk_todo_db
    export DATABASE_URL="postgresql:///$PGDATABASE?host=$PGDATA"
    alias psqlx="psql -h $PWD/pgdata/ -d stk_todo_db"

    if [ ! -d "$PGDATA" ]; then
      echo "Initializing PostgreSQL database..."
      initdb -D "$PGDATA" --no-locale --encoding=UTF8 --username=$PGUSER && echo "listen_addresses = '''" >> $PGDATA/postgresql.conf
      pg_ctl start -o "-k \"$PGDATA\"" -l "$PGDATA/postgresql.log"
      createdb $PGDATABASE -h $PGDATA -U $PGUSER 
    else
      echo "Starting PostgreSQL..."
      pg_ctl start -o "-k \"$PGDATA\"" -l "$PGDATA/postgresql.log"
    fi

    # create link to migrations directory
    ln -s ../migrations/ migrations

    run-migrations

    echo "PostgreSQL is running using Unix socket in $PGDATA"
    echo "To connect, issue: psqlx"
    echo "To run migrations, use the 'run-migrations' command"

    cleanup() {
      echo "Stopping PostgreSQL and cleaning up..."
      pg_ctl stop
      rm -rf "$PGDATA"
      rm migrations
    }

    trap cleanup EXIT
  '';
}

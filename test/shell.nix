{ pkgs ? import <nixpkgs> {} }:

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

    if [ ! -d "$PGDATA" ]; then
      echo "Initializing PostgreSQL database..."
      initdb "$PGDATA" && echo "listen_addresses = ''" >> $PGDATA/postgresql.conf
      pg_ctl start -o "-k $PGDATA" -l "$PGDATA/postgresql.log"
      createdb $PGDATABASE
    else
      echo "Starting PostgreSQL..."
      pg_ctl start -o "-k $PGDATA" -l "$PGDATA/postgresql.log"
    fi

    echo "PostgreSQL is running using Unix socket in $PGDATA"
    echo "To run migrations, use the 'run-migrations' command"

    trap "pg_ctl stop" EXIT
  '';
}

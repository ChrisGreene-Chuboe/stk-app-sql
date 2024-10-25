{ pkgs ? import <nixpkgs> {} }:

# Prerequisites
  # install Nix package manager or use NixOS

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
    export PGUSERSU=postgres
    export PGUSER=stk_todo_superuser
    export PGDATABASE=stk_todo_db
    # next line is used by sqlx-cli
    export DATABASE_URL="postgresql://$PGUSER/$PGDATABASE?host=$PGDATA"
    alias psqlx="psql -h $PWD/pgdata/ -d $PGDATABASE"

    if [ ! -d "$PGDATA" ]; then
      echo "Initializing PostgreSQL database..."
      initdb -D "$PGDATA" --no-locale --encoding=UTF8 --username=$PGUSERSU && echo "listen_addresses = '''" >> $PGDATA/postgresql.conf
      pg_ctl start -o "-k \"$PGDATA\"" -l "$PGDATA/postgresql.log"
      createdb $PGDATABASE -h $PGDATA -U $PGUSERSU
      # Note: the following commands need to stay in sync with chuck-stack-nix => nixos => stk-todo-app.nix => services.postgresql.initscript
      psql -h $PGDATA -U $PGUSERSU -c "CREATE ROLE $PGUSER LOGIN CREATEROLE"
      psql -h $PGDATA -U $PGUSERSU -c "ALTER DATABASE $PGDATABASE OWNER TO $PGUSER"
    else
      echo "exiting with error - $PGDATA directory is not empty"
      exit 1
    fi

    # create link to migrations directory
    ln -s ../migrations/ migrations

    run-migrations

    echo ""
    echo "***************************************************"
    echo "PostgreSQL is running using Unix socket in $PGDATA"
    echo "Issue \"psqlx\" to connect to $PGDATABASE database"
    echo "To run migrations, use the 'run-migrations' command"
    echo "Note: this database will be destroyed on shell exit"
    echo "***************************************************"
    echo ""

    cleanup() {
      echo "Stopping PostgreSQL and cleaning up..."
      pg_ctl stop
      rm -rf "$PGDATA"
      rm migrations
    }

    trap cleanup EXIT
  '';
}

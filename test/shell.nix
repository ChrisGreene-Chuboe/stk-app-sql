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
    # note the PGUSER env var is used by psql directly
    export STK_SUPERUSER=stk_superuser
    export STK_USER=stk_login
    # note next line allows for migrations to execute
    export PGUSER=$STK_SUPERUSER
    export PGDATABASE=stk_db
    # note next line is used by sqlx-cli
    export DATABASE_URL="postgresql://$STK_SUPERUSER/$PGDATABASE?host=$PGDATA"

    if [ ! -d "$PGDATA" ]; then
      echo "Initializing PostgreSQL database..."
      initdb -D "$PGDATA" --no-locale --encoding=UTF8 --username=$PGUSERSU && echo "listen_addresses = '''" >> $PGDATA/postgresql.conf
      pg_ctl start -o "-k \"$PGDATA\"" -l "$PGDATA/postgresql.log"
      createdb $PGDATABASE -h $PGDATA -U $PGUSERSU
      # Note: the following commands need to stay in sync with chuck-stack-nix => nixos => stk-todo-app.nix => services.postgresql.initscript
      psql -h $PGDATA -U $PGUSERSU -c "CREATE ROLE $STK_SUPERUSER LOGIN CREATEROLE"
      psql -h $PGDATA -U $PGUSERSU -c "COMMENT ON ROLE $STK_SUPERUSER IS 'superuser role to administer the $PGDATABASE';"
      psql -h $PGDATA -U $PGUSERSU -c "ALTER DATABASE $PGDATABASE OWNER TO $STK_SUPERUSER"
    else
      echo "exiting with error - $PGDATA directory is not empty"
      exit 1
    fi

    # create link to migrations directory
    ln -s ../migrations/ migrations

    run-migrations

    # note next line sets database user to powerless user
    export PGUSER=$STK_USER
    # note next line used by aicaht and llm-tool to connect to db
    export AICHAT_PG_HOST="-h $PGDATA -d $PGDATABASE"
    export AICHAT_PG_ROLE="stk_api_role" # hard coded as default
    export PSQLRC="$PWD"/.psqlrc
    alias psqlx="psql $AICHAT_PG_HOST"

    pg_dump -U stk_superuser $AICHAT_PG_HOST --schema-only -n api > schema-api.sql
    sed -i '/^--/d' schema-api.sql
    sed -i '/^GRANT/d' schema-api.sql
    sed -i '/^ALTER/d' schema-api.sql

    echo "---- the following represent all enum values ----" > schema-enum.sql
    echo "" >> schema-enum.sql
    echo "--select * from api.enum_value" >> schema-enum.sql
    psql -U stk_superuser $AICHAT_PG_HOST -c "select * from api.enum_value" >> schema-enum.sql
    
    echo "---- the following represent all private table defaults ----" > schema-private.sql
    echo "---- we are includes these values so that you can see the default values for the tables behind the api views ----" >> schema-private.sql
    echo "---- when inserting records, to do set colums with default values unless the default is not desired ----" >> schema-private.sql
    echo "" >> schema-private.sql
    pg_dump -U stk_superuser $AICHAT_PG_HOST --schema-only -n private --table='stk*' >> schema-private.sql
    sed -i '/^--/d' schema-private.sql
    sed -i '/^GRANT/d' schema-private.sql
    sed -i '/^ALTER/d' schema-private.sql
    sed -i '/^CREATE TRIGGER/d' schema-private.sql
    sed -i '/ADD CONSTRAINT/d' schema-private.sql

    STK_DOCS=chuckstack.github.io
    git clone https://github.com/chuckstack/$STK_DOCS

    alias aix="aichat -r %functions% -f schema-api.sql -f schema-enum.sql -f schema-private.sql"
    alias aix-conv="aichat -r %functions% -f schema-api.sql -f schema-enum.sql -f schema-private.sql -f $STK_DOCS/src-ls/postgres-conventions.md"

    echo ""
    echo "******************************************************"
    echo "PostgreSQL is running using Unix socket in $PGDATA"
    echo "Issue \"psqlx\" to connect to $PGDATABASE database"
    echo "To run migrations, use the 'run-migrations' command"
    echo "Note: PGUSER = $STK_USER demonstrating user login with no abilities"
    echo "Note: AICHAT_PG_ROLE sets the desired role for both psqlx and aicaht - see impersonation"
    echo "      export AICHAT_PG_ROLE=stk_api_role #default"
    echo "      export AICHAT_PG_ROLE=stk_private_role"
    echo "      psqlx: show role; to see your current role"
    echo "Note: aix - an alias including the current db schema"
    echo "Note: aix-conv - an alias including aix + website conventions"
    echo "Note: this database will be destroyed on shell exit"
    echo "******************************************************"
    echo ""

    cleanup() {
      echo "Stopping PostgreSQL and cleaning up..."
      pg_ctl stop
      rm -rf "$PGDATA"
      rm -rf "$STK_DOCS"
      rm migrations
      rm schema-api.sql
      rm schema-enum.sql
      rm schema-private.sql
      rm .psql_history
    }

    trap cleanup EXIT
  '';
}

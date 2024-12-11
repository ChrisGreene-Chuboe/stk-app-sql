{ pkgs ? import <nixpkgs> {} }:

# Prerequisites
  # install Nix package manager or use NixOS

# The purpose of this shell is to:
  # install postgresql
  # install sqlx-cli
  # create a local psql cluster (in this directory)
  # run the migrations and report success or failure
  # allow you to view and interact with the results using 'psql'
  # allow you to use the database with aichat function calling
  # destroy all artifacts upon leaving the shell

let
  # Function to run migrations
  runMigrations = pkgs.writeShellScriptBin "run-migrations" ''
    echo "Running migrations..."
    sqlx migrate run
  '';

  # Function to override usql to psql
  usql-override = pkgs.writeShellScriptBin "usql" ''
      #!${pkgs.bash}/bin/bash
      exec ${pkgs.postgresql}/bin/psql "$@"
  '';

in pkgs.mkShell {
  buildInputs = [
    pkgs.postgresql
    pkgs.sqlx-cli
    runMigrations
    usql-override
  ];

  shellHook = ''

    # get current directory for cleanup reference
    export STK_PWD_SHELL=$PWD

    export PGHOST="$PWD/pgdata"
    # note next line needed for pg_ctl
    export PGDATA="$PGHOST"
    export PGUSERSU=postgres
    export STK_SUPERUSER=stk_superuser
    export STK_USER=stk_login
    # note next line allows for migrations to execute
    # note the PGUSER env var is used by psql directly
    export PGUSER=$STK_SUPERUSER
    export PGDATABASE=stk_db
    # note next line is used by sqlx-cli
    export DATABASE_URL="postgresql://$STK_SUPERUSER/$PGDATABASE?host=$PGHOST"

    if [ ! -d "$PGHOST" ]; then
      echo "Initializing PostgreSQL database..."
      initdb --no-locale --encoding=UTF8 --username=$PGUSERSU && echo "listen_addresses = '''" >> $PGHOST/postgresql.conf
      pg_ctl start -o "-k \"$PGHOST\"" -l "$PGHOST/postgresql.log"
      createdb $PGDATABASE -h $PGHOST -U $PGUSERSU
      # Note: the following commands need to stay in sync with chuck-stack-nix => nixos => stk-todo-app.nix => services.postgresql.initscript
      psql -U $PGUSERSU -c "CREATE ROLE $STK_SUPERUSER LOGIN CREATEROLE"
      psql -U $PGUSERSU -c "COMMENT ON ROLE $STK_SUPERUSER IS 'superuser role to administer the $PGDATABASE';"
      psql -U $PGUSERSU -c "ALTER DATABASE $PGDATABASE OWNER TO $STK_SUPERUSER"
    else
      echo "exiting with error - $PGHOST directory is not empty"
      exit 1
    fi

    # create link to migrations directory
    ln -s ../migrations/ migrations

    run-migrations

    # note next line used by aicaht and llm-tool to connect to db
    export USQL_DSN="" # needed for aichat tool => execute sql
    # note next lines (STK_PG_ROLE and STK_PG_SESSION) are used in .psqlrc to set values when running commands
    export STK_PG_ROLE="stk_api_role" # hard coded as default
    export STK_PG_SESSION="'{\"psql_user\": \"$STK_USER\"}'" # hard coded as default
    # note next line tells psql where to look for settings
    export PSQLRC="$PWD"/.psqlrc

    mkdir -p delme/

    V_SCHEMA_DETAILS="schema-details/"
    mkdir -p "$V_SCHEMA_DETAILS"

    V_SCHEMA_DETAILS_API="$V_SCHEMA_DETAILS/schema-api.sql"
    V_SCHEMA_DETAILS_PRIVATE="$V_SCHEMA_DETAILS/schema-private.sql"
    V_SCHEMA_DETAILS_ENUM="$V_SCHEMA_DETAILS/schema-enum.txt"

    pg_dump --schema-only -n api > $V_SCHEMA_DETAILS_API
    sed -i '/^--/d' $V_SCHEMA_DETAILS_API
    sed -i '/^GRANT/d' $V_SCHEMA_DETAILS_API
    sed -i '/^ALTER/d' $V_SCHEMA_DETAILS_API

    echo "---- the following represent all enum values ----" > $V_SCHEMA_DETAILS_PRIVATE
    echo "" >> $V_SCHEMA_DETAILS_PRIVATE
    echo "--select * from api.enum_value" >> $V_SCHEMA_DETAILS_PRIVATE
    psql -c "select * from api.enum_value" >> $V_SCHEMA_DETAILS_PRIVATE
    
    echo "---- the following represent all private table defaults ----" > $V_SCHEMA_DETAILS_PRIVATE
    echo "---- we are includes these values so that you can see the default values for the tables behind the api views ----" >> $V_SCHEMA_DETAILS_PRIVATE
    echo "---- when inserting records, to do set colums with default values unless the default is not desired ----" >> $V_SCHEMA_DETAILS_PRIVATE
    echo "" >> $V_SCHEMA_DETAILS_PRIVATE
    pg_dump  --schema-only -n private --table='stk*' >> $V_SCHEMA_DETAILS_PRIVATE
    sed -i '/^--/d' $V_SCHEMA_DETAILS_PRIVATE
    sed -i '/^GRANT/d' $V_SCHEMA_DETAILS_PRIVATE
    sed -i '/^ALTER/d' $V_SCHEMA_DETAILS_PRIVATE
    sed -i '/^CREATE TRIGGER/d' $V_SCHEMA_DETAILS_PRIVATE
    sed -i '/ADD CONSTRAINT/d' $V_SCHEMA_DETAILS_PRIVATE

    STK_DOCS=chuckstack.github.io
    #git clone https://github.com/chuckstack/$STK_DOCS

    export f="-r %functions%"
    alias aix="aichat -f $V_SCHEMA_DETAILS "
    alias aix-conv-detail="aichat -f $V_SCHEMA_DETAILS -f $STK_DOCS/src-ls/postgres-convention/"
    alias aix-conv-sum="aichat -f $V_SCHEMA_DETAILS -f $STK_DOCS/src-ls/postgres-conventions.md"

    # note next line sets aichat environment var
    export AICHAT_ROLES_DIR="chuckstack.github.io/src-ls/roles/"
    
    # note next line sets database user to powerless user
    export PGUSER=$STK_USER

    echo ""
    echo "******************************************************"
    echo "PostgreSQL is running using Unix socket in $PGHOST"
    echo "Issue \"psql\" to connect to $PGDATABASE database - note env vars set accordingly"
    echo "To run migrations, use the 'run-migrations' command"
    echo "Note: PGUSER = $STK_USER demonstrating user login with no abilities"
    echo "Note: STK_PG_ROLE sets the desired role for both psql and aicaht - see impersonation"
    echo "      export STK_PG_ROLE=stk_api_role #default"
    echo "      export STK_PG_ROLE=stk_private_role"
    echo "      psql: show role; to see your current role"
    echo "Note: aix - an alias including the current db schema summary"
    echo "      aix-conv-detail - an alias including aix + website all psql conventions"
    echo "      aix-conv-sum - an alias including aix + website summary of psql conventions"
    echo "      use \$f to execute these calls with function calling"
    echo "      aix \$f -- show me all stk_actors"
    echo "Documentation:"
    echo "      bat chuckstack.github.io/src-ls/postgres-conventions.md"
    echo "      bat chuckstack.github.io/src-ls/postgres-convention/*"
    echo "Note: this database and all artifacts will be destroyed on shell exit"
    echo "******************************************************"
    echo ""

    cleanup() {
      echo "Stopping PostgreSQL and cleaning up..."
      cd $STK_PWD_SHELL
      pg_ctl stop
      rm -rf "$PGHOST"
      rm -rf "$STK_DOCS"
      rm -rf delme/
      rm migrations
      rm -rf "$V_SCHEMA_DETAILS"
      rm .psql_history
    }

    trap cleanup EXIT
  '';
}

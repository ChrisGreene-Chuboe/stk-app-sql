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
    cd "$STK_TEST_DIR"
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
    pkgs.postgrest
    pkgs.bat
    #pkgs.nushell
    #pkgs.aichat
    #pkgs.git
    runMigrations
    usql-override
  ];

  shellHook = ''

    # copy over psql pg_jsonschema extension files into nix directories
    # NOTE: this is bad nix form - supposed to create a derivation instead; however, this is an easy fix
    # uncomment if needed
    #sudo cp ./pg_extension/16/pg_jsonschema.so ${pkgs.postgresql}/lib/
    #sudo cp ./pg_extension/16/pg_jsonschema.control ${pkgs.postgresql}/share/postgresql/extension/
    #sudo cp ./pg_extension/16/pg_jsonschema--0.3.3.sql ${pkgs.postgresql}/share/postgresql/extension/
    #sudo chmod 444 ${pkgs.postgresql}/lib/pg_jsonschema.so
    #sudo chmod 444 ${pkgs.postgresql}/share/postgresql/extension/pg_jsonschema.control
    #sudo chmod 444 ${pkgs.postgresql}/share/postgresql/extension/pg_jsonschema--0.3.3.sql

    # get current directory for cleanup reference
    export STK_PWD_SHELL=$PWD

    # create unique temporary directory for this test session
    export STK_TEST_DIR="/tmp/stk-test-$$"
    mkdir -p "$STK_TEST_DIR"
    export PGHOST="$STK_TEST_DIR/pgdata"
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
    # clear variable just in case it existed previously
    export STK_PG_ROLE="" # hard coded as default

    if [ ! -d "$PGHOST" ]; then
      echo "Initializing PostgreSQL database..."
      initdb --no-locale --encoding=UTF8 --username=$PGUSERSU && echo "listen_addresses = '''" >> $PGHOST/postgresql.conf
      pg_ctl start -o "-k \"$PGHOST\"" -l "$PGHOST/postgresql.log"
      createdb $PGDATABASE -h $PGHOST -U $PGUSERSU
      # Note: the following commands need to stay in sync with chuck-stack-nix => nixos => stk-todo-app.nix => services.postgresql.initscript
      psql -U $PGUSERSU -c "CREATE EXTENSION pg_jsonschema" # must be run as superuser/postgres - NOT moved to chuck-stack-nix yet
      psql -U $PGUSERSU -c "CREATE ROLE $STK_SUPERUSER LOGIN CREATEROLE"
      psql -U $PGUSERSU -c "COMMENT ON ROLE $STK_SUPERUSER IS 'superuser role to administer the $PGDATABASE';"
      psql -U $PGUSERSU -c "ALTER DATABASE $PGDATABASE OWNER TO $STK_SUPERUSER"
    else
      echo "exiting with error - $PGHOST directory is not empty"
      exit 1
    fi

    # create link to migrations directory in test directory
    ln -s "$STK_PWD_SHELL/../migrations/" "$STK_TEST_DIR/migrations"

    run-migrations

    # note next line used by aicaht and llm-tool to connect to db
    export USQL_DSN="" # needed for aichat tool => execute sql
    # note next lines (STK_PG_ROLE and STK_PG_SESSION) are used in .psqlrc to set values when running commands
    export STK_PG_ROLE="stk_api_role" # hard coded as default
    export STK_PG_SESSION="'{\"psql_user\": \"$STK_USER\"}'" # hard coded as default
    # note next line tells psql where to look for settings
    export PSQLRC="$PWD"/.psqlrc
    # set psql history file to temp directory
    export HISTFILE="$STK_TEST_DIR/.psql_history"

    mkdir -p "$STK_TEST_DIR/delme/"

    V_SCHEMA_DETAILS="$STK_TEST_DIR/schema-details/"
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

    # Get chuck-stack to gain access to roles, conventions and best practices
    # Maintained in /opt for this script so that we can
      # create rags of the docs
      # preserve file paths in the rag definitions
      # prevent from needing to constantly delete and clone this repo
    STK_DOCS=chuckstack.github.io
    STK_DOCS_PATH=/opt/$STK_DOCS
    if [ ! -d "$STK_DOCS_PATH" ]; then
      sudo git clone https://github.com/chuckstack/$STK_DOCS /opt/$STK_DOCS
    fi

    export f="-r %functions%"
    alias aix="aichat -f $V_SCHEMA_DETAILS "
    alias aix-conv-detail="aichat -f $V_SCHEMA_DETAILS -f $STK_DOCS_PATH/src-ls/postgres-convention/"
    alias aix-conv-sum="aichat -f $V_SCHEMA_DETAILS -f $STK_DOCS_PATH/src-ls/postgres-conventions.md"

    # note next line sets aichat environment var
    export AICHAT_ROLES_DIR="$STK_DOCS_PATH/src-ls/roles/"
    
    # note next line sets database user to powerless user
    export PGUSER=$STK_USER

    # create postgrest config file
    echo ""
    echo "Start PostgREST config"
    mkdir -p "$STK_TEST_DIR/postgrest-config/"
    export STK_POSTGREST_CONFIG="$STK_TEST_DIR/postgrest-config/postgrest.conf"
    export STK_POSTGREST_CURL="$STK_TEST_DIR/postgrest-config/curl.sh"
    echo STK_POSTGREST_CONFIG = $STK_POSTGREST_CONFIG
    echo "db-uri = \"postgres://postgrest@/$PGDATABASE?host=$PGHOST\"" | tee $STK_POSTGREST_CONFIG
    echo 'db-schemas = "api"' | tee -a $STK_POSTGREST_CONFIG
    echo 'db-anon-role = "stk_api_role"' | tee -a $STK_POSTGREST_CONFIG
    echo 'server-port = 3001' | tee -a $STK_POSTGREST_CONFIG
cat << EOF > $STK_POSTGREST_CURL
curl -X POST \
  'http://localhost:3001/rpc/stk_form_post_fn' \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "John Doe",
    "email": "john@example.com",
    "message": "Hello, this is a test form submission"
  }'
EOF
    echo "End PostgREST config"
    echo ""

    # clear variables no longer needed after migration
    #export DATABASE_URL=""

    echo ""
    echo "******************************************************"
    echo "Test environment created in: $STK_TEST_DIR"
    echo "To navigate to test directory: cd \$STK_TEST_DIR"
    echo "PostgreSQL is running using Unix socket in $PGHOST"
    echo "Issue \"psql\" to connect to $PGDATABASE database - note env vars set accordingly"
    echo "To run migrations, use the 'run-migrations' command"
    echo "Note: PGUSER = $STK_USER demonstrating user login with no abilities"
    echo "Note: STK_PG_ROLE sets the desired role for both psql and aicaht - see impersonation"
    echo "      export STK_PG_ROLE=stk_api_role #default"
    echo "      export STK_PG_ROLE=stk_private_role"
    echo "      psql => show role; --to see your current role"
    echo "Note: You can simply insert records."
    echo "      Use psql to execute the following example:"
    echo "      insert into api.stk_request (name) values ('test');"
    echo "      select * from api.stk_request;"
    echo "      Note that all the normal created, updated, created_by, ... columns are populated"
    echo "Note: The following aichat aliases depend on $STK_DOCS_PATH"
    echo "      Make sure you have pulled a current version of $STK_DOCS_PATH"
    echo "      aichat function calling depends on https://github.com/sigoden/llm-functions/ being configured"
    echo "      aix - an aichat alias including the current db schema summary"
    echo "      aix-conv-detail - an aichat alias including aix + website all psql conventions"
    echo "      aix-conv-sum - an aichat alias including aix + website summary of psql conventions"
    echo "      use \$f to execute these calls with function calling"
    echo "      Examples:"
    echo "      aix \$f -- show me all api.stk_actors #use most basic function where \$f = $f"
    echo "      aichat --role api-crud -- show me all stk_actors #use role from $STK_DOCS_PATH/src-ls/roles/"
    echo "Note: to make/test stk_superuser DDL changes:"
    echo "      export PGUSER=stk_superuser"
    echo "      export STK_PG_ROLE=stk_superuser"
    echo "      psql"
    echo "Note: PostgREST detals:"
    echo "      config file => $STK_POSTGREST_CONFIG"
    echo "      start PostgREST => postgrest $STK_POSTGREST_CONFIG"
    echo "      example curl => sh $STK_POSTGREST_CURL"
    echo "Documentation:"
    echo "      bat $STK_DOCS_PATH/src-ls/postgres-conventions.md"
    echo "      bat $STK_DOCS_PATH/src-ls/postgres-convention/*"
    echo "Note: this database and all artifacts will be destroyed on shell exit"
    echo "******************************************************"
    echo ""



    cleanup() {
      echo "Stopping PostgreSQL and cleaning up..."
      cd $STK_PWD_SHELL
      pg_ctl stop
      echo "Removing temporary test directory: $STK_TEST_DIR"
      rm -rf "$STK_TEST_DIR"
    }

    trap cleanup EXIT
  '';
}

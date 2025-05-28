{ pkgs ? import <nixpkgs> {} }:

# Prerequisites
  # install Nix package manager or use NixOS

# The purpose of this shell is to:
  # create a persistent local chuck-stack deployment in /opt/
  # install postgresql
  # install sqlx-cli
  # create a local psql cluster (persistent across shell sessions)
  # run the migrations and report success or failure
  # allow you to view and interact with the results using 'psql'
  # allow you to use the database with aichat function calling
  # stop postgresql when leaving the shell (data persists)

let
  # Create pg_jsonschema extension package
  pg_jsonschema_ext = pkgs.stdenv.mkDerivation {
    name = "pg_jsonschema-extension";
    src = ./pg_extension/17;
    installPhase = ''
      mkdir -p $out/lib $out/share/postgresql/extension
      cp pg_jsonschema.so $out/lib/
      cp pg_jsonschema.control $out/share/postgresql/extension/
      cp pg_jsonschema--0.3.3.sql $out/share/postgresql/extension/
    '';
  };

  # Combine PostgreSQL with extension using buildEnv (no rebuild)
  postgresql-with-jsonschema = pkgs.buildEnv {
    name = "postgresql-with-jsonschema";
    paths = [ pkgs.postgresql pg_jsonschema_ext ];
  };

  # Function to run migrations
  runMigrations = pkgs.writeShellScriptBin "run-migrations" ''
    echo "Running migrations..."
    cd "$STK_TEST_DIR"
    sqlx migrate run
  '';

  # Function to override usql to psql
  usql-override = pkgs.writeShellScriptBin "usql" ''
      #!${pkgs.bash}/bin/bash
      exec ${postgresql-with-jsonschema}/bin/psql "$@"
  '';

in pkgs.mkShell {
  buildInputs = [
    postgresql-with-jsonschema
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

    # pg_jsonschema extension is now included in the postgresql-with-jsonschema derivation
    # No manual copying needed - extension files are built into the package

    # Determine instance name
    if [ -n "$STK_INSTANCE_NAME" ]; then
      INSTANCE_NAME="$STK_INSTANCE_NAME"
    else
      INSTANCE_NAME="default-$(date +%Y%m%d-%H%M%S)"
    fi

    export STK_LOCAL_DIR="/opt/stk-local-$INSTANCE_NAME"

    # Check if this is being run from deploy-local template directory
    if [[ "$PWD" =~ deploy-local$ ]]; then
      echo "Creating new chuck-stack instance: $INSTANCE_NAME"
      
      # Create instance directory with proper permissions
      sudo mkdir -p "$STK_LOCAL_DIR"
      sudo chown $USER:$USER "$STK_LOCAL_DIR"
      
      # Copy template files to instance directory
      cp shell.nix "$STK_LOCAL_DIR/"
      cp -r pg_extension/ "$STK_LOCAL_DIR/"
      cp -r ../migrations/ "$STK_LOCAL_DIR/"
      
      echo ""
      echo "******************************************************"
      echo "Instance created in: $STK_LOCAL_DIR"
      echo "To start working with this instance:"
      echo "  cd $STK_LOCAL_DIR"
      echo "  nix-shell"
      echo "******************************************************"
      echo ""
      exit 0
    fi

    # If we reach here, we're running from an instance directory
    export STK_LOCAL_DIR="$PWD"
    export PGHOST="$STK_LOCAL_DIR/pgdata"
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
      echo "Initializing new PostgreSQL database in: $STK_LOCAL_DIR"
      ${postgresql-with-jsonschema}/bin/initdb --no-locale --encoding=UTF8 --username=$PGUSERSU && echo "listen_addresses = '''" >> $PGHOST/postgresql.conf
      ${postgresql-with-jsonschema}/bin/pg_ctl start -o "-k \"$PGHOST\"" -l "$PGHOST/postgresql.log"
      ${postgresql-with-jsonschema}/bin/createdb $PGDATABASE -h $PGHOST -U $PGUSERSU
      # Note: the following commands need to stay in sync with chuck-stack-nix => nixos => stk-todo-app.nix => services.postgresql.initscript
      ${postgresql-with-jsonschema}/bin/psql -U $PGUSERSU -c "CREATE EXTENSION pg_jsonschema" # must be run as superuser/postgres - NOT moved to chuck-stack-nix yet
      ${postgresql-with-jsonschema}/bin/psql -U $PGUSERSU -c "CREATE ROLE $STK_SUPERUSER LOGIN CREATEROLE"
      ${postgresql-with-jsonschema}/bin/psql -U $PGUSERSU -c "COMMENT ON ROLE $STK_SUPERUSER IS 'superuser role to administer the $PGDATABASE';"
      ${postgresql-with-jsonschema}/bin/psql -U $PGUSERSU -c "ALTER DATABASE $PGDATABASE OWNER TO $STK_SUPERUSER"
    else
      echo "Restarting existing PostgreSQL database in: $STK_LOCAL_DIR"
      ${postgresql-with-jsonschema}/bin/pg_ctl start -o "-k \"$PGHOST\"" -l "$PGHOST/postgresql.log"
      # Verify connection
      ${postgresql-with-jsonschema}/bin/psql -U $PGUSERSU -c "SELECT 1" > /dev/null || { echo "Failed to connect to existing database"; exit 1; }
    fi

    # migrations directory already copied to instance directory
    # no symlink needed

    run-migrations

    # note next line used by aicaht and llm-tool to connect to db
    export USQL_DSN="" # needed for aichat tool => execute sql
    # note next lines (STK_PG_ROLE and STK_PG_SESSION) are used in .psqlrc to set values when running commands
    export STK_PG_ROLE="stk_api_role" # hard coded as default
    export STK_PG_SESSION="'{\"psql_user\": \"$STK_USER\"}'" # hard coded as default
    # note next line tells psql where to look for settings
    export PSQLRC="$PWD"/.psqlrc
    # set psql history file to instance directory
    export HISTFILE="$STK_LOCAL_DIR/.psql_history"

    mkdir -p "$STK_LOCAL_DIR/delme/"

    V_SCHEMA_DETAILS="$STK_LOCAL_DIR/schema-details/"
    mkdir -p "$V_SCHEMA_DETAILS"

    V_SCHEMA_DETAILS_API="$V_SCHEMA_DETAILS/schema-api.sql"
    V_SCHEMA_DETAILS_PRIVATE="$V_SCHEMA_DETAILS/schema-private.sql"
    V_SCHEMA_DETAILS_ENUM="$V_SCHEMA_DETAILS/schema-enum.txt"

    ${postgresql-with-jsonschema}/bin/pg_dump --schema-only -n api > $V_SCHEMA_DETAILS_API
    sed -i '/^--/d' $V_SCHEMA_DETAILS_API
    sed -i '/^GRANT/d' $V_SCHEMA_DETAILS_API
    sed -i '/^ALTER/d' $V_SCHEMA_DETAILS_API

    echo "---- the following represent all enum values ----" > $V_SCHEMA_DETAILS_PRIVATE
    echo "" >> $V_SCHEMA_DETAILS_PRIVATE
    echo "--select * from api.enum_value" >> $V_SCHEMA_DETAILS_PRIVATE
    ${postgresql-with-jsonschema}/bin/psql -c "select * from api.enum_value" >> $V_SCHEMA_DETAILS_PRIVATE
    
    echo "---- the following represent all private table defaults ----" > $V_SCHEMA_DETAILS_PRIVATE
    echo "---- we are includes these values so that you can see the default values for the tables behind the api views ----" >> $V_SCHEMA_DETAILS_PRIVATE
    echo "---- when inserting records, to do set colums with default values unless the default is not desired ----" >> $V_SCHEMA_DETAILS_PRIVATE
    echo "" >> $V_SCHEMA_DETAILS_PRIVATE
    ${postgresql-with-jsonschema}/bin/pg_dump  --schema-only -n private --table='stk*' >> $V_SCHEMA_DETAILS_PRIVATE
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
    mkdir -p "$STK_LOCAL_DIR/postgrest-config/"
    export STK_POSTGREST_CONFIG="$STK_LOCAL_DIR/postgrest-config/postgrest.conf"
    export STK_POSTGREST_CURL="$STK_LOCAL_DIR/postgrest-config/curl.sh"
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
    echo "Chuck-stack local deployment ready in: $STK_LOCAL_DIR"
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
    echo "Note: PostgREST details:"
    echo "      config file => $STK_POSTGREST_CONFIG"
    echo "      start PostgREST => postgrest $STK_POSTGREST_CONFIG"
    echo "      example curl => sh $STK_POSTGREST_CURL"
    echo "      NOTE: If running multiple instances, change 'server-port = 3001' in config to avoid conflicts"
    echo "Documentation:"
    echo "      bat $STK_DOCS_PATH/src-ls/postgres-conventions.md"
    echo "      bat $STK_DOCS_PATH/src-ls/postgres-convention/*"
    echo "Note: PostgreSQL will stop on shell exit, but data persists for next restart"
    echo "Note: To remove this instance: sudo rm -rf $STK_LOCAL_DIR"
    echo "******************************************************"
    echo ""



    cleanup() {
      echo "Stopping PostgreSQL..."
      cd "$STK_LOCAL_DIR"
      ${postgresql-with-jsonschema}/bin/pg_ctl stop
      echo "PostgreSQL stopped. Data preserved in: $STK_LOCAL_DIR"
    }

    trap cleanup EXIT
  '';
}

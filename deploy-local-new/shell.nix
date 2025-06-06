{ pkgs ? import <nixpkgs> {} }:

# Prerequisites
  # install Nix package manager or use NixOS

# The purpose of this shell is to:
  # install postgresql
  # install chuck-stack-nushell-psql-migration
  # create a persistent local psql cluster (in /opt/)
  # run the migrations and report success or failure
  # allow you to view and interact with the results using 'psql'
  # allow you to use the database with aichat function calling
  # stop postgresql when leaving the shell (data persists)

let
  # Fetch chuck-stack-nushell-psql-migration source
  migrationUtilSrc = pkgs.fetchgit {
    url = "https://github.com/chuckstack/chuck-stack-nushell-psql-migration";
    rev = "aeb2a5fe185e09ba46d1422a01d8caf4715bc16e";  # updated roadmap with hash comparison
    sha256 = "sha256-aiUikB6o/GdBoiREWe7BSpLX2tlyKfQN26Z5QhJRBK8=";
  };

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

  # Function to start deployment environment (assumes all setup is done by shell.nix)
  startDeploy = pkgs.writeShellScriptBin "start-deploy" ''
    # Run the nushell start-deploy script
    cd "$STK_DEPLOY_DIR"
    ${pkgs.nushell}/bin/nu "./start-deploy.nu"
  '';

  # Function to stop deployment environment (but preserve data)
  stopDeploy = pkgs.writeShellScriptBin "stop-deploy" ''
    ${pkgs.nushell}/bin/nu "./stop-deploy.nu"
  '';

  # Function to override usql to psql
  usql-override = pkgs.writeShellScriptBin "usql" ''
      #!${pkgs.bash}/bin/bash
      exec ${postgresql-with-jsonschema}/bin/psql "$@"
  '';

in pkgs.mkShell {
  buildInputs = [
    postgresql-with-jsonschema
    pkgs.nushell
    pkgs.postgrest
    pkgs.bat
    #pkgs.aichat
    #pkgs.git
    startDeploy
    stopDeploy
    usql-override
  ];

  shellHook = ''
    # Determine instance name
    if [ -n "$STK_INSTANCE_NAME" ]; then
      INSTANCE_NAME="$STK_INSTANCE_NAME"
    else
      INSTANCE_NAME="default-$(date +%Y%m%d-%H%M%S)"
    fi

    # Setup environment variables for chuck-stack deployment environment
    export STK_PWD_SHELL=$PWD
    export STK_DEPLOY_DIR="/opt/stk-local-$INSTANCE_NAME"
    export PGHOST="$STK_DEPLOY_DIR/pgdata"
    export PGDATA="$PGHOST"
    export PGUSERSU=postgres
    export STK_SUPERUSER=stk_superuser
    export STK_USER=stk_login
    export PGUSER=$STK_SUPERUSER
    export PGDATABASE=stk_db
    export STK_PG_ROLE="stk_api_role"
    export STK_PG_SESSION="'{\"psql_user\": \"$STK_USER\"}'"
    export PSQLRC="$STK_DEPLOY_DIR"/.psqlrc
    export HISTFILE="$STK_DEPLOY_DIR/.psql_history"
    export USQL_DSN=""
    export f="-r %functions%"
    
    # Documentation paths
    export STK_DOCS_PATH="/opt/chuckstack.github.io"
    export AICHAT_ROLES_DIR="$STK_DOCS_PATH/src-ls/roles/"
    
    # aichat aliases (will be set up after environment starts)
    alias aix="aichat -f $STK_DEPLOY_DIR/schema-details/ "
    alias aix-conv-detail="aichat -f $STK_DEPLOY_DIR/schema-details/ -f $STK_DOCS_PATH/src-ls/postgres-convention/"
    alias aix-conv-sum="aichat -f $STK_DEPLOY_DIR/schema-details/ -f $STK_DOCS_PATH/src-ls/postgres-conventions.md"

    # Check if this is being run from deploy-local-new template directory
    if [[ "$PWD" =~ deploy-local-new$ ]]; then
      echo "Creating new chuck-stack deployment instance: $INSTANCE_NAME"
      
      # Create instance directory with proper permissions
      sudo mkdir -p "$STK_DEPLOY_DIR"
      sudo chown $USER:$USER "$STK_DEPLOY_DIR"
      
      # Pre-create required subdirectories with proper permissions
      mkdir -p "$STK_DEPLOY_DIR/pgdata"
      mkdir -p "$STK_DEPLOY_DIR/delme"
      mkdir -p "$STK_DEPLOY_DIR/schema-details"
      mkdir -p "$STK_DEPLOY_DIR/postgrest-config"
      
      # Copy template files to instance directory
      cp shell.nix "$STK_DEPLOY_DIR/"
      cp start-deploy.nu "$STK_DEPLOY_DIR/"
      cp stop-deploy.nu "$STK_DEPLOY_DIR/"
      cp .psqlrc "$STK_DEPLOY_DIR/" 2>/dev/null || echo "Note: .psqlrc not found, will be created"
      cp .psqlrc-nu "$STK_DEPLOY_DIR/" 2>/dev/null || echo "Note: .psqlrc-nu not found, will be created"
      cp -r pg_extension/ "$STK_DEPLOY_DIR/" 2>/dev/null || echo "Note: pg_extension not found"
      cp -r ../migrations/ "$STK_DEPLOY_DIR/" 2>/dev/null || echo "Note: ../migrations not found"
      cp -r ../modules/ "$STK_DEPLOY_DIR/" 2>/dev/null || echo "Note: ../modules not found"
      
      echo ""
      echo "******************************************************"
      echo "Instance created in: $STK_DEPLOY_DIR"
      echo "To start working with this instance:"
      echo "  cd $STK_DEPLOY_DIR"
      echo "  nix-shell"
      echo "******************************************************"
      echo ""
      exit 0
    fi

    # If we reach here, we're running from an instance directory
    export STK_DEPLOY_DIR="$PWD"
    # Update PGHOST to use current directory, not the template-time variable
    export PGHOST="$PWD/pgdata"
    export PGDATA="$PGHOST"

    # Setup migration utility in deployment directory (if not already done)
    if [ ! -d "$STK_DEPLOY_DIR/tools/migration" ]; then
      mkdir -p "$STK_DEPLOY_DIR/tools/migration"
      cp -r ${migrationUtilSrc}/src/* "$STK_DEPLOY_DIR/tools/migration/"
    fi

    # Start the deployment environment using nushell
    start-deploy

    # Switch to deployment directory and powerless user for regular operations
    cd "$STK_DEPLOY_DIR"
    export PGUSER=$STK_USER

    # Setup stop trap (preserve data, just stop services)
    cleanup() {
      stop-deploy
    }
    trap cleanup EXIT
  '';
}
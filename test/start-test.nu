#!/usr/bin/env nu

# Start test environment - handles database setup, migrations, and configuration
def main [] {
    print $"(ansi green)Starting chuck-stack test environment...(ansi reset)"
    
    # Migration utility will be set up by shell script before calling this
    # We'll import it after setup_directories creates the structure
    
    # Setup directories
    setup_directories
    
    # Setup PostgreSQL if needed
    setup_postgresql
    
    # Run migrations
    run_migrations
    
    # Generate schema details
    generate_schema_details
    
    # Setup PostgREST configuration
    setup_postgrest
    
    # Setup chuck-stack documentation access
    setup_documentation
    
    print $"(ansi green)Test environment ready!(ansi reset)"
    show_usage_info
}

# Setup required directories
def setup_directories [] {
    print "Creating directories..."
    
    let dirs = [
        $env.STK_TEST_DIR
        $"($env.STK_TEST_DIR)/delme"
        $"($env.STK_TEST_DIR)/schema-details"
        $"($env.STK_TEST_DIR)/postgrest-config"
        $env.PGHOST
    ]
    
    for dir in $dirs {
        if not ($dir | path exists) {
            mkdir $dir
            print $"  Created: ($dir)"
        }
    }
    
    # Copy configuration files and modules to test directory
    print "Copying configuration files..."
    cp -f $"($env.STK_PWD_SHELL)/.psqlrc" $env.STK_TEST_DIR
    cp -f $"($env.STK_PWD_SHELL)/.psqlrc-nu" $env.STK_TEST_DIR
    print $"  Copied: .psqlrc and .psqlrc-nu"
    
    # Copy modules directory to make it accessible via ./modules
    print "Copying modules directory..."
    cp -rf $"($env.STK_PWD_SHELL)/../modules" $env.STK_TEST_DIR
    print $"  Copied: modules directory to ($env.STK_TEST_DIR)/modules"
    
    # Copy test files to test directory
    print "Copying test files..."
    glob $"($env.STK_PWD_SHELL)/test-*.nu" | each { |file| cp -f $file $env.STK_TEST_DIR }
    print $"  Copied: test files to ($env.STK_TEST_DIR)"
}

# Setup PostgreSQL cluster and database
def setup_postgresql [] {
    if not ($"($env.PGHOST)/postgresql.conf" | path exists) {
        print "Initializing PostgreSQL database..."
        
        # Initialize cluster
        try {
            ^initdb --no-locale --encoding=UTF8 --username=postgres $env.PGHOST
            $"listen_addresses = ''\n" | save --append $"($env.PGHOST)/postgresql.conf"
        } catch {
            print $"(ansi red)Failed to initialize PostgreSQL cluster(ansi reset)"
            exit 1
        }
        
        # Start PostgreSQL
        try {
            ^pg_ctl start -D $env.PGHOST -o $"-k \"($env.PGHOST)\"" -l $"($env.PGHOST)/postgresql.log"
        } catch {
            print $"(ansi red)Failed to start PostgreSQL(ansi reset)"
            exit 1
        }
        
        # Create database and users
        # Disable .psqlrc during initial setup since roles don't exist yet
        try {
            with-env {PSQLRC: "/dev/null"} {
                ^createdb $env.PGDATABASE -h $env.PGHOST -U postgres
                ^psql -U postgres -h $env.PGHOST -c "CREATE EXTENSION pg_jsonschema"
                ^psql -U postgres -h $env.PGHOST -c $"CREATE ROLE ($env.STK_SUPERUSER) LOGIN CREATEROLE"
                ^psql -U postgres -h $env.PGHOST -c $"COMMENT ON ROLE ($env.STK_SUPERUSER) IS 'superuser role to administer the ($env.PGDATABASE)';"
                ^psql -U postgres -h $env.PGHOST -c $"ALTER DATABASE ($env.PGDATABASE) OWNER TO ($env.STK_SUPERUSER)"
            }
        } catch {
            print $"(ansi red)Failed to setup database and users(ansi reset)"
            exit 1
        }
    } else {
        print $"(ansi red)Error: ($env.PGHOST) directory is not empty(ansi reset)"
        exit 1
    }
}

# Run database migrations using nushell migration utility
def run_migrations [] {
    print "Running database migrations..."
    
    # Verify migration utility is available
    if not ($"./tools/migration/mod.nu" | path exists) {
        print $"(ansi red)Error: Migration utility not found at ./tools/migration/mod.nu(ansi reset)"
        exit 1
    }
    
    # Note: Syntax fixes are now included in the upstream migration utility
    
    # Create symlink to migrations
    if not ($"($env.STK_TEST_DIR)/migrations" | path exists) {
        try {
            ^ln -s $"($env.STK_PWD_SHELL)/../migrations/" $"($env.STK_TEST_DIR)/migrations"
        } catch {
            print $"(ansi red)Failed to create migrations symlink(ansi reset)"
            exit 1
        }
    }
    
    # Run migrations using dynamic nu command to avoid parse-time issues
    # Set PSQLRC=/dev/null to prevent .psqlrc from being loaded during migration
    # This avoids the "role stk_api_role does not exist" error since roles are created by migrations
    try {
        with-env {PSQLRC: "/dev/null"} {
            ^nu -c "use ./tools/migration/mod.nu *; migrate run ./migrations"
        }
    } catch {
        print $"(ansi red)Migration failed(ansi reset)"
        exit 1
    }
}

# Generate schema documentation files
def generate_schema_details [] {
    print "Generating schema details..."
    
    let schema_dir = $"($env.STK_TEST_DIR)/schema-details"
    
    # Generate API schema (clean version)
    try {
        ^pg_dump --schema-only -n api -h $env.PGHOST -U $env.STK_SUPERUSER -d $env.PGDATABASE
        | lines
        | where not ($it | str starts-with '--')
        | where not ($it | str starts-with 'GRANT')
        | where not ($it | str starts-with 'ALTER')
        | str join "\n"
        | save $"($schema_dir)/schema-api.sql"
    } catch {
        print $"(ansi yellow)Warning: Failed to generate API schema(ansi reset)"
    }
    
    # Generate enum values and private schema details
    try {
        let enum_content = [
            "---- the following represent all enum values ----"
            ""
            "--select * from api.enum_value"
            (^psql -h $env.PGHOST -U $env.STK_SUPERUSER -d $env.PGDATABASE -c "select * from api.enum_value")
            ""
            "---- the following represent all private table defaults ----"
            "---- we are includes these values so that you can see the default values for the tables behind the api views ----"
            "---- when inserting records, to do set colums with default values unless the default is not desired ----"
            ""
        ] | str join "\n"
        
        let private_schema = ^pg_dump --schema-only -n private --table='stk*' -h $env.PGHOST -U $env.STK_SUPERUSER -d $env.PGDATABASE
        | lines
        | where not ($it | str starts-with '--')
        | where not ($it | str starts-with 'GRANT')
        | where not ($it | str starts-with 'ALTER')
        | where not ($it | str contains 'ADD CONSTRAINT')
        | where not ($it | str starts-with 'CREATE TRIGGER')
        | str join "\n"
        
        [$enum_content $private_schema] | str join "\n" | save $"($schema_dir)/schema-private.sql"
    } catch {
        print $"(ansi yellow)Warning: Failed to generate private schema details(ansi reset)"
    }
}

# Setup PostgREST configuration
def setup_postgrest [] {
    print "Setting up PostgREST configuration..."
    
    let config_file = $"($env.STK_TEST_DIR)/postgrest-config/postgrest.conf"
    let curl_script = $"($env.STK_TEST_DIR)/postgrest-config/curl.sh"
    
    # PostgREST config
    [
        $"db-uri = \"postgres://postgrest@/($env.PGDATABASE)?host=($env.PGHOST)\""
        'db-schemas = "api"'
        'db-anon-role = "stk_api_role"'
        'server-port = 3001'
    ] | str join "\n" | save $config_file
    
    # Sample curl script
    [
        "curl -X POST \\"
        "  'http://localhost:3001/rpc/stk_form_post_fn' \\"
        "  -H 'Content-Type: application/json' \\"
        "  -d '{"
        "    \"name\": \"John Doe\","
        "    \"email\": \"john@example.com\","
        "    \"message\": \"Hello, this is a test form submission\""
        "  }'"
    ] | str join "\n" | save $curl_script
    
    ^chmod +x $curl_script
}

# Setup chuck-stack documentation access
def setup_documentation [] {
    print "Setting up chuck-stack documentation access..."
    
    let docs_path = "/opt/chuckstack.github.io"
    
    if not ($docs_path | path exists) {
        try {
            ^sudo git clone https://github.com/chuckstack/chuckstack.github.io $docs_path
        } catch {
            print $"(ansi yellow)Warning: Failed to clone chuck-stack docs to ($docs_path)(ansi reset)"
        }
    }
}

# Show usage information
def show_usage_info [] {
    print ""
    print "******************************************************"
    print $"Test environment created in: ($env.STK_TEST_DIR)"
    print $"To navigate to test directory: cd ($env.STK_TEST_DIR)"
    print $"PostgreSQL is running using Unix socket in ($env.PGHOST)"
    print $"Issue \"psql\" to connect to ($env.PGDATABASE) database"
    print ""
    print "Migration commands (run from $STK_TEST_DIR):"
    print "  migrate status ./migrations       # Show migration status"
    print "  migrate history ./migrations      # Show migration history"  
    print "  migrate run ./migrations --dry-run # Test without applying"
    print "  migrate add ./migrations <description> # Create new migration"
    print ""
    print $"Note: PGUSER = ($env.STK_USER) \(demonstrating user login with no abilities)"
    print "Note: STK_PG_ROLE sets the desired role for both psql and aichat"
    print "      export STK_PG_ROLE=stk_api_role #default"
    print "      export STK_PG_ROLE=stk_private_role"
    print "      psql => show role; --to see your current role"
    print "Note: To connect as a superuser"
    print "      export STK_PG_ROLE=stk_superuser"
    print "      export PGUSER=stk_superuser"
    print "      psql => show role; --to see your current role"
    print ""
    print "PostgREST details:"
    print $"      config file => ($env.STK_TEST_DIR)/postgrest-config/postgrest.conf"
    print "      start PostgREST => postgrest $STK_TEST_DIR/postgrest-config/postgrest.conf"
    print $"      example curl => sh ($env.STK_TEST_DIR)/postgrest-config/curl.sh"
    print ""
    print "Note: this database and all artifacts will be destroyed on shell exit"
    print "******************************************************"
    print ""
}

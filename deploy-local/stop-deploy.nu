#!/usr/bin/env nu

# Stop deployment environment (preserve data)
def main [] {
    print $"(ansi yellow)Stopping PostgreSQL deployment environment...(ansi reset)"
    
    # Change back to original directory
    if ($env.STK_PWD_SHELL? | is-not-empty) {
        cd $env.STK_PWD_SHELL
    }
    
    # Stop PostgreSQL if running
    if ($env.PGHOST? | is-not-empty) and ($env.PGHOST | path exists) {
        try {
            ^pg_ctl stop -D $env.PGHOST
            print "PostgreSQL stopped"
        } catch {
            print $"(ansi yellow)Warning: Failed to stop PostgreSQL gracefully(ansi reset)"
        }
    }
    
    # NOTE: Unlike test environment, we DO NOT remove the deployment directory
    # Data is preserved for next restart
    
    if ($env.STK_DEPLOY_DIR? | is-not-empty) {
        print $"PostgreSQL stopped. Data preserved in: ($env.STK_DEPLOY_DIR)"
    }
    
    print $"(ansi green)Deployment environment stopped!(ansi reset)"
}
#!/usr/bin/env nu

# Stop and cleanup test environment
def main [] {
    print $"(ansi yellow)Stopping PostgreSQL and cleaning up test environment...(ansi reset)"
    
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
    
    # Remove test directory
    if ($env.STK_TEST_DIR? | is-not-empty) and ($env.STK_TEST_DIR | path exists) {
        try {
            rm -rf $env.STK_TEST_DIR
            print $"Removed temporary test directory: ($env.STK_TEST_DIR)"
        } catch {
            print $"(ansi yellow)Warning: Failed to remove test directory ($env.STK_TEST_DIR)(ansi reset)"
        }
    }
    
    print $"(ansi green)Test environment cleanup complete!(ansi reset)"
}
# PSQL Common Module
# This module provides common commands for executing PostgreSQL queries

# Execute a SQL query using psql with .psqlrc-nu configuration
export def "psql exec" [
    query: string  # The SQL query to execute
] {
    with-env {PSQLRC: ".psqlrc-nu"} {
        echo $query | psql | from csv
    }
}

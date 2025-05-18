# PSQL Common Module
# This module provides common commands for executing PostgreSQL queries

# Execute a SQL query using psql with .psqlrc-nu configuration
export def "psql exec" [
    query: string  # The SQL query to execute
] {
    with-env {PSQLRC: ".psqlrc-nu"} {
        mut result = []
        $result = echo $query | psql | from csv --no-infer
        let date_cols = $result 
            | columns 
            | where {|x| ($x == 'created') or ($x == 'updated') or ($x | str starts-with 'date_')}
        if not ($date_cols | is-empty) {
            for col in $date_cols {
                $result = $result | into datetime $col
            }
        }
        let json_cols = $result 
            | columns 
            | where {|x| ($x == 'record_json')}
        if not ($json_cols | is-empty) {
            for col in $json_cols {
                $result = $result | update $col { from json }
            }
        }
        let bool_cols = $result 
            | columns 
            | where {|x| ($x | str starts-with 'is_')}
        if not ($bool_cols | is-empty) {
            for col in $bool_cols {
                $result = $result | into bool $col
            }
        }
        $result
    }
}

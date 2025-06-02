# PSQL Common Module
# This module provides common commands for executing PostgreSQL queries

# Helper function to convert PostgreSQL boolean values (t/f) to nushell booleans
def "into bool ext" [] {
    match $in {
        "t" => true,
        "f" => false,
        _ => ($in | into bool)
    }
}

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
                $result = $result | update $col { into bool ext }
            }
        }
        $result
    }
}

# Generic list records from a table with default ordering and limit
#
# Executes a SELECT query with standard columns and ordering for any STK table.
# Returns records ordered by created DESC with configurable limit.
# Used by module-specific list commands to reduce code duplication.
#
# Examples:
#   psql list-records "api" "stk_event" "uu, created, updated, is_revoked" "name, record_json" 10
#   psql list-records $STK_SCHEMA $STK_TABLE_NAME $STK_BASE_COLUMNS $STK_EVENT_COLUMNS $STK_DEFAULT_LIMIT
#
# Returns: All specified columns from the table, newest records first
# Note: Uses the same column processing as psql exec (datetime, json, boolean conversion)
export def "psql list-records" [
    schema: string          # Database schema (e.g., "api")
    table_name: string      # Table name (e.g., "stk_event") 
    base_columns: string    # Base columns (e.g., "uu, created, updated, is_revoked")
    specific_columns: string # Module-specific columns (e.g., "name, record_json")
    limit: int = 10         # Maximum number of records to return
] {
    let table = $"($schema).($table_name)"
    let columns = $"($base_columns), ($specific_columns)"
    psql exec $"SELECT ($columns) FROM ($table) ORDER BY created DESC LIMIT ($limit)"
}

# Generic get single record by UUID from a table
#
# Executes a SELECT query to fetch a specific record by its UUID.
# Returns complete record details for the specified UUID.
# Used by module-specific get commands to reduce code duplication.
#
# Examples:
#   psql get-record "api" "stk_event" "uu, created, updated, is_revoked" "name, record_json" $uuid
#   psql get-record $STK_SCHEMA $STK_TABLE_NAME $STK_BASE_COLUMNS $STK_EVENT_COLUMNS $uu
#
# Returns: Single record with all specified columns, or empty if UUID not found
# Note: Uses the same column processing as psql exec (datetime, json, boolean conversion)
export def "psql get-record" [
    schema: string          # Database schema (e.g., "api")
    table_name: string      # Table name (e.g., "stk_event")
    base_columns: string    # Base columns (e.g., "uu, created, updated, is_revoked")
    specific_columns: string # Module-specific columns (e.g., "name, record_json")
    uu: string              # UUID of the record to retrieve
] {
    let table = $"($schema).($table_name)"
    let columns = $"($base_columns), ($specific_columns)"
    psql exec $"SELECT ($columns) FROM ($table) WHERE uu = '($uu)'"
}

# Generic revoke record by UUID in a table
#
# Executes an UPDATE query to set the revoked timestamp to now() for the specified UUID.
# This performs a soft delete by marking the record as revoked while preserving data.
# Used by module-specific revoke commands to reduce code duplication.
#
# Examples:
#   psql revoke-record "api" "stk_event" $uuid
#   psql revoke-record $STK_SCHEMA $STK_TABLE_NAME $uu
#
# Returns: uu, name, revoked timestamp, and is_revoked status for the revoked record
# Error: Command fails if UUID doesn't exist or record is already revoked
export def "psql revoke-record" [
    schema: string          # Database schema (e.g., "api")
    table_name: string      # Table name (e.g., "stk_event")
    uu: string              # UUID of the record to revoke
] {
    let table = $"($schema).($table_name)"
    psql exec $"UPDATE ($table) SET revoked = now\() WHERE uu = '($uu)' RETURNING uu, name, revoked, is_revoked"
}

# Generic process record by UUID in a table
#
# Executes an UPDATE query to set the processed timestamp to now() for the specified UUID.
# This marks the record as completed/processed in tables that support processing status.
# Used by module-specific process commands to reduce code duplication.
#
# Examples:
#   psql process-record "api" "stk_request" $uuid
#   psql process-record $STK_SCHEMA $STK_TABLE_NAME $uu
#
# Returns: uu, name, processed timestamp, and is_processed status for the processed record
# Error: Command fails if UUID doesn't exist, record is already processed, or table lacks processed column
export def "psql process-record" [
    schema: string          # Database schema (e.g., "api")
    table_name: string      # Table name (e.g., "stk_request")
    uu: string              # UUID of the record to mark as processed
] {
    let table = $"($schema).($table_name)"
    psql exec $"UPDATE ($table) SET processed = now\() WHERE uu = '($uu)' RETURNING uu, name, processed, is_processed"
}

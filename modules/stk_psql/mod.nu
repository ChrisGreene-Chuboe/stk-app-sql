# STK PSQL Module
# This module provides common commands for executing PostgreSQL queries

# Module Constants
const STK_SCHEMA = "api"
const STK_PRIVATE_SCHEMA = "private"

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
        if ($date_cols | is-not-empty) {
            $result = $result | into datetime ...$date_cols
        }
        let json_cols = $result 
            | columns 
            | where {|x| ($x | str ends-with '_json')}
        if ($json_cols | is-not-empty) {
            for col in $json_cols {
                $result = $result | update $col { from json }
            }
        }
        let bool_cols = $result 
            | columns 
            | where {|x| ($x | str starts-with 'is_')}
        if ($bool_cols | is-not-empty) {
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

# Generic create new record in a table
#
# Executes an INSERT query to create a new record with specified name and optional fields.
# This provides a standard way to create records in STK tables with automatic defaults.
# The system automatically assigns default type_uu and entity_uu values via triggers.
#
# Examples:
#   psql new-record "api" "stk_item" "Product Name"
#   psql new-record "api" "stk_item" "Service Item" --description "Professional consulting"
#   psql new-record $STK_SCHEMA $STK_TABLE_NAME $name --type-uu $type_uu --description $desc
#
# Returns: uu, name, and other basic fields for the newly created record
# Error: Command fails if required references don't exist or constraints are violated
export def "psql new-record" [
    schema: string              # Database schema (e.g., "api")
    table_name: string          # Table name (e.g., "stk_item")
    name: string                # Name for the new record
    --type-uu(-t): string       # Optional type UUID (uses default type if not provided)
    --description(-d): string   # Optional description for the record
    --entity-uu(-e): string     # Optional entity UUID (uses first entity if not provided)
] {
    let table = $"($schema).($table_name)"
    
    # Build the entity clause - use provided or let trigger handle default
    let entity_clause = if ($entity_uu | is-empty) {
        $"\(SELECT uu FROM ($schema).stk_entity LIMIT 1)"
    } else {
        $"'($entity_uu)'"
    }
    
    # Build SQL based on what's provided
    let sql = if ($type_uu | is-not-empty) and ($description | is-not-empty) {
        $"INSERT INTO ($table) \(name, description, type_uu, stk_entity_uu) VALUES \('($name)', '($description)', '($type_uu)', ($entity_clause)) RETURNING uu, name, description"
    } else if ($type_uu | is-not-empty) {
        $"INSERT INTO ($table) \(name, type_uu, stk_entity_uu) VALUES \('($name)', '($type_uu)', ($entity_clause)) RETURNING uu, name"
    } else if ($description | is-not-empty) {
        $"INSERT INTO ($table) \(name, description, stk_entity_uu) VALUES \('($name)', '($description)', ($entity_clause)) RETURNING uu, name, description"
    } else {
        $"INSERT INTO ($table) \(name, stk_entity_uu) VALUES \('($name)', ($entity_clause)) RETURNING uu, name"
    }
    
    psql exec $sql
}

# Enhanced new record creation using parameter record approach
#
# This is an enhanced version of new-record that eliminates cascading if/else logic
# by accepting all parameters in a record structure. It dynamically builds SQL
# based on which fields are present (non-null) in the parameters record.
#
# Examples:
#   let params = {name: "Test Item", description: "A test item"}
#   psql new-record-enhanced "api" "stk_item" $params
#   
#   let params = {name: "Service", type_uu: "uuid-here", description: "Professional service"}
#   psql new-record-enhanced $STK_SCHEMA $STK_TABLE_NAME $params
#
# Parameters record can contain:
#   - name: string (required)
#   - type_uu: string (optional)
#   - description: string (optional) 
#   - entity_uu: string (optional)
#
# Returns: uu, name, and other fields for the newly created record
# Error: Command fails if required references don't exist or constraints are violated
export def "psql new-record-enhanced" [
    schema: string      # Database schema (e.g., "api")
    table_name: string  # Table name (e.g., "stk_item")
    params: record      # Parameters record with name (required) and optional fields
] {
    let table = $"($schema).($table_name)"
    
    # Validate required name parameter
    if ($params.name? | is-empty) {
        error make {msg: "Parameter 'name' is required in params record"}
    }
    
    # Build entity clause - use provided or let trigger handle default
    let entity_clause = if ($params.entity_uu? | is-empty) {
        $"\(SELECT uu FROM ($schema).stk_entity LIMIT 1)"
    } else {
        $"'($params.entity_uu)'"
    }
    
    # Build columns and values lists dynamically
    let base_columns = ["name", "stk_entity_uu"]
    let base_values = [$"'($params.name)'", $entity_clause]
    
    # Add optional columns and values if they exist
    let final_columns = $base_columns 
        | append (if ($params.type_uu? | is-not-empty) { ["type_uu"] } else { [] })
        | append (if ($params.description? | is-not-empty) { ["description"] } else { [] })
    
    let final_values = $base_values
        | append (if ($params.type_uu? | is-not-empty) { [$"'($params.type_uu)'"] } else { [] })
        | append (if ($params.description? | is-not-empty) { [$"'($params.description)'"] } else { [] })
    
    # Build RETURNING clause based on what we're inserting
    let returning_columns = ["uu", "name"]
        | append (if ($params.description? | is-not-empty) { ["description"] } else { [] })
    
    # Construct final SQL
    let columns_str = $final_columns | str join ", "
    let values_str = $final_values | str join ", "
    let returning_str = $returning_columns | str join ", "
    
    let sql = $"INSERT INTO ($table) \(($columns_str)) VALUES \(($values_str)) RETURNING ($returning_str)"
    
    psql exec $sql
}

# Generic list types for a specific table concept
#
# Shows all available types for any STK table that has an associated type table.
# This provides a standard way to view type options across all chuck-stack concepts.
# Use this to see valid type options before creating new records with specific types.
#
# Examples:
#   psql list-types "api" "stk_item_type"
#   psql list-types "api" "stk_request_type"
#   psql list-types $STK_SCHEMA $STK_TYPE_TABLE_NAME
#
# Returns: uu, type_enum, name, description, is_default, created for all active types
# Note: Shows types ordered by type_enum for consistent display
export def "psql list-types" [
    schema: string          # Database schema (e.g., "api")
    type_table_name: string # Type table name (e.g., "stk_item_type")
] {
    let table = $"($schema).($type_table_name)"
    let sql = $"
        SELECT uu, type_enum, name, description, is_default, created
        FROM ($table)
        WHERE is_revoked = false
        ORDER BY type_enum
    "
    psql exec $sql
}

# Generic type resolution - converts type enum to UUID
#
# Resolves a type enum string to its corresponding UUID for any STK type table.
# This provides a standard way to look up type UUIDs across all chuck-stack concepts.
# Use this when you need to convert user-friendly type names to database UUIDs.
#
# Examples:
#   psql resolve-type "api" "stk_item_type" "PRODUCT-STOCKED"
#   psql resolve-type "api" "stk_request_type" "INVESTIGATION" 
#   psql resolve-type $STK_SCHEMA $STK_TYPE_TABLE_NAME $type_string
#
# Returns: UUID string for the specified type
# Error: Command fails if type_enum doesn't exist in the type table
export def "psql resolve-type" [
    schema: string          # Database schema (e.g., "api")
    type_table_name: string # Type table name (e.g., "stk_item_type")
    type_enum: string       # Type enum value to resolve (e.g., "PRODUCT-STOCKED")
] {
    let type_result = (psql exec $"SELECT uu FROM ($schema).($type_table_name) WHERE type_enum = '($type_enum)' LIMIT 1")
    if ($type_result | is-empty) {
        error make {msg: $"Type '($type_enum)' not found in ($schema).($type_table_name)"}
    } else {
        $type_result | get uu.0
    }
}

# Generic get detailed record information including type
#
# Provides a comprehensive view of any STK record by joining with its type
# table to show classification and context. This is a standard pattern across
# all chuck-stack concepts that have associated type tables.
#
# Examples:
#   psql detail-record "api" "stk_item" "stk_item_type" $uuid
#   psql detail-record "api" "stk_request" "stk_request_type" $uuid
#   psql detail-record $STK_SCHEMA $STK_TABLE_NAME $STK_TYPE_TABLE_NAME $uu
#
# Returns: Complete record details with type_enum, type_name, and other joined information
# Error: Returns empty result if UUID doesn't exist
export def "psql detail-record" [
    schema: string              # Database schema (e.g., "api")
    table_name: string          # Main table name (e.g., "stk_item")
    type_table_name: string     # Type table name (e.g., "stk_item_type")
    uu: string                  # UUID of the record to get details for
] {
    let table = $"($schema).($table_name)"
    let type_table = $"($schema).($type_table_name)"
    let sql = $"
        SELECT 
            i.uu, i.name, i.description, i.is_template, i.is_valid,
            it.type_enum, it.name as type_name,
            i.created, i.updated, i.is_revoked
        FROM ($table) i
        JOIN ($type_table) it ON i.type_uu = it.uu
        WHERE i.uu = '($uu)'
    "
    psql exec $sql
}

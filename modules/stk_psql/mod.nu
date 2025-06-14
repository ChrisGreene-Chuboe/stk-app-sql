# STK PSQL Module
# This module provides common commands for executing PostgreSQL queries

# Module Constants
const STK_SCHEMA = "api"
const STK_PRIVATE_SCHEMA = "private"

# Chuck-stack standard column definitions
export const STK_BASE_COLUMNS = [created, created_by_uu, updated, updated_by_uu, is_revoked, uu, table_name]
export const STK_REVOKED_COLUMNS = [revoked, is_revoked]
export const STK_PROCESSED_COLUMNS = [processed, is_processed]
export const STK_TYPE_COLUMNS = [name, description, search_key, type_enum, is_revoked, is_default, record_json, uu]

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
#   psql list-records "api" "stk_event" [name, record_json] $STK_BASE_COLUMNS 10
#   psql list-records $STK_SCHEMA $STK_TABLE_NAME $STK_EVENT_COLUMNS $STK_BASE_COLUMNS $STK_DEFAULT_LIMIT
#
# Returns: All specified columns from the table, newest records first
# Note: Uses the same column processing as psql exec (datetime, json, boolean conversion)
export def "psql list-records" [
    schema: string          # Database schema (e.g., "api")
    table_name: string      # Table name (e.g., "stk_event") 
    specific_columns: list  # Module-specific columns (e.g., [name, record_json])
    limit: int = 10         # Maximum number of records to return
] {
    let table = $"($schema).($table_name)"
    let columns = ($specific_columns | append $STK_BASE_COLUMNS | str join ", ")
    psql exec $"SELECT ($columns) FROM ($table) ORDER BY created DESC LIMIT ($limit)"
}

# Generic list line records filtered by header UUID
#
# Executes a SELECT query for line records belonging to a specific header record.
# This supports the common ERP pattern where line items belong to header records
# (e.g., project_line -> project, invoice_line -> invoice, order_line -> order).
# Returns records ordered by created DESC with configurable limit.
#
# Examples:
#   psql list-line-records "api" "stk_project_line" [name, description] $project_uu
#   psql list-line-records $STK_SCHEMA $STK_LINE_TABLE_NAME $STK_LINE_COLUMNS $header_uu 20
#
# Returns: All specified columns plus base columns for lines belonging to the header
# Note: Filters out revoked records (is_revoked = false)
export def "psql list-line-records" [
    schema: string          # Database schema (e.g., "api")
    line_table_name: string # Line table name (e.g., "stk_project_line")
    specific_columns: list  # Module-specific columns (e.g., [name, description])
    header_uu: string       # UUID of the header record to filter by
    limit: int = 10         # Maximum number of records to return
] {
    let table = $"($schema).($line_table_name)"
    let columns = ($specific_columns | append $STK_BASE_COLUMNS | str join ", ")
    psql exec $"SELECT ($columns) FROM ($table) WHERE header_uu = '($header_uu)' AND is_revoked = false ORDER BY created DESC LIMIT ($limit)"
}

# Generic get single record by UUID from a table
#
# Executes a SELECT query to fetch a specific record by its UUID.
# Returns complete record details for the specified UUID.
# Used by module-specific get commands to reduce code duplication.
#
# Examples:
#   psql get-record "api" "stk_event" [name, record_json] $uuid
#   psql get-record $STK_SCHEMA $STK_TABLE_NAME $STK_EVENT_COLUMNS $uu
#
# Returns: Single record with all specified columns, or empty if UUID not found
# Note: Uses the same column processing as psql exec (datetime, json, boolean conversion)
export def "psql get-record" [
    schema: string          # Database schema (e.g., "api")
    table_name: string      # Table name (e.g., "stk_event")
    specific_columns: list  # Module-specific columns (e.g., [name, record_json])
    uu: string              # UUID of the record to retrieve
] {
    let table = $"($schema).($table_name)"
    let columns = ($specific_columns | append $STK_BASE_COLUMNS | str join ", ")
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
# Executes an INSERT query to create a new record using a parameter record approach.
# This provides a standard way to create records in STK tables with automatic defaults.
# The system automatically assigns default type_uu and entity_uu values via triggers.
# This implementation eliminates cascading if/else logic by accepting all parameters
# in a record structure and dynamically building SQL based on which fields are present.
#
# Examples:
#   let params = {name: "Product Name"}
#   psql new-record "api" "stk_item" $params
#   
#   let params = {name: "Service Item", description: "Professional consulting"}
#   psql new-record "api" "stk_item" $params
#   
#   let params = {name: "Service", type_uu: "uuid-here", description: "Professional service"}
#   psql new-record $STK_SCHEMA $STK_TABLE_NAME $params
#
# Parameters record can contain:
#   - name: string (required)
#   - type_uu: string (optional)
#   - description: string (optional) 
#   - entity_uu: string (optional)
#
# Returns: uu, name, and other fields for the newly created record
# Error: Command fails if required references don't exist or constraints are violated
export def "psql new-record" [
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

# Generic create new line record for header-line relationships
#
# Creates a new line record that belongs to a header record using the established
# chuck-stack header-line pattern. This handles the common ERP scenario where
# detailed line items belong to summary header records (project/project_line,
# invoice/invoice_line, order/order_line, etc.).
#
# The function automatically derives the header table name by removing '_line' suffix
# and constructs the foreign key field name as {header_table_name}_uu.
#
# Examples:
#   let params = {name: "User Authentication"}
#   psql new-line-record "api" "stk_project_line" $project_uu $params
#   
#   let params = {name: "Consulting Hours", description: "Professional services", type_uu: $type_uu}
#   psql new-line-record "api" "stk_invoice_line" $invoice_uu $params
#   
#   let params = {name: "Product Item", description: "Hardware component"}
#   psql new-line-record $STK_SCHEMA $STK_LINE_TABLE_NAME $header_uu $params
#
# Parameters record can contain:
#   - name: string (required)
#   - type_uu: string (optional)
#   - description: string (optional) 
#   - entity_uu: string (optional)
#   - is_template: boolean (optional)
#
# Returns: uu, name, and other fields for the newly created line record
# Error: Command fails if required references don't exist or constraints are violated
export def "psql new-line-record" [
    schema: string           # Database schema (e.g., "api")
    line_table_name: string  # Line table name (e.g., "stk_project_line")
    header_uu: string        # UUID of the header record
    params: record           # Parameters record with name (required) and optional fields
] {
    let table = $"($schema).($line_table_name)"
    
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
    let base_columns = ["name", "stk_entity_uu", "header_uu"]
    let base_values = [$"'($params.name)'", $entity_clause, $"'($header_uu)'"]
    
    # Add optional columns and values if they exist
    let final_columns = $base_columns 
        | append (if ($params.type_uu? | is-not-empty) { ["type_uu"] } else { [] })
        | append (if ($params.description? | is-not-empty) { ["description"] } else { [] })
        | append (if ($params.is_template? | is-not-empty) { ["is_template"] } else { [] })
    
    let final_values = $base_values
        | append (if ($params.type_uu? | is-not-empty) { [$"'($params.type_uu)'"] } else { [] })
        | append (if ($params.description? | is-not-empty) { [$"'($params.description)'"] } else { [] })
        | append (if ($params.is_template? | is-not-empty) { [$"($params.is_template)"] } else { [] })
    
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
#   psql list-types "api" "stk_item"
#   psql list-types "api" "stk_request"
#   psql list-types $STK_SCHEMA $STK_TABLE_NAME
#
# Returns: uu, type_enum, name, description, is_default, created for all active types
# Note: Shows types ordered by type_enum for consistent display
export def "psql list-types" [
    schema: string          # Database schema (e.g., "api")
    table_name: string      # Table name (e.g., "stk_item")
] {
    let table = $"($schema).($table_name)_type"
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
#   psql resolve-type "api" "stk_item" "PRODUCT-STOCKED"
#   psql resolve-type "api" "stk_request" "INVESTIGATION" 
#   psql resolve-type $STK_SCHEMA $STK_TABLE_NAME $type_string
#
# Returns: UUID string for the specified type
# Error: Command fails if type_enum doesn't exist in the type table
export def "psql resolve-type" [
    schema: string          # Database schema (e.g., "api")
    table_name: string      # Table name (e.g., "stk_item")
    type_enum: string       # Type enum value to resolve (e.g., "PRODUCT-STOCKED")
] {
    let type_table_name = $"($table_name)_type"
    let type_result = (psql exec $"SELECT uu FROM ($schema).($type_table_name) WHERE type_enum = '($type_enum)' LIMIT 1")
    if ($type_result | is-empty) {
        error make {msg: $"Type '($type_enum)' not found in ($schema).($type_table_name)"}
    } else {
        $type_result | get uu.0
    }
}

# Generic list records with detailed type information
#
# Executes a SELECT query with joins to type table for detailed views.
# Returns records with type information ordered by created DESC with configurable limit.
# Used by module-specific list --detail commands to reduce code duplication.
#
# Examples:
#   psql list-records-with-detail "api" "stk_item" [name, description, is_template, is_valid] 10
#   psql list-records-with-detail $STK_SCHEMA $STK_TABLE_NAME $STK_ITEM_COLUMNS
#
# Returns: All specified columns plus type_enum, type_name, type_description from joined type table
# Note: Uses LEFT JOIN to include records without type assignments
export def "psql list-records-with-detail" [
    schema: string           # Database schema (e.g., "api")
    table_name: string       # Table name (e.g., "stk_item") 
    specific_columns: list   # Module-specific columns (e.g., [name, description, is_template, is_valid])
    limit: int = 10          # Maximum number of records to return
] {
    let table = $"($schema).($table_name)"
    let type_table = $"($schema).($table_name)_type"
    # Prefix columns with table aliases properly
    let specific_cols = $specific_columns | each {|col| $"i.($col)"} | str join ", "
    let base_cols = $STK_BASE_COLUMNS | each {|col| $"i.($col)"} | str join ", "
    
    # Build type columns with 'type_' prefix dynamically from STK_TYPE_COLUMNS
    # Don't prefix if column already starts with 'type_'
    let type_cols = $STK_TYPE_COLUMNS | each {|col| 
        if ($col | str starts-with 'type_') {
            $"t.($col) as ($col)"
        } else {
            $"t.($col) as type_($col)"
        }
    } | str join ", "
    
    let sql = $"
        SELECT 
            ($specific_cols), ($base_cols),
            ($type_cols)
        FROM ($table) i
        LEFT JOIN ($type_table) t ON i.type_uu = t.uu
        WHERE i.is_revoked = false
        ORDER BY i.created DESC
        LIMIT ($limit)
    "
    psql exec $sql
}

# Generic get detailed record information including type
#
# Provides a comprehensive view of any STK record by joining with its type
# table to show classification and context. This is a standard pattern across
# all chuck-stack concepts that have associated type tables.
# 
# This function dynamically selects columns that exist in the table to handle
# different table schemas across STK modules.
#
# Examples:
#   psql detail-record "api" "stk_item" $uuid
#   psql detail-record "api" "stk_request" $uuid
#   psql detail-record $STK_SCHEMA $STK_TABLE_NAME $uu
#
# Returns: Complete record details with type_enum, type_name, and other joined information
# Error: Returns empty result if UUID doesn't exist
export def "psql detail-record" [
    schema: string              # Database schema (e.g., "api")
    table_name: string          # Main table name (e.g., "stk_item")
    uu: string                  # UUID of the record to get details for
] {
    let table = $"($schema).($table_name)"
    let type_table = $"($schema).($table_name)_type"
    
    # Build type columns with 'type_' prefix dynamically from STK_TYPE_COLUMNS
    # Don't prefix if column already starts with 'type_'
    let type_cols = $STK_TYPE_COLUMNS | each {|col| 
        if ($col | str starts-with 'type_') {
            $"t.($col) as ($col)"
        } else {
            $"t.($col) as type_($col)"
        }
    } | str join ", "
    
    # Use SELECT * to avoid hardcoding column names that may not exist across all tables
    let sql = $"
        SELECT 
            i.*,
            ($type_cols)
        FROM ($table) i
        LEFT JOIN ($type_table) t ON i.type_uu = t.uu
        WHERE i.uu = '($uu)'
    "
    psql exec $sql
}

# Elaborate foreign key references in a table by adding resolved columns
#
# Takes a table with UUID references and adds new columns containing the full
# referenced records. This enhances data exploration by automatically resolving
# foreign key relationships without modifying the original data structure.
#
# Handles two patterns:
# 1. table_name_uu_json columns - Already contain table name and UUID
# 2. xxx_uu columns - Uses api.get_table_name_uu_json() to find the table
#
# For each resolvable column, adds a new column with suffix "_resolved" containing
# the complete referenced record. Errors are handled gracefully with informative
# messages when lookups fail.
#
# Examples:
#   event list | elaborate
#   todo list | elaborate | select name todo_uu_resolved.name
#   request list | where status == "OPEN" | elaborate
#
# Returns: Original table with additional _resolved columns for each UUID reference
# Note: Resolution happens dynamically by calling each module's get command
export def elaborate [] {
    let input_table = $in
    
    # Return empty if input is empty
    if ($input_table | is-empty) {
        return $input_table
    }
    
    mut result = $input_table
    
    # Process table_name_uu_json columns
    let table_uu_json_cols = $result 
        | columns 
        | where {|x| ($x == 'table_name_uu_json')}
    
    if ($table_uu_json_cols | is-not-empty) {
        for col in $table_uu_json_cols {
            $result = $result | insert $"($col)_resolved" {|row| 
                let ref = ($row | get $col)
                if ($ref != null) and ($ref.uu? != null) and ($ref.uu != "") and ($ref.table_name? != null) and ($ref.table_name != "") {
                    # Use psql get-record directly instead of module commands
                    # This avoids dynamic command execution issues
                    try {
                        # Query the table directly using psql
                        let query = $"SELECT * FROM api.($ref.table_name) WHERE uu = '($ref.uu)'"
                        let records = (psql exec $query)
                        if ($records | is-empty) {
                            {error: $"Record not found: ($ref.table_name)/($ref.uu)"}
                        } else {
                            $records | first
                        }
                    } catch {
                        # Return error info if resolution fails
                        {error: $"Could not resolve ($ref.table_name)/($ref.uu)"}
                    }
                } else {
                    null
                }
            }
        }
    }
    
    # Process xxx_uu columns (but not the primary 'uu' column)
    let uu_cols = $result 
        | columns 
        | where {|x| ($x | str ends-with '_uu') and ($x != 'uu')}
    
    if ($uu_cols | is-not-empty) {
        for col in $uu_cols {
            $result = $result | insert $"($col)_resolved" {|row|
                let uu_value = ($row | get $col)
                if ($uu_value != null) and ($uu_value != "") {
                    # Look up table name using PostgreSQL function
                    let lookup_result = (psql exec $"SELECT api.get_table_name_uu_json\('($uu_value)'::uuid)" | first)
                    let ref = ($lookup_result | get "get_table_name_uu_json")
                    
                    if ($ref != null) and ($ref.table_name? != null) and ($ref.table_name != "") and ($ref.uu? != null) and ($ref.uu != "") {
                        # Use psql to query the table directly
                        try {
                            # Query the table directly using psql
                            let query = $"SELECT * FROM api.($ref.table_name) WHERE uu = '($ref.uu)'"
                            let records = (psql exec $query)
                            if ($records | is-empty) {
                                {error: $"Record not found: ($ref.table_name)/($ref.uu)"}
                            } else {
                                $records | first
                            }
                        } catch {
                            # Return error info if resolution fails
                            {error: $"Could not resolve ($ref.table_name)/($ref.uu)"}
                        }
                    } else {
                        {error: $"UUID ($uu_value) not found in any table"}
                    }
                } else {
                    null
                }
            }
        }
    }
    
    $result
}

# Helper function to check if a table exists in the api schema
def table-exists [table_name: string] {
    let query = $"SELECT COUNT\(*) as count FROM information_schema.tables WHERE table_schema = 'api' AND table_name = '($table_name)'"
    let result = (psql exec $query)
    if ($result | is-empty) {
        false
    } else {
        ($result | get count | get 0 | into int) > 0
    }
}

# Add a 'lines' column to records that have associated line tables
#
# This command enhances table data by adding a column containing all related line records
# for tables that follow the header-line pattern (e.g., stk_project -> stk_project_line).
#
# Purpose:
# - Automatically detects if a table has an associated '_line' table
# - Fetches all related line records using the header_uu foreign key
# - Adds a 'lines' column containing the full line records
#
# Example:
# > project list | lines
# Returns project records with a 'lines' column containing all stk_project_line records
#
# Returns:
# - Original table with an additional 'lines' column
# - The 'lines' column contains an array of line records or null if no line table exists
#
# Error handling:
# - Returns null if no line table exists for the given table_name
# - Returns empty array if line table exists but no lines are found
# - Returns error object if database query fails
export def lines [] {
    let input = $in
    
    # Return empty if no input
    if ($input | is-empty) {
        return []
    }
    
    # Build cache of table existence checks upfront
    # This avoids mutable variable capture in closures
    let unique_tables = $input 
        | where { |record| 'table_name' in ($record | columns) }
        | get table_name
        | uniq
    
    let table_cache = $unique_tables | reduce -f {} { |table_name, acc|
        let line_table_name = $"($table_name)_line"
        $acc | insert $line_table_name (table-exists $line_table_name)
    }
    
    # Process each record using the immutable cache
    let result = $input | each { |record|
        # Check if record has table_name column
        if 'table_name' not-in ($record | columns) {
            return $record | insert lines null
        }
        
        let table_name = $record.table_name
        let line_table_name = $"($table_name)_line"
        
        # Look up in the pre-built cache
        let line_table_exists = $table_cache | get -i $line_table_name | default false
        
        if $line_table_exists {
            # Line table exists, fetch the actual lines
            try {
                let lines_query = $"SELECT * FROM api.($line_table_name) WHERE header_uu = '($record.uu)' ORDER BY created"
                let lines_data = (psql exec $lines_query)
                
                # Add lines column with fetched data
                $record | insert lines $lines_data
            } catch {
                # Error occurred, return error object
                $record | insert lines { error: $"Failed to fetch lines from ($line_table_name): ($in)" }
            }
        } else {
            # No line table exists, add null column
            $record | insert lines null
        }
    }
    
    $result
}

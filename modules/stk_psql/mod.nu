# STK PSQL Module
# This module provides common commands for executing PostgreSQL queries

# Module Constants
const STK_SCHEMA = "api"
const STK_PRIVATE_SCHEMA = "private"

# Chuck-stack standard column definitions
export const STK_BASE_COLUMNS = [created, created_by_uu, updated, updated_by_uu, is_revoked, uu, table_name]
export const STK_REVOKED_COLUMNS = [revoked, is_revoked]
export const STK_PROCESSED_COLUMNS = [processed, is_processed]
export const STK_TYPE_COLUMNS = [name, description, search_key, type_enum, is_revoked, is_default, record_json]

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
    # Ensure STK_PSQLRC_NU environment variable is set
    if not ("STK_PSQLRC_NU" in $env) {
        error make {
            msg: "STK_PSQLRC_NU environment variable not set"
            label: {
                text: "Required environment variable missing"
                span: (metadata $query).span
            }
            help: "Set STK_PSQLRC_NU to the path of your .psqlrc-nu file"
        }
    }
    
    with-env {PSQLRC: $env.STK_PSQLRC_NU} {
        # Execute psql command and capture complete output
        let psql_result = (do { ^echo $query | ^psql } | complete)
        
        # Check for errors  
        if $psql_result.exit_code != 0 {
            error make {
                msg: $"PostgreSQL error: ($psql_result.stderr)"
            }
        }
        
        # Process successful result
        mut result = $psql_result.stdout | from csv --no-infer
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
            | where {|x| ($x | str starts-with 'is_') or ($x | str starts-with 'has_')}
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
#   psql list-records "api" "stk_event" "name" "record_json"
#   psql list-records "api" "stk_event" "name" "record_json" --all
#   psql list-records "api" "stk_event" "name" "record_json" --limit 20
#   
# With spread operator:
#   let args = ["api", "stk_event", "name", "record_json"]
#   psql list-records ...$args
#   psql list-records ...$args --all
#
# Returns: All specified columns from the table, newest records first
# Note: Uses the same column processing as psql exec (datetime, json, boolean conversion)
export def "psql list-records" [
    ...args: string                 # Positional arguments: schema, table_name, column1, column2, ... [, --all, --templates]
    --limit: int = 10               # Maximum number of records to return
    --enum: list<string> = []       # Type enum constraint(s) to filter by (optional)
] {
    # Check if --all or --templates flags are present in args
    let has_all = ("--all" in $args)
    let has_templates = ("--templates" in $args)
    
    # Filter out any flags from the args to get only positional arguments
    let positional_args = ($args | where {|it| not ($it | str starts-with "--") })
    
    # Validate minimum arguments
    if ($positional_args | length) < 2 {
        error make {msg: "Expected at least 2 arguments: schema and table_name"}
    }
    
    let schema = $positional_args.0
    let table_name = $positional_args.1
    # Note: specific_columns is ignored now but kept for backward compatibility
    let specific_columns = ($positional_args | skip 2)  # Ignored - using SELECT * instead
    
    let table = $"($schema).($table_name)"
    let type_table = $"($schema).($table_name)_type"
    
    # Use SELECT * for the primary table to get all API columns
    # Type columns still need explicit selection with aliases
    let type_cols = $STK_TYPE_COLUMNS | each {|col| 
        if ($col | str starts-with 'type_') {
            $"t.($col) as ($col)"
        } else {
            $"t.($col) as type_($col)"
        }
    } | str join ", "
    
    # Build WHERE clause based on flags and table capabilities
    let base_where = if $has_all {
        ""  # Show everything
    } else if $has_templates {
        # Check if table has is_template column
        let has_template_col = (column-exists "is_template" $table_name)
        if $has_template_col {
            "r.is_template = true AND r.is_revoked = false"
        } else {
            "1=1"  # No template support, show all non-revoked
        }
    } else {
        # Default: exclude revoked and templates
        let has_template_col = (column-exists "is_template" $table_name)
        if $has_template_col {
            "r.is_revoked = false AND r.is_template = false"
        } else {
            "r.is_revoked = false"
        }
    }
    
    # Add enum filtering if requested
    let where_clause = if ($enum | length) > 0 {
        let enum_list = $enum | str join "', '"
        let enum_filter = $"t.type_enum IN \('($enum_list)')"
        
        if ($base_where | is-empty) {
            $"WHERE ($enum_filter)"
        } else {
            $"WHERE ($base_where) AND ($enum_filter)"
        }
    } else {
        if ($base_where | is-empty) {
            ""
        } else {
            $"WHERE ($base_where)"
        }
    }
    
    # Always use LEFT JOIN to include type information
    # Using r.* to get all columns from the primary table
    let sql = $"
        SELECT r.*, ($type_cols)
        FROM ($table) r
        LEFT JOIN ($type_table) t ON r.type_uu = t.uu
        ($where_clause)
        ORDER BY r.created DESC
        LIMIT ($limit)
    "
    
    let result = (psql exec $sql)
    
    # If specific columns were provided (for priority), move them to the front
    if ($specific_columns | length) > 0 {
        # Filter to only columns that exist in the result
        let existing_priority = ($specific_columns | where { |col| $col in ($result | columns) })
        
        if ($existing_priority | length) > 0 {
            # Move priority columns to the beginning
            $result | move ...$existing_priority --before ($result | columns | first)
        } else {
            $result
        }
    } else {
        $result
    }
}

# Generic list line records filtered by header UUID
#
# Executes a SELECT query for line records belonging to a specific header record.
# This supports the common ERP pattern where line items belong to header records
# (e.g., project_line -> project, invoice_line -> invoice, order_line -> order).
# Returns records ordered by created DESC with configurable limit.
#
# Returns: All specified columns plus base columns for lines belonging to the header
# Note: By default filters out revoked records (use --all to include)
#
# Examples:
#   psql list-line-records "api" "stk_project_line" "af3e-3434..." "name" "description"
#   psql list-line-records "api" "stk_project_line" "af3e-3434..." "name" "description" --all
#   
# With spread operator:
#   let args = ["api", "stk_project_line", $header_uu, "name", "description"]
#   psql list-line-records ...$args
#   psql list-line-records ...$args --all
export def "psql list-line-records" [
    ...args: string         # Positional arguments: schema, line_table_name, header_uu, column1, column2, ... [, --all]
    --limit: int = 10       # Maximum number of records to return
] {
    # Check if --all flag is present in args
    let has_all = ("--all" in $args)
    
    # Filter out any flags from the args to get only positional arguments
    let positional_args = ($args | where {|it| not ($it | str starts-with "--") })
    
    # Validate minimum arguments
    if ($positional_args | length) < 3 {
        error make {msg: "Expected at least 3 arguments: schema, line_table_name, and header_uu"}
    }
    
    let schema = $positional_args.0
    let line_table_name = $positional_args.1
    let header_uu = $positional_args.2
    # Note: specific_columns is ignored now but kept for backward compatibility
    let specific_columns = ($positional_args | skip 3)  # Ignored - using SELECT * instead
    
    let table = $"($schema).($line_table_name)"
    let revoked_clause = if $has_all { "" } else { " AND is_revoked = false" }
    
    # Use SELECT * to get all columns
    let sql = $"SELECT * FROM ($table) WHERE header_uu = '($header_uu)'($revoked_clause) ORDER BY created DESC LIMIT ($limit)"
    let result = (psql exec $sql)
    
    # If specific columns were provided (for priority), move them to the front
    if ($specific_columns | length) > 0 {
        # Filter to only columns that exist in the result
        let existing_priority = ($specific_columns | where { |col| $col in ($result | columns) })
        
        if ($existing_priority | length) > 0 {
            # Move priority columns to the beginning
            $result | move ...$existing_priority --before ($result | columns | first)
        } else {
            $result
        }
    } else {
        $result
    }
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
    schema: string                # Database schema (e.g., "api")
    table_name: string            # Table name (e.g., "stk_event")
    specific_columns: list        # Module-specific columns (kept for backward compatibility, used for prioritization)
    uu: string                    # UUID of the record to retrieve
    --enum: list<string> = []     # Type enum constraint(s) to validate against (optional)
] {
    let table = $"($schema).($table_name)"
    let type_table = $"($schema).($table_name)_type"
    
    # Always include type columns for comprehensive record information
    let type_cols = $STK_TYPE_COLUMNS | each {|col| 
        if ($col | str starts-with 'type_') {
            $"t.($col) as ($col)"
        } else {
            $"t.($col) as type_($col)"
        }
    } | str join ", "
    
    # Build SQL based on enum filtering
    let sql = if ($enum | length) > 0 {
        # With enum filtering - use JOIN
        let enum_list = $enum | str join "', '"
        $"
            SELECT r.*, ($type_cols)
            FROM ($table) r
            JOIN ($type_table) t ON r.type_uu = t.uu
            WHERE r.uu = '($uu)' AND t.type_enum IN \('($enum_list)')
        "
    } else {
        # Without enum filtering - use LEFT JOIN
        $"
            SELECT r.*, ($type_cols)
            FROM ($table) r
            LEFT JOIN ($type_table) t ON r.type_uu = t.uu
            WHERE r.uu = '($uu)'
        "
    }
    
    let result = (psql exec $sql | first)
    
    # If specific columns were provided (for priority), move them to the front
    if ($specific_columns | length) > 0 and (not ($result | is-empty)) {
        # Filter to only columns that exist in the result
        let existing_priority = ($specific_columns | where { |col| $col in ($result | columns) })
        
        if ($existing_priority | length) > 0 {
            # Move priority columns to the beginning
            $result | move ...$existing_priority --before ($result | columns | first)
        } else {
            $result
        }
    } else {
        $result
    }
}


# Validate that a UUID exists in a specific table
#
# Performs a simple EXISTS check to verify the UUID is present in the
# expected table. This is used to ensure parent-child relationships 
# are created with valid UUIDs from the correct table.
#
# Examples:
#   psql validate-uuid-table $uuid "stk_project"  # Returns UUID if valid
#   psql validate-uuid-table $parent_uuid $STK_PROJECT_TABLE_NAME
#
# Returns: The validated UUID if it exists in the expected table
# Error: Throws error if UUID doesn't exist in the expected table
export def "psql validate-uuid-table" [
    uuid: string           # UUID to validate
    expected_table: string # Expected table name (e.g., "stk_project")
] {
    let sql = $"SELECT EXISTS\(SELECT 1 FROM api.($expected_table) WHERE uu = '($uuid)'::uuid) AS is_valid"
    let result = (psql exec $sql | get 0 | get is_valid)
    
    if not $result {
        error make {msg: $"UUID ($uuid) not found in table ($expected_table)"}
    }
    
    $uuid  # Return the validated UUID
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
    schema: string                # Database schema (e.g., "api")
    table_name: string            # Table name (e.g., "stk_event")
    uu: string                    # UUID of the record to revoke
    returning_columns: list = [uu, name, revoked, is_revoked]  # Columns to return (default includes name)
    --enum: list<string> = []     # Type enum constraint(s) to validate against (optional)
] {
    let table = $"($schema).($table_name)"
    let type_table = $"($schema).($table_name)_type"
    
    # If enum filtering is requested, validate first
    if ($enum | length) > 0 {
        # Build enum filter
        let enum_list = $enum | str join "', '"
        
        # Verify record exists with matching enum and not already revoked
        let check_sql = $"
            SELECT r.uu 
            FROM ($table) r
            JOIN ($type_table) t ON r.type_uu = t.uu
            WHERE r.uu = '($uu)' 
            AND t.type_enum IN \('($enum_list)')
            AND r.is_revoked = false"
        
        let check_result = psql exec $check_sql
        if ($check_result | is-empty) {
            error make { msg: $"Record not found, already revoked, or type_enum not in [($enum_list)]" }
        }
    }
    
    let returning_str = ($returning_columns | str join ", ")
    psql exec $"UPDATE ($table) SET revoked = now\() WHERE uu = '($uu)' RETURNING ($returning_str)"
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
# Creates a new record in the specified table and returns the complete record
# with all columns populated, including database-generated defaults and type information.
# Uses a parameter record approach for flexible column specification.
#
# Examples:
#   let params = {name: "Product Name"}
#   psql new-record "api" "stk_item" $params
#   
#   let params = {description: "Important event", record_json: {data: "value"}}
#   psql new-record "api" "stk_event" $params
#   
#   let params = {name: "Service", type_uu: "uuid-here", parent_uu: "parent-uuid"}
#   psql new-record $STK_SCHEMA $STK_TABLE_NAME $params
#
# Parameters record can contain any valid column names for the target table
# The calling module determines which columns are required
#
# Returns: Single record with all columns and type information
# Error: Command fails if database constraints are violated
export def "psql new-record" [
    schema: string                # Database schema (e.g., "api")
    table_name: string            # Table name (e.g., "stk_item")
    params: record                # Parameters record with column values to insert
    --enum: list<string> = []     # Type enum constraint(s) for the record (optional)
    --type-name: string           # Specific type name within the enum (optional)
] {
    let parent_uuid = $in
    let table = $"($schema).($table_name)"
    let type_table = $"($schema).($table_name)_type"
    
    # Validate params is not empty
    if ($params | is-empty) {
        error make {msg: "Parameters record cannot be empty"}
    }
    
    mut full_params = $params
    
    # If enum is specified, handle type assignment
    if ($enum | length) > 0 {
        # Build enum filter
        let enum_list = $enum | str join "', '"
        
        # Find appropriate type_uu
        let type_uu = if ($type_name | is-not-empty) {
            # Find specific type by name
            let specific_type = psql exec $"SELECT uu FROM ($type_table) WHERE type_enum IN \('($enum_list)') AND name = '($type_name)' AND is_revoked = false LIMIT 1"
            if ($specific_type | is-empty) {
                error make { msg: $"Type '($type_name)' not found with type_enum in [($enum_list)]" }
            }
            $specific_type | get uu.0
        } else {
            # Find default type
            let default_type = psql exec $"SELECT uu FROM ($type_table) WHERE type_enum IN \('($enum_list)') AND is_default = true AND is_revoked = false LIMIT 1"
            if ($default_type | is-empty) {
                # Fall back to any type
                let any_type = psql exec $"SELECT uu FROM ($type_table) WHERE type_enum IN \('($enum_list)') AND is_revoked = false LIMIT 1"
                if ($any_type | is-empty) {
                    error make { msg: $"No type found with type_enum in [($enum_list)]" }
                }
                $any_type | get uu.0
            } else {
                $default_type | get uu.0
            }
        }
        
        # Add type_uu to params
        $full_params = ($full_params | merge {type_uu: $type_uu})
        
        # Handle parent UUID if provided via pipe
        if ($parent_uuid | is-not-empty) {
            # Validate parent has matching enum
            let parent_check = psql exec $"SELECT r.uu FROM ($table) r JOIN ($type_table) t ON r.type_uu = t.uu WHERE r.uu = '($parent_uuid)' AND t.type_enum IN \('($enum_list)') AND r.is_revoked = false"
            if ($parent_check | is-empty) {
                error make { msg: $"Parent UUID must be an active record with type_enum in [($enum_list)]" }
            }
            
            # Get table_name_uu_json for the parent
            let table_name_uu_json = psql exec $"SELECT ($schema).get_table_name_uu_json\('($parent_uuid)') AS result" | get result.0
            $full_params = ($full_params | merge {table_name_uu_json: $table_name_uu_json})
        }
    }
    
    # Build columns and values from params dynamically
    let final_params = $full_params  # Create immutable copy for closure
    let columns = ($final_params | columns)
    let values = ($columns | each {|col|
        let val = ($final_params | get $col)
        if ($val == null) {
            "NULL"
        } else if ($val | describe) == "bool" {
            $val | into string
        } else if ($col | str ends-with "_json") {
            $"'($val)'::jsonb"
        } else {
            $"'($val)'"
        }
    })
    
    # Construct SQL
    let columns_str = ($columns | str join ", ")
    let values_str = ($values | str join ", ")
    
    # Only return the UUID - we'll use get-record for the complete data
    let sql = $"INSERT INTO ($table) \(($columns_str)) VALUES \(($values_str)) RETURNING uu"
    
    let insert_result = psql exec $sql
    let new_uu = $insert_result | get uu.0
    
    # Return the complete record using get-record
    psql get-record $schema $table_name [] $new_uu --enum=$enum
}


# Generic create new line record for header-line relationships
#
# Creates a new line record that belongs to a header record using the established
# chuck-stack header-line pattern. This handles the common ERP scenario where
# detailed line items belong to summary header records (project/project_line,
# invoice/invoice_line, order/order_line, etc.).
#
# Automatically adds header_uu column to link line with its header record.
# The system automatically assigns default values via database triggers for any
# columns not provided (e.g., type_uu, stk_entity_uu).
#
# Examples:
#   let params = {name: "User Authentication"}
#   psql new-line-record "api" "stk_project_line" $project_uu $params
#   
#   let params = {name: "Consulting Hours", description: "Professional services", type_uu: $type_uu}
#   psql new-line-record "api" "stk_invoice_line" $invoice_uu $params
#   
#   let params = {description: "Important milestone"}
#   psql new-line-record $STK_SCHEMA $STK_LINE_TABLE_NAME $header_uu $params
#
# Parameters record can contain any valid column names for the target line table
# The calling module determines which columns are required
# The header_uu is automatically added to link the line to its header
#
# Returns: Single record with all columns populated
# Error: Command fails if database constraints are violated
export def "psql new-line-record" [
    schema: string           # Database schema (e.g., "api")
    line_table_name: string  # Line table name (e.g., "stk_project_line")
    header_uu: string        # UUID of the header record
    params: record           # Parameters record with column values to insert
] {
    let table = $"($schema).($line_table_name)"
    
    # Validate params is not empty
    if ($params | is-empty) {
        error make {msg: "Parameters record cannot be empty"}
    }
    
    # Add header_uu to params
    let full_params = ($params | merge {header_uu: $header_uu})
    
    # Build columns and values from params dynamically
    let columns = ($full_params | columns)
    let values = ($columns | each {|col|
        let val = ($full_params | get $col)
        if ($val == null) {
            "NULL"
        } else if ($val | describe) == "bool" {
            $val | into string
        } else if ($col | str ends-with "_json") {
            $"'($val)'::jsonb"
        } else {
            $"'($val)'"
        }
    })
    
    # Construct SQL
    let columns_str = ($columns | str join ", ")
    let values_str = ($values | str join ", ")
    
    # Only return the UUID - we'll use get-record for the complete data
    let sql = $"INSERT INTO ($table) \(($columns_str)) VALUES \(($values_str)) RETURNING uu"
    
    let insert_result = psql exec $sql
    let new_uu = $insert_result | get uu.0
    
    # Return the complete record using get-record
    # Note: line tables typically don't have types, so we don't pass --enum
    psql get-record $schema $line_table_name [] $new_uu
}

# Generic list types for a specific table concept
#
# Shows all available types for any STK table that has an associated type table.
# This provides a standard way to view type options across all chuck-stack concepts.
# Use this to see valid type options before creating new records with specific types.
#
# Examples:
#   psql list-types "api" "stk_item"
#   psql list-types "api" "stk_request" --all
#   
# With spread operator:
#   let args = ["api", "stk_item"]
#   psql list-types ...$args
#   psql list-types ...$args --all
#
# Returns: All columns from the type table including table_name
# Note: By default shows only active types, use --all to include revoked
export def "psql list-types" [
    ...args: string                 # Positional arguments: schema, table_name [, --all]
    --enum: list<string> = []       # Type enum constraint(s) to filter by (optional)
] {
    # Check if --all flag is present in args
    let has_all = ("--all" in $args)
    
    # Filter out any flags from the args to get only positional arguments
    let positional_args = ($args | where {|it| not ($it | str starts-with "--") })
    
    # Validate arguments
    if ($positional_args | length) != 2 {
        error make {msg: "Expected exactly 2 arguments: schema and table_name"}
    }
    
    let schema = $positional_args.0
    let table_name = $positional_args.1
    
    let table = $"($schema).($table_name)_type"
    
    # Build WHERE clause
    let enum_filter = if ($enum | length) > 0 {
        let enum_list = $enum | str join "', '"
        $"type_enum IN \('($enum_list)')"
    } else {
        ""
    }
    
    let revoked_filter = if not $has_all { "is_revoked = false" } else { "" }
    
    # Combine filters
    let where_parts = [$enum_filter, $revoked_filter] | where {|it| $it | is-not-empty}
    let where_clause = if ($where_parts | length) > 0 {
        $"WHERE ($where_parts | str join ' AND ')"
    } else {
        ""
    }
    
    let sql = $"
        SELECT uu, type_enum, search_key, name, description, record_json, is_default, created, table_name
        FROM ($table)
        ($where_clause)
        ORDER BY type_enum, name
    "
    psql exec $sql
}



# Flexible type lookup by search_key or name
#
# Looks up a type record using either search_key or name field.
# Automatically detects if the type table has a name column and
# searches the appropriate field based on what's provided.
# Always filters out revoked records.
#
# Examples:
#   psql get-type "api" "stk_item" --search-key "RETAIL"
#   psql get-type "api" "stk_project" --name "Client Project"
#   psql get-type $STK_SCHEMA $STK_TABLE_NAME --search-key $type_key
#
# Returns: Type record if found
# Error: If type not found or if name used on table without name column
export def "psql get-type" [
    schema: string          # Database schema (e.g., "api")
    table_name: string      # Table name (e.g., "stk_item")
    --search-key: string    # Search by search_key field
    --name: string          # Search by name field (if column exists)
] {
    let type_table = $"($table_name)_type"
    
    # Ensure exactly one search parameter is provided
    if (($search_key | is-empty) and ($name | is-empty)) {
        error make {msg: "Must provide either --search-key or --name"}
    }
    
    if (($search_key | is-not-empty) and ($name | is-not-empty)) {
        error make {msg: "Provide only one of --search-key or --name, not both"}
    }
    
    # Check if name column exists if --name was provided
    if ($name | is-not-empty) {
        let has_name = (
            psql exec $"SELECT EXISTS \(
                SELECT 1 FROM information_schema.columns 
                WHERE table_schema = '($schema)' 
                AND table_name = '($type_table)' 
                AND column_name = 'name'
            ) as has_name" 
            | get has_name.0
        )
        
        if not $has_name {
            error make {msg: $"Type table ($schema).($type_table) does not have a 'name' column. Use --search-key instead."}
        }
    }
    
    # Build WHERE clause
    let where_clause = if ($search_key | is-not-empty) {
        $"search_key = '($search_key)'"
    } else {
        $"name = '($name)'"
    }
    
    # Execute query
    let result = (psql exec $"SELECT * FROM ($schema).($type_table) WHERE ($where_clause) AND is_revoked = false")
    
    if ($result | is-empty) {
        let field = if ($search_key | is-not-empty) { "search_key" } else { "name" }
        let value = if ($search_key | is-not-empty) { $search_key } else { $name }
        error make {msg: $"Type with ($field) '($value)' not found in ($schema).($type_table)"}
    } else {
        $result | first
    }
}


# Get table name and UUID for a given UUID
#
# Looks up which table a UUID belongs to and returns both the table name
# and UUID as a nushell record. This is a core chuck-stack function that
# enables flexible references between any records.
#
# When you already know the table name (e.g., from a list command), you can
# avoid this database lookup by building the record directly in nushell.
#
# Examples:
#   psql get-table-name-uu "12345678-1234-5678-9012-123456789abc"
#   # Returns: {table_name: "stk_project", uu: "12345678-1234-5678-9012-123456789abc"}
#
#   let uuid = (project list | get uu.0)
#   psql get-table-name-uu $uuid
#
# Returns: Record with table_name and uu fields
# Error: If UUID not found in any table
export def "psql get-table-name-uu" [
    uuid: string  # The UUID to look up
] {
    let result = (
        psql exec $"SELECT api.get_table_name_uu_json\('($uuid)') as result"
    )
    
    if ($result | is-empty) {
        error make {msg: $"UUID not found: ($uuid)"}
    }
    
    # Parse the JSONB result from PostgreSQL into a nushell record
    let parsed = ($result.0.result | from json)
    
    # Check if the result contains an error
    if ("error" in ($parsed | columns)) and ($parsed.error? | is-not-empty) {
        error make {msg: $"UUID not found: ($uuid) - ($parsed.error)"}
    }
    
    return $parsed
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
#   event list | elaborate                      # Default columns: name, description, search_key
#   event list | elaborate --detail             # All columns from resolved records  
#   todo list | elaborate name created          # Select specific columns
#   request list | where status == "OPEN" | elaborate type_enum name
#
# Parameters:
# - ...columns: Specific columns to include in resolved records (optional)
# - --detail: Include all columns from resolved records (overrides column selection)
#
# Returns: Original table with additional _resolved columns for each UUID reference
# Note: Resolution happens dynamically by querying the referenced tables directly
export def elaborate [
    ...columns: string  # Specific columns to include in resolved records
    --detail(-d)        # Include all columns from resolved records
    --table            # Always return a table format (useful for scripts)
] {
    let input = $in
    
    # Return empty if input is empty
    if ($input | is-empty) {
        return $input
    }
    
    # Normalize input - convert single record to table
    let normalized_input = if ($input | describe | str starts-with "record") {
        [$input]
    } else {
        $input
    }
    
    mut result = $normalized_input
    
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
                        # Build SELECT clause based on user input
                        let select_clause = if $detail {
                            "*"
                        } else if ($columns | is-empty) {
                            # Default columns when none specified (same as lines command)
                            "name, description, search_key"
                        } else {
                            $columns | str join ", "
                        }
                        
                        # Query the table directly using psql
                        let query = $"SELECT ($select_clause) FROM api.($ref.table_name) WHERE uu = '($ref.uu)'"
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
                if ($uu_value != null) and ($uu_value != "") and (($uu_value | str downcase) != "null") {
                    # Look up table name using PostgreSQL function
                    let lookup_result = (psql exec $"SELECT api.get_table_name_uu_json\('($uu_value)'::uuid)" | first)
                    let ref = ($lookup_result | get "get_table_name_uu_json")
                    
                    if ($ref != null) and ($ref.table_name? != null) and ($ref.table_name != "") and ($ref.uu? != null) and ($ref.uu != "") {
                        # Use psql to query the table directly
                        try {
                            # Build SELECT clause based on user input
                            let select_clause = if $detail {
                                "*"
                            } else if ($columns | is-empty) {
                                # Default columns when none specified (same as lines command)
                                "name, description, search_key"
                            } else {
                                $columns | str join ", "
                            }
                            
                            # Query the table directly using psql
                            let query = $"SELECT ($select_clause) FROM api.($ref.table_name) WHERE uu = '($ref.uu)'"
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
    
    # Return in the same format as input (unless --table is specified)
    if $table {
        $result  # Always return table format
    } else if ($input | describe | str starts-with "record") {
        $result | first  # Return single record if input was a record
    } else {
        $result  # Return table if input was a table
    }
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

# Helper function to check if a column exists in a table
def column-exists [column: string, table: string] {
    let query = $"
        SELECT EXISTS \(
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'api' 
            AND table_name = '($table)' 
            AND column_name = '($column)'
        ) as exists
    "
    let result = (psql exec $query)
    if ($result | is-empty) {
        false
    } else {
        $result | get exists.0 | into bool ext
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
# - Allows column selection with default to [name, description, search_key] when available
#
# Note: Column selection is built-in to simplify working with nested arrays
# Compare: project list | lines | update lines {|it| $it.lines | select name}
# With:    project list | lines name        # This is much better!
#
# Examples:
# > project list | lines                    # Default columns: name, description, search_key
# > project list | lines --detail           # All columns (select *)
# > project list | lines --all              # Include revoked line records
# > project list | lines name type_uu       # Specific columns
# > todo list | lines name description created  # Custom column selection
#
# Parameters:
# - ...columns: Specific columns to include in line records (optional)
# - --detail: Include all columns from line records (overrides column selection)
# - --all: Include revoked line records (by default only active records are shown)
#
# Returns:
# - Original table with an additional 'lines' column
# - The 'lines' column contains an array of line records or null if no line table exists
# - Line records include only requested columns (or defaults when applicable)
#
# Error handling:
# - Returns null if no line table exists for the given table_name
# - Returns empty array if line table exists but no lines are found
# - Returns error object if database query fails
export def lines [
    ...columns: string  # Specific columns to include in line records
    --detail           # Include all columns (select *)
    --all              # Include revoked line records
    --table            # Always return a table format (useful for scripts)
] {
    let input = $in
    
    # Return empty if no input
    if ($input | is-empty) {
        return []
    }
    
    # Normalize input - convert single record to table
    let normalized_input = if ($input | describe | str starts-with "record") {
        [$input]
    } else {
        $input
    }
    
    # Build cache of table existence checks upfront
    # This avoids mutable variable capture in closures
    let unique_tables = $normalized_input 
        | where { |record| 'table_name' in ($record | columns) }
        | get table_name
        | uniq
    
    let table_cache = $unique_tables | reduce -f {} { |table_name, acc|
        let line_table_name = $"($table_name)_line"
        $acc | insert $line_table_name (table-exists $line_table_name)
    }
    
    # Process each record using the immutable cache
    let result = $normalized_input | each { |record|
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
                # Build SELECT clause based on user input
                let select_clause = if ($columns | is-empty) {
                    "*"
                } else {
                    $columns | str join ", "
                }
                
                # Add revoked filter based on --all flag
                let revoked_clause = if $all { "" } else { " AND is_revoked = false" }
                let lines_query = $"SELECT ($select_clause) FROM api.($line_table_name) WHERE header_uu = '($record.uu)'($revoked_clause) ORDER BY created"
                let lines_data = (psql exec $lines_query)
                
                # If no columns specified and not --detail, filter to default columns
                let final_data = if (not $detail) and ($columns | is-empty) and (not ($lines_data | is-empty)) {
                    let available_columns = ($lines_data | columns)
                    let default_cols = ["name", "description", "search_key"]
                    let cols_to_keep = $default_cols | where { |col| $col in $available_columns }
                    
                    if ($cols_to_keep | is-empty) {
                        $lines_data
                    } else {
                        $lines_data | select ...$cols_to_keep
                    }
                } else {
                    $lines_data
                }
                
                # Add lines column with fetched data
                $record | insert lines $final_data
            } catch {
                # Error occurred, return error object
                $record | insert lines { error: $"Failed to fetch lines from ($line_table_name): ($in)" }
            }
        } else {
            # No line table exists, add null column
            $record | insert lines null
        }
    }
    
    # Return in the same format as input (unless --table is specified)
    if $table {
        $result  # Always return table format
    } else if ($input | describe | str starts-with "record") {
        $result | first  # Return single record if input was a record
    } else {
        $result  # Return table if input was a table
    }
}

# Add a 'children' column to records, fetching child records via parent_uu
#
# This command enriches piped records with a 'children' column containing
# their child records for tables that follow the parent-child pattern.
# The parent-child pattern enables hierarchical relationships within the
# same table (e.g., sub-projects, organizational hierarchies).
#
# Purpose:
# - Automatically detects if a table has a 'parent_uu' column
# - Fetches all child records where parent_uu matches the record's uu
# - Adds a 'children' column containing the full child records
# - Allows column selection with default to [name, description, type_uu] when available
#
# The command gracefully handles tables without parent_uu support by
# returning an empty array, maintaining consistency with the 'lines' command.
#
# Examples:
# > project list | where name == "Q4 Initiative" | children
# > project list | first | children name description created
# > project list | first | children --detail
# > project list | children | select name {|r| $r.children | length}
#
# Parameters:
# - ...columns: Specific columns to include in child records (optional)
# - --detail: Include all columns from child records (overrides column selection)
#
# Returns:
# - Original records with an additional 'children' column
# - The 'children' column contains an array of child records (empty if none exist)
# - Child records include only requested columns (or defaults when applicable)
#
# Error handling:
# - Returns empty array [] if table has no parent_uu column
# - Returns empty array [] if no children are found
# - Returns error object if database query fails
export def children [
    ...columns: string  # Specific columns to include in child records
    --detail(-d)        # Include all columns (select *)
    --table            # Always return a table format (useful for scripts)
] {
    let input = $in
    
    # Return empty if no input
    if ($input | is-empty) {
        return []
    }
    
    # Normalize input - not needed because 'each' works on both records and tables
    
    # Process each record
    let result = $input | each { |record|
        # Check if record has required columns
        if 'table_name' not-in ($record | columns) or 'uu' not-in ($record | columns) {
            return $record | insert children []
        }
        
        let table_name = $record.table_name
        
        # Check if table has parent_uu column
        let has_parent_uu = (column-exists "parent_uu" $table_name)
        
        if $has_parent_uu {
            # Table has parent_uu column, fetch children
            try {
                # Build SELECT clause based on user input
                let select_clause = if ($columns | is-empty) {
                    "*"
                } else {
                    $columns | str join ", "
                }
                
                let children_query = $"
                    SELECT ($select_clause) 
                    FROM api.($table_name) 
                    WHERE parent_uu = '($record.uu)' 
                    AND is_revoked = false
                    ORDER BY created
                "
                let children_data = (psql exec $children_query)
                
                # If no columns specified and not --detail, filter to default columns
                let final_data = if (not $detail) and ($columns | is-empty) and (not ($children_data | is-empty)) {
                    let available_columns = ($children_data | columns)
                    let default_cols = ["name", "description", "type_uu"]
                    let cols_to_keep = $default_cols | where { |col| $col in $available_columns }
                    
                    if ($cols_to_keep | is-empty) {
                        $children_data
                    } else {
                        $children_data | select ...$cols_to_keep
                    }
                } else {
                    $children_data
                }
                
                # Add children column with fetched data
                $record | insert children $final_data
            } catch {
                # Error occurred, return error object
                $record | insert children { error: $"Failed to fetch children from ($table_name): ($in)" }
            }
        } else {
            # No parent_uu column exists, add empty array
            $record | insert children []
        }
    }
    
    # Handle --table flag for consistent output format
    if $table and ($input | describe | str starts-with "record") {
        [$result]  # Wrap single record in table if --table specified
    } else {
        $result  # Otherwise preserve input format (each preserves format naturally)
    }
}


# Generic command to append related records using table_name_uu_json pattern
#
# This is a generic implementation that allows any module to add a column
# containing related records that reference the input records via table_name_uu_json.
# This pattern is used by tags, requests, events, and potentially other modules.
#
# The command enriches piped records by:
# - Building a table_name_uu_json value for each record: {"table_name": "xxx", "uu": "yyy"}
# - Querying the specified table for records where table_name_uu_json matches
# - Adding a new column with the fetched records
#
# This is typically wrapped by module-specific commands like:
# - stk_tag: tags command
# - stk_request: requests command  
# - stk_event: events command
#
# Requirements:
# - Input records must have 'table_name' and 'uu' columns
# - Target table must have 'table_name_uu_json' and 'is_revoked' columns
#
# Examples (when wrapped by module commands):
# # From stk_tag module
# export def tags [...columns: string --detail] {
#     $in | psql append-table-name-uu-json "stk_tag" "tags" ["record_json", "search_key", "description", "type_uu"] ...$columns --detail=$detail
# }
#
# Parameters:
# - table: The table name to query (e.g., "stk_tag", "stk_request")
# - column: The column name to add to results (e.g., "tags", "requests")
# - default_columns: List of columns to return by default when no columns specified
# - ...columns: User-specified columns to return
# - --detail: Return all columns from the related records
export def "psql append-table-name-uu-json" [
    table: string               # Table to query for related records
    column: string              # Name of column to add to results
    default_columns: list       # Default columns when none specified
    ...columns: string          # Specific columns to include
    --detail(-d)                # Include all columns (select *)
] {
    let input = $in
    
    # Return empty if no input
    if ($input | is-empty) {
        return []
    }
    
    # Process each record
    let result = $input | each { |record|
        # Check if record has required columns
        if 'table_name' not-in ($record | columns) or 'uu' not-in ($record | columns) {
            return $record | insert $column null
        }
        
        let table_name = $record.table_name
        let record_uu = $record.uu
        
        try {
            # Build the table_name_uu_json value for searching
            let table_name_uu_json = {table_name: $table_name, uu: $record_uu} | to json
            
            # Build SELECT clause based on user input
            let select_clause = if ($columns | is-empty) {
                "*"
            } else {
                $columns | str join ", "
            }
            
            # Query for related records using standard is_revoked pattern
            let query = $"SELECT ($select_clause) FROM api.($table) WHERE table_name_uu_json = '($table_name_uu_json)' AND is_revoked = false ORDER BY created"
            let data = (psql exec $query)
            
            # If no columns specified and not --detail, filter to default columns
            let final_data = if (not $detail) and ($columns | is-empty) and (not ($data | is-empty)) {
                let available_columns = ($data | columns)
                let cols_to_keep = $default_columns | where { |col| $col in $available_columns }
                
                if ($cols_to_keep | is-empty) {
                    $data
                } else {
                    $data | select ...$cols_to_keep
                }
            } else {
                $data
            }
            
            # Add column with fetched data
            $record | insert $column $final_data
        } catch {
            # Error occurred, return error object
            $record | insert $column { error: $"Failed to fetch ($column) for ($table_name):($record_uu): ($in)" }
        }
    }
    
    $result
}

# Add links data to records (for use in pipelines)
#
# Enriches records with their associated links in a new 'links' column.
# Similar to the 'lines' command but for many-to-many relationships via stk_link.
#
# For BIDIRECTIONAL links, the relationship appears from both perspectives
# regardless of which record was the source when the link was created.
# This provides intuitive navigation where bidirectional truly means "works both ways".
#
# Direction flags:
# - Default (no flags): Shows all relationships (bidirectional links appear from both sides)
# - --outgoing: Shows outgoing relationships (including bidirectional as outgoing)
# - --incoming: Shows incoming relationships (including bidirectional as incoming)
#
# Examples:
#   # Add links to contacts (shows all relationships)
#   contact list | links
#   
#   # Show only outgoing relationships
#   contact list | links --outgoing
#   
#   # Include all columns from linked records
#   contact list | links --detail
#   
#   # Include revoked links
#   contact list | links --all
#
# Error handling:
# - Returns empty array if no links exist
# - Returns empty array if input has no uu/table_name
export def links [
    --detail(-d)           # Include all columns from linked records
    --all(-a)              # Include revoked links
    --incoming             # Show incoming relationships (including bidirectional)
    --outgoing             # Show outgoing relationships (including bidirectional)
] {
    let input = $in
    
    # Return empty if no input
    if ($input | is-empty) {
        return []
    }
    
    # Normalize input - convert single record to table
    let normalized_input = if ($input | describe | str starts-with "record") {
        [$input]
    } else {
        $input
    }
    
    # Capture flags for use in closure
    let show_detail = $detail
    let show_all = $all
    let show_incoming = $incoming
    let show_outgoing = $outgoing
    
    # Process each record
    let result = $normalized_input | each { |record|
        # Skip if no uu or table_name
        if (not ('uu' in ($record | columns))) or (not ('table_name' in ($record | columns))) {
            return ($record | insert links [])
        }
        
        # Build table_name_uu JSON for SQL comparison
        let record_json = ({table_name: $record.table_name, uu: $record.uu} | to json)
        
        # Build query with UNION for different directions
        let revoked_clause = if $show_all { "" } else { " AND l.is_revoked = false" }
        
        # Build queries based on symmetric bidirectional logic:
        # - Default: all links (both directions for bidirectional)
        # - --outgoing: outgoing + bidirectional as target (flipped)
        # - --incoming: incoming + bidirectional as source (flipped)
        let queries = []
        
        # Determine which queries to include based on flags
        let include_outgoing = not $show_incoming or $show_outgoing or (not $show_incoming and not $show_outgoing)
        let include_incoming = $show_incoming or (not $show_incoming and not $show_outgoing)
        
        # Query 1: Outgoing links (record is source)
        let queries = if $include_outgoing {
            $queries | append $"
                SELECT 
                    l.uu as link_uu,
                    l.description as link_description,
                    l.target_table_name_uu_json as linked_json,
                    t.name as link_type,
                    t.type_enum as type_enum,
                    'outgoing' as direction
                FROM api.stk_link l
                JOIN api.stk_link_type t ON l.type_uu = t.uu
                WHERE l.source_table_name_uu_json = '($record_json)'::jsonb($revoked_clause)
            "
        } else { $queries }
        
        # Query 2: Incoming links (record is target) 
        let queries = if $include_incoming {
            $queries | append $"
                SELECT 
                    l.uu as link_uu,
                    l.description as link_description,
                    l.source_table_name_uu_json as linked_json,
                    t.name as link_type,
                    t.type_enum as type_enum,
                    'incoming' as direction
                FROM api.stk_link l
                JOIN api.stk_link_type t ON l.type_uu = t.uu
                WHERE l.target_table_name_uu_json = '($record_json)'::jsonb($revoked_clause)
            "
        } else { $queries }
        
        # Query 3: Bidirectional links from opposite perspective
        # For --outgoing: add bidirectional where record is target (shows as outgoing)
        let queries = if $show_outgoing and not $show_incoming {
            $queries | append $"
                SELECT 
                    l.uu as link_uu,
                    l.description as link_description,
                    l.source_table_name_uu_json as linked_json,
                    t.name as link_type,
                    t.type_enum as type_enum,
                    'outgoing \(bidirectional)' as direction
                FROM api.stk_link l
                JOIN api.stk_link_type t ON l.type_uu = t.uu
                WHERE l.target_table_name_uu_json = '($record_json)'::jsonb
                    AND t.type_enum = 'BIDIRECTIONAL'($revoked_clause)
            "
        } else { $queries }
        
        # Query 4: Bidirectional links from opposite perspective  
        # For --incoming: add bidirectional where record is source (shows as incoming)
        let queries = if $show_incoming and not $show_outgoing {
            $queries | append $"
                SELECT 
                    l.uu as link_uu,
                    l.description as link_description,
                    l.target_table_name_uu_json as linked_json,
                    t.name as link_type,
                    t.type_enum as type_enum,
                    'incoming \(bidirectional)' as direction
                FROM api.stk_link l
                JOIN api.stk_link_type t ON l.type_uu = t.uu
                WHERE l.source_table_name_uu_json = '($record_json)'::jsonb
                    AND t.type_enum = 'BIDIRECTIONAL'($revoked_clause)
            "
        } else { $queries }
        
        # Combine queries with UNION and order by created
        let links_query = if ($queries | length) > 1 {
            $"($queries | str join ' UNION ') ORDER BY link_uu"
        } else if ($queries | length) == 1 {
            $queries.0
        } else {
            return ($record | insert links [])
        }
        
        try {
            let links_data = psql exec $links_query
            
            # Return empty array if no links
            if ($links_data | is-empty) {
                return ($record | insert links [])
            }
            
            # For each link, fetch the linked record data
            let enriched_links = $links_data | each { |link|
                # Parse the linked JSON to get table_name and uu
                let linked_info = $link.linked_json
                let linked_table = $linked_info.table_name
                let linked_uu = $linked_info.uu
                
                # Build query for linked record - use same default columns as lines
                let select_clause = if $show_detail {
                    "*"
                } else {
                    # Default columns - same as lines command
                    "name, description, search_key"
                }
                
                # Fetch linked record
                try {
                    let linked_query = $"SELECT ($select_clause) FROM api.($linked_table) WHERE uu = '($linked_uu)'"
                    let linked_data = psql exec $linked_query | first
                    
                    # Return merged data with link metadata at the end
                    $linked_data | merge ($link | reject linked_json | insert linked_table $linked_table | insert linked_uu $linked_uu)
                } catch {
                    # If fetch fails, just return basic link info
                    $link | reject linked_json | insert linked_table $linked_table | insert linked_uu $linked_uu
                }
            }
            
            $record | insert links $enriched_links
        } catch {
            # Error occurred, return empty links
            $record | insert links []
        }
    }
    
    $result
}

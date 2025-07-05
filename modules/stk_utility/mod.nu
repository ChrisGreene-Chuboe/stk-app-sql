# STK Utility Module
# Provides shared utility functions for chuck-stack modules

# Extract uu and table_name from string, record, or table format
#
# This helper function extracts uu and table_name from various input types into a consistent table format
# with 'uu' and optional 'table_name' columns. This allows modules to handle input
# uniformly and sets the foundation for future multi-record support.
#
# Consuming modules currently use only the first record (.0) from the returned table.
#
# Note: Also accepts list<any> type which occurs when nushell can't infer table schema.
# This is common with PostgreSQL query results. See: https://github.com/nushell/nushell/discussions/10897
#
# Examples:
#   "12345678-1234-5678-9012-123456789abc" | extract-uu-table-name
#   # Returns: table with one row: [{uu: "12345678-1234-5678-9012-123456789abc", table_name: null}]
#
#   {uu: "12345678-1234-5678-9012-123456789abc", name: "test"} | extract-uu-table-name
#   # Returns: table with one row: [{uu: "12345678-1234-5678-9012-123456789abc", table_name: null}]
#
#   {uu: "12345678-1234-5678-9012-123456789abc", table_name: "stk_project", name: "test"} | extract-uu-table-name
#   # Returns: table with one row: [{uu: "12345678-1234-5678-9012-123456789abc", table_name: "stk_project"}]
#
#   project list | extract-uu-table-name  # Returns full table (even if typed as list<any>)
#   # Returns: table with all rows: [{uu: "uuid1", table_name: "stk_project"}, {uu: "uuid2", table_name: "stk_project"}, ...]
#
# Returns: Table with 'uu' and 'table_name' columns, or empty table if input is empty
# Error: Throws error if any record/table row lacks 'uu' field
export def extract-uu-table-name [] {
    let input = $in
    
    if ($input | is-empty) {
        return []
    }
    
    let input_type = ($input | describe)
    
    if $input_type == "string" {
        # String UUID - return as single-row table
        return [{uu: $input, table_name: null}]
    } else if ($input_type | str starts-with "record") {
        # Single record - extract uu and optional table_name
        let uuid = $input.uu?
        if ($uuid | is-empty) {
            error make { msg: "Record must contain 'uu' field" }
        }
        let table_name = $input.table_name?
        return [{uu: $uuid, table_name: $table_name}]
    } else if (($input_type | str starts-with "table") or ($input_type == "list<any>")) {
        # Table or list<any> - normalize each row
        # Note: list<any> is common when nushell can't infer table schema, especially
        # with PostgreSQL results. See: https://github.com/nushell/nushell/discussions/10897
        if ($input | length) == 0 {
            return []
        }
        
        # Process all rows
        return ($input | each { |row|
            let uuid = $row.uu?
            if ($uuid | is-empty) {
                error make { msg: "Table row must contain 'uu' field" }
            }
            let table_name = $row.table_name?
            {uu: $uuid, table_name: $table_name}
        })
    } else {
        error make { msg: $"Input must be a string UUID, record, or table with 'uu' field, got ($input_type)" }
    }
}

# Extract a single UUID from piped input with validation
#
# This helper reduces the repetitive UUID extraction pattern used in commands like
# 'request get' and 'request revoke'. It handles string UUIDs, records, and tables,
# always returning a single UUID string.
#
# Examples:
#   "uuid-string" | extract-single-uu
#   {uu: "uuid", name: "test"} | extract-single-uu
#   request list | first | extract-single-uu
#
# Returns: String UUID
# Error: Throws error if input is empty or no valid UUID found
export def extract-single-uu [
    --error-msg: string = "UUID required via piped input"
] {
    let piped_input = $in
    
    if ($piped_input | is-empty) {
        error make { msg: $error_msg }
    }
    
    # Handle string UUID directly
    if ($piped_input | describe) == "string" {
        return $piped_input
    }
    
    # For records/tables, use extract-uu-table-name
    let extracted = ($piped_input | extract-uu-table-name)
    if ($extracted | is-empty) {
        error make { msg: "No valid UUID found in input" }
    }
    $extracted.0.uu
}

# Extract attachment data from piped input or --attach parameter
#
# This helper simplifies the common pattern of extracting attachment data
# from either piped input or an --attach parameter. Used in commands that
# support attaching records to other records.
#
# The function returns the exact same structure as the original code:
# - null if no attachment
# - {uu: string, table_name: string|null} if attachment found
#
# Examples:
#   project list | first | extract-attach-from-input
#   "" | extract-attach-from-input "uuid-string"
#
# Returns: Record with 'uu' and 'table_name' fields, or null
export def extract-attach-from-input [
    attach?: string  # The --attach parameter value (optional)
] {
    let piped_input = $in
    
    if ($piped_input | is-empty) {
        # No piped input, use --attach parameter
        if ($attach == null or ($attach | is-empty)) {
            null
        } else {
            {uu: $attach, table_name: null}
        }
    } else {
        # Extract uu and table_name, then get first row
        let extracted = ($piped_input | extract-uu-table-name)
        if ($extracted | is-empty) {
            null
        } else {
            $extracted.0
        }
    }
}

# Extract UUID from either piped input or --uu parameter
#
# This helper consolidates the common pattern of accepting a UUID from either:
# - Piped input (string, record with 'uu' field, or table)
# - --uu parameter
#
# This reduces boilerplate in commands that support dual UUID input methods.
#
# Examples:
#   # With piped input
#   "uuid-string" | extract-uu-with-param
#   {uu: "uuid", name: "test"} | extract-uu-with-param
#   
#   # With --uu parameter
#   "" | extract-uu-with-param "uuid-from-param"
#   
#   # With custom error message
#   $in | extract-uu-with-param $uu --error-msg "Tag UUID required"
#
# Returns: String UUID
# Error: Throws error if no UUID provided via either method
export def extract-uu-with-param [
    uu?: string  # The --uu parameter value
    --error-msg: string = "UUID required via piped input or --uu parameter"
] {
    let piped_input = $in
    
    if ($piped_input | is-empty) {
        if ($uu | is-empty) {
            error make { msg: $error_msg }
        }
        $uu
    } else {
        ($piped_input | extract-single-uu --error-msg $error_msg)
    }
}

# Parse and validate JSON string with consistent error handling
#
# This helper provides standardized JSON validation across chuck-stack modules.
# It ensures JSON can be parsed and returns either the parsed data or the original
# string, depending on the return-parsed flag. This creates a consistent pattern
# for modules that accept --json parameters.
#
# The standard pattern for modules is:
# 1. Accept --json parameter as string
# 2. Validate it can be parsed (syntax check)
# 3. Pass the original string to database for schema validation
#
# Examples:
#   # Basic validation (returns original string for database)
#   let json_string = ('{"key": "value"}' | parse-json)
#   
#   # Get parsed data for inspection
#   let parsed = ('{"key": "value"}' | parse-json --return-parsed)
#   
#   # Handle empty input with default
#   let record_json = ($json | parse-json --default "{}")
#   
#   # One-liner for modules with optional JSON
#   let record_json = try { $json | parse-json --default "{}" } catch { error make { msg: $in.msg } }
#   
#   # Handle invalid JSON
#   try {
#       '{invalid json}' | parse-json
#   } catch { |err|
#       print $err.msg  # "Invalid JSON format"
#   }
#
# Returns: Original JSON string (default) or parsed data (with --return-parsed)
# Error: Throws standardized error if JSON cannot be parsed
export def parse-json [
    --return-parsed  # Return parsed data instead of original string
    --default: string = "{}"  # Default value when input is empty (typically "{}")
] {
    let json_string = $in
    
    # Handle empty input with default if specified
    if ($json_string | is-empty) {
        if ($default | is-not-empty) {
            return $default  # Return default JSON string
        } else {
            error make { msg: "JSON string cannot be empty" }
        }
    }
    
    # Attempt to parse JSON for validation
    let parsed = try {
        $json_string | from json
    } catch {
        error make { msg: "Invalid JSON format" }
    }
    
    # Return based on flag
    if $return_parsed {
        $parsed
    } else {
        $json_string  # Return original string for database
    }
}
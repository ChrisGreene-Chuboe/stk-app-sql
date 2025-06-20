# STK Utility Module
# Provides shared utility functions for chuck-stack modules

# Normalize UUID input from string, record, or table format
#
# This helper function normalizes various input types into a consistent table format
# with 'uu' and optional 'table_name' columns. This allows modules to handle input
# uniformly and sets the foundation for future multi-record support.
#
# Consuming modules currently use only the first record (.0) from the returned table.
#
# Examples:
#   "12345678-1234-5678-9012-123456789abc" | normalize-uuid-input
#   # Returns: table with one row: [{uu: "12345678-1234-5678-9012-123456789abc", table_name: null}]
#
#   {uu: "12345678-1234-5678-9012-123456789abc", name: "test"} | normalize-uuid-input
#   # Returns: table with one row: [{uu: "12345678-1234-5678-9012-123456789abc", table_name: null}]
#
#   {uu: "12345678-1234-5678-9012-123456789abc", table_name: "stk_project", name: "test"} | normalize-uuid-input
#   # Returns: table with one row: [{uu: "12345678-1234-5678-9012-123456789abc", table_name: "stk_project"}]
#
#   project list | normalize-uuid-input  # Returns full table
#   # Returns: table with all rows: [{uu: "uuid1", table_name: "stk_project"}, {uu: "uuid2", table_name: "stk_project"}, ...]
#
# Returns: Table with 'uu' and 'table_name' columns, or empty table if input is empty
# Error: Throws error if any record/table row lacks 'uu' field
export def normalize-uuid-input [] {
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
    } else if ($input_type | str starts-with "table") {
        # Table - normalize each row
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
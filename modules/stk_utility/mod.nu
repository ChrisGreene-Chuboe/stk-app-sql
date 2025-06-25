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
# STK Request Module - Enhanced with UUID Input Pattern
# Example implementation showing string/record UUID input support

# Module Constants
const STK_SCHEMA = "api"
const STK_TABLE_NAME = "stk_request"
const STK_REQUEST_COLUMNS = [name, description, table_name_uu_json, is_processed, record_json]

# Import UUID input utilities
use ../stk_utility/uuid_input.nu [normalize-uuid-input, extract-uuid, extract-table-name]

# Create a new request with optional attachment to another record
#
# This enhanced version accepts either string UUIDs or records with 'uu' field.
# When a record is provided, it can include 'table_name' to avoid database lookup.
#
# Accepts piped input:
#   string - UUID of record to attach this request to
#   record - Record containing 'uu' field (and optionally 'table_name')
#
# Examples:
#   # Traditional string UUID
#   "12345678-1234-5678-9012-123456789abc" | .append request "bug-fix" --description "Fix critical bug"
#   
#   # New record input - no more .0.uu extraction needed!
#   project list | get 0 | .append request "update" --description "Update project"
#   
#   # Record with table_name for performance
#   {uu: $some_uuid, table_name: "stk_project"} | .append request "review"
#   
#   # Works with any record containing 'uu'
#   todo list | where name == "important" | get 0 | .append request "follow-up"
#
# Returns: The UUID of the newly created request record
export def ".append request" [
    name: string                    # The name/topic of the request
    --description(-d): string = ""  # Description of the request (optional)
    --attach(-a): string           # UUID of record to attach (alternative to piped input)
    --json(-j): string             # Optional JSON data to store in record_json field
] {
    let piped_input = $in
    let table = $"($STK_SCHEMA).($STK_TABLE_NAME)"
    
    # Normalize input - now accepts both string and record!
    let normalized = if ($piped_input | is-empty) {
        if ($attach | is-empty) { 
            null 
        } else { 
            # --attach is always a string, normalize it
            $attach | normalize-uuid-input
        }
    } else {
        $piped_input | normalize-uuid-input
    }
    
    # Extract UUID and table_name from normalized input
    let attach_uuid = $normalized | extract-uuid
    let table_name = $normalized | extract-table-name
    
    # Handle json parameter
    let record_json = if ($json | is-empty) { "'{}'" } else { $"'($json)'" }
    
    if ($attach_uuid | is-empty) {
        # Standalone request - no attachment
        let sql = $"INSERT INTO ($table) \(name, description, record_json) VALUES \('($name)', '($description)', ($record_json)::jsonb) RETURNING uu"
        psql exec $sql
    } else {
        # Request with attachment
        # If table_name was provided, we could optimize by avoiding the lookup
        # For now, still use get_table_name_uu_json for consistency
        let sql = $"INSERT INTO ($table) \(name, description, table_name_uu_json, record_json) VALUES \('($name)', '($description)', ($STK_SCHEMA).get_table_name_uu_json\('($attach_uuid)'), ($record_json)::jsonb) RETURNING uu"
        
        # Future optimization when table_name is provided:
        # if ($table_name | is-not-empty) {
        #     # Build table_name_uu_json directly without database lookup
        #     let table_name_uu_json = {table_name: $table_name, uu: $attach_uuid} | to json
        #     # Use direct value instead of function call
        # }
        
        psql exec $sql
    }
}

# Example of how other commands would be updated
export def "request get" [
    --detail(-d)  # Include detailed type information
] {
    # Now accepts both string UUID and record
    let normalized = $in | normalize-uuid-input
    let uu = $normalized | extract-uuid
    
    if ($uu | is-empty) {
        error make { msg: "UUID required via piped input (string or record with 'uu' field)" }
    }
    
    if $detail {
        psql detail-record $STK_SCHEMA $STK_TABLE_NAME $uu
    } else {
        psql get-record $STK_SCHEMA $STK_TABLE_NAME $STK_REQUEST_COLUMNS $uu
    }
}
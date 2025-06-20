# STK Request Module - Test version with UUID input enhancement
# This is a copy of mod.nu enhanced to accept both string and record inputs

# Module Constants
const STK_SCHEMA = "api"
const STK_TABLE_NAME = "stk_request"
const STK_REQUEST_COLUMNS = [name, description, table_name_uu_json, is_processed, record_json]

# Import UUID input utilities
use ../stk_utility/uuid_input.nu [normalize-uuid-input, extract-uuid, extract-table-name]

# Create a new request with optional attachment to another record
#
# Enhanced to accept both string UUIDs and records with 'uu' field
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
    
    # Extract UUID from normalized input
    let attach_uuid = $normalized | extract-uuid
    
    # Handle json parameter
    let record_json = if ($json | is-empty) { "'{}'" } else { $"'($json)'" }
    
    if ($attach_uuid | is-empty) {
        # Standalone request - no attachment
        let sql = $"INSERT INTO ($table) \(name, description, record_json) VALUES \('($name)', '($description)', ($record_json)::jsonb) RETURNING uu"
        psql exec $sql
    } else {
        # Request with attachment
        let sql = $"INSERT INTO ($table) \(name, description, table_name_uu_json, record_json) VALUES \('($name)', '($description)', ($STK_SCHEMA).get_table_name_uu_json\('($attach_uuid)'), ($record_json)::jsonb) RETURNING uu"
        psql exec $sql
    }
}

# List the 10 most recent requests from the chuck-stack system
export def "request list" [
    --detail(-d)  # Include detailed type information for all requests
    --all(-a)     # Include revoked requests
] {
    # Build complete arguments array including flags
    let args = [$STK_SCHEMA, $STK_TABLE_NAME] | append $STK_REQUEST_COLUMNS
    
    # Add --all flag to args if needed
    let args = if $all { $args | append "--all" } else { $args }
    
    # Choose command and execute with spread - no nested if/else!
    if $detail {
        psql list-records-with-detail ...$args
    } else {
        psql list-records ...$args
    }
}

# Retrieve a specific request by its UUID
#
# Enhanced to accept both string UUIDs and records with 'uu' field
#
# Accepts piped input:
#   string - The UUID of the request to retrieve
#   record - Record containing 'uu' field
#
# Examples:
#   "12345678-1234-5678-9012-123456789abc" | request get
#   request list | get 0 | request get
#   $request_record | request get --detail
#
# Returns: Request details
export def "request get" [
    --detail(-d)  # Include detailed type information
] {
    let input = $in
    
    if ($input | is-empty) {
        error make { msg: "UUID required via piped input (string or record with 'uu' field)" }
    }
    
    # Normalize and extract UUID
    let normalized = $input | normalize-uuid-input
    let uu = $normalized | extract-uuid
    
    if ($uu | is-empty) {
        error make { msg: "Could not extract UUID from input" }
    }
    
    if $detail {
        psql detail-record $STK_SCHEMA $STK_TABLE_NAME $uu
    } else {
        psql get-record $STK_SCHEMA $STK_TABLE_NAME $STK_REQUEST_COLUMNS $uu
    }
}

# Mark a request as processed
export def "request process" [
    uu: string  # The UUID of the request to mark as processed
] {
    psql process-record $STK_SCHEMA $STK_TABLE_NAME $uu
}

# Revoke a request by setting its revoked timestamp
#
# Enhanced to accept both string UUIDs and records with 'uu' field
#
# Accepts piped input: 
#   string - The UUID of the request to revoke
#   record - Record containing 'uu' field
#
# Examples:
#   request list | where name == "obsolete" | get 0 | request revoke
#   "12345678-1234-5678-9012-123456789abc" | request revoke
export def "request revoke" [] {
    let input = $in
    
    if ($input | is-empty) {
        error make { msg: "UUID required via piped input (string or record with 'uu' field)" }
    }
    
    # Normalize and extract UUID
    let normalized = $input | normalize-uuid-input
    let target_uuid = $normalized | extract-uuid
    
    if ($target_uuid | is-empty) {
        error make { msg: "Could not extract UUID from input" }
    }
    
    psql revoke-record $STK_SCHEMA $STK_TABLE_NAME $target_uuid
}

# List available request types
export def "request types" [] {
    psql list-types $STK_SCHEMA $STK_TABLE_NAME
}
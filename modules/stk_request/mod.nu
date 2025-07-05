# STK Request Module
# This module provides commands for working with stk_request table

# Import utility functions
use ../stk_utility *

# Module Constants
const STK_SCHEMA = "api"
const STK_TABLE_NAME = "stk_request"
const STK_REQUEST_COLUMNS = [name, description, table_name_uu_json, is_processed, record_json]

# Request module overview
export def "request" [] {
    print "Requests track follow-up actions and hierarchical work items.
Requests can be attached to any record and organized in parent-child trees.

The request system forms the foundation for todos, approvals, and workflows.
Use .append request pattern to attach requests to any record.

Type 'request <tab>' to see available commands.
"
}

# Create a new request with optional attachment to another record
#
# This is the primary way to create requests in the chuck-stack system.
# You can pipe in a UUID string, a single record, or a table to attach to.
# The --attach parameter accepts only string UUIDs.
# Use --description to provide request details.
#
# Accepts piped input:
#   string - UUID of record to attach this request to
#   record - Single record containing 'uu' field
#   table  - Table where first row contains 'uu' field
#
# Examples:
#   .append request "quarterly-review" --description "Review quarterly reports"
#   "12345678-1234-5678-9012-123456789abc" | .append request "bug-fix" --description "Fix critical bug"
#   project list | get 0 | .append request "update" --description "Update project"
#   project list | where name == "test" | .append request "review" --description "Review this project"
#   .append request "profile-update" --description "Update user profile" --attach $user_uuid
#   .append request "feature-request" --json '{"priority": "medium", "component": "ui"}'
#
# Returns: The UUID of the newly created request record
# Note: When a UUID is provided (via pipe or --attach), table_name_uu_json is auto-populated
export def ".append request" [
    name: string                    # The name/topic of the request (used for categorization and filtering)
    --description(-d): string = ""  # Description of the request (optional)
    --attach(-a): string           # UUID of record to attach this request to (alternative to piped input)
    --json(-j): string             # Optional JSON data to store in record_json field
] {
    let table = $"($STK_SCHEMA).($STK_TABLE_NAME)"
    
    # Extract attachment data from piped input or --attach parameter
    let attach_data = ($in | extract-attach-from-input $attach)
    
    # Handle json parameter - validate if provided, default to empty object
    let record_json = try { $json | parse-json } catch { error make { msg: $in.msg } }
    
    if ($attach_data | is-empty) {
        # Standalone request - no attachment
        let params = {
            name: $name
            description: $description
            record_json: $record_json
        }
        psql new-record $STK_SCHEMA $STK_TABLE_NAME $params
    } else {
        # Request with attachment - get table_name_uu as nushell record
        let table_name_uu = if ($attach_data.table_name? | is-not-empty) {
            # We have the table name - use it directly (no DB lookup)
            {table_name: $attach_data.table_name, uu: $attach_data.uu}
        } else {
            # No table name - look it up using psql command
            psql get-table-name-uu $attach_data.uu
        }
        
        # Convert to JSON for storage
        let table_name_uu_json = ($table_name_uu | to json)
        let params = {
            name: $name
            description: $description
            table_name_uu_json: $table_name_uu_json
            record_json: $record_json
        }
        psql new-record $STK_SCHEMA $STK_TABLE_NAME $params
    }
}

# List the 10 most recent requests from the chuck-stack system
#
# Displays requests in chronological order (newest first) to help you
# monitor recent activity, track outstanding requests, or review request
# history. This is typically your starting point for request investigation.
# Use the returned UUIDs with other request commands for detailed work.
# Use --detail to include type information for all requests.
#
# Accepts piped input: none
#
# Examples:
#   request list
#   request list --detail
#   request list | where name == "urgent"
#   request list --detail | where type_enum == "TODO"
#   request list | where is_revoked == false
#   request list | where is_processed == false
#   request list | select name description created | table
#
# Using elaborate to resolve foreign key references:
#   request list | elaborate                                              # Resolve with default columns
#   request list | elaborate name table_name                              # Show referenced table names
#   request list | elaborate --all | select name table_name_uu_json_resolved.name  # Show referenced record names
#
# Returns: name, description, table_name_uu_json, is_processed, created, updated, is_revoked, uu
# Returns (with --detail): Includes type_enum, type_name, type_description from joined type table
# Note: Only shows the 10 most recent requests - use direct SQL for larger queries
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
# Fetches complete details for a single request when you need to
# inspect its contents, verify its state, check attachments, or
# extract specific data. Use this when you have a UUID from
# request list or from other system outputs.
# Use --detail to include type information.
#
# Accepts piped input:
#   string - The UUID of the request to retrieve
#   record - Single record containing 'uu' field
#   table  - Table where first row contains 'uu' field
#
# Examples:
#   # Using piped input
#   "12345678-1234-5678-9012-123456789abc" | request get
#   request list | get 0 | request get
#   request list | where name == "urgent" | request get
#   
#   # Using --uu parameter
#   request get --uu "12345678-1234-5678-9012-123456789abc"
#   request get --uu $request_uuid --detail
#   
#   # Practical examples
#   $request_uuid | request get | get table_name_uu_json
#   request get --uu $uu | if $in.is_processed { print "Request completed" }
#
# Returns: name, description, table_name_uu_json, is_processed, created, updated, is_revoked, uu
# Returns (with --detail): Includes type_enum, type_name, and other type information
# Error: Returns empty result if UUID doesn't exist
export def "request get" [
    --detail(-d)  # Include detailed type information
    --uu: string  # UUID as parameter (alternative to piped input)
] {
    # Extract UUID from piped input or --uu parameter
    let uu = ($in | extract-uu-with-param $uu)
    
    if $detail {
        psql detail-record $STK_SCHEMA $STK_TABLE_NAME $uu
    } else {
        psql get-record $STK_SCHEMA $STK_TABLE_NAME $STK_REQUEST_COLUMNS $uu
    }
}

# Mark a request as processed by setting its processed timestamp
#
# This indicates the request has been completed and resolved.
# Once processed, requests are considered final and represent
# completed work. Use this to track request completion and
# maintain accurate request status in the chuck-stack system.
#
# Accepts piped input: none
#
# Examples:
#   request process "12345678-1234-5678-9012-123456789abc"
#   request list | where name == "completed" | get uu.0 | request process $in
#   request list | where is_processed == false | each { |row| request process $row.uu }
#
# Returns: uu, name, processed timestamp, and is_processed status
# Error: Command fails if UUID doesn't exist or request is already processed
export def "request process" [
    uu: string  # The UUID of the request to mark as processed
] {
    psql process-record $STK_SCHEMA $STK_TABLE_NAME $uu
}

# Revoke a request by setting its revoked timestamp
#
# This performs a soft delete by setting the revoked column to now().
# Once revoked, requests are considered cancelled and won't appear in 
# normal selections. Use this instead of hard deleting to maintain
# audit trails and data integrity in the chuck-stack system.
#
# Accepts piped input:
#   string - The UUID of the request to revoke
#   record - Single record containing 'uu' field
#   table  - Table where first row contains 'uu' field
#
# Examples:
#   # Using piped input
#   "12345678-1234-5678-9012-123456789abc" | request revoke
#   request list | get 0 | request revoke
#   request list | where name == "obsolete" | request revoke
#   
#   # Using --uu parameter
#   request revoke --uu "12345678-1234-5678-9012-123456789abc"
#   request revoke --uu $request_uuid
#   
#   # Bulk operations
#   request list | where created < (date now) - 30day | each { |row| request revoke --uu $row.uu }
#
# Returns: uu, name, revoked timestamp, and is_revoked status
# Error: Command fails if UUID doesn't exist or request is already revoked
export def "request revoke" [
    --uu: string  # UUID as parameter (alternative to piped input)
] {
    # Extract UUID from piped input or --uu parameter
    let target_uuid = ($in | extract-uu-with-param $uu)
    
    psql revoke-record $STK_SCHEMA $STK_TABLE_NAME $target_uuid
}

# List available request types using generic psql list-types command
#
# Shows all available request types that can be used when creating requests.
# Use this to see valid type options and their descriptions before
# creating new requests with specific types.
#
# Accepts piped input: none
#
# Examples:
#   request types
#   request types | where type_enum == "TODO"
#   request types | where is_default == true
#   request types | select type_enum name is_default | table
#
# Returns: uu, type_enum, name, description, is_default, created for all request types
# Note: Uses the generic psql list-types command for consistency across chuck-stack
export def "request types" [] {
    psql list-types $STK_SCHEMA $STK_TABLE_NAME
}

# Add a 'requests' column to records, fetching associated stk_request records
#
# This command enriches piped records with a 'requests' column containing
# their associated request records. It uses the table_name_uu_json pattern
# to find requests that reference the input records.
#
# Examples:
#   project list | requests                            # Default columns
#   project list | requests --all                      # All request columns
#   project list | requests name description created   # Specific columns
#
# Returns: Original records with added 'requests' column containing array of request records
export def requests [
    ...columns: string  # Specific columns to include in request records
    --all               # Include all columns (select *)
] {
    $in | psql append-table-name-uu-json "stk_request" "requests" ["record_json", "name", "description", "search_key"] ...$columns --all=$all
}

# STK Request Module
# This module provides commands for working with stk_request table

# Module Constants
const STK_SCHEMA = "api"
const STK_PRIVATE_SCHEMA = "private"
const STK_TABLE_NAME = "stk_request"
const STK_DEFAULT_LIMIT = 10
const STK_REQUEST_COLUMNS = "name, description, table_name_uu_json, is_processed"
const STK_BASE_COLUMNS = "created, updated, is_revoked, uu"

# Create a new request with optional attachment to another record
#
# This is the primary way to create requests in the chuck-stack system.
# You can either pipe in a UUID to attach to, or provide it via --attach.
# The UUID identifies the parent record this request should be linked to.
# Use --description to provide request details.
#
# Accepts piped input:
#   string - UUID of record to attach this request to (optional)
#
# Examples:
#   .append request "quarterly-review" --description "Review quarterly reports"
#   "12345678-1234-5678-9012-123456789abc" | .append request "bug-fix" --description "Fix critical bug"
#   .append request "profile-update" --description "Update user profile" --attach $user_uuid
#   request list | get uu.0 | .append request "follow-up" --description "Follow up on this request"
#
# Returns: The UUID of the newly created request record
# Note: When a UUID is provided (via pipe or --attach), table_name_uu_json is auto-populated
export def ".append request" [
    name: string                    # The name/topic of the request (used for categorization and filtering)
    --description(-d): string = ""  # Description of the request (optional)
    --attach(-a): string           # UUID of record to attach this request to (alternative to piped input)
] {
    let piped_uuid = $in
    let table = $"($STK_SCHEMA).($STK_TABLE_NAME)"
    
    # Determine which UUID to use - piped input takes precedence over --attach
    let attach_uuid = if ($piped_uuid | is-empty) {
        $attach
    } else {
        $piped_uuid
    }
    
    if ($attach_uuid | is-empty) {
        # Standalone request - no attachment
        let sql = $"INSERT INTO ($table) \(name, description) VALUES \('($name)', '($description)') RETURNING uu"
        psql exec $sql
    } else {
        # Request with attachment - auto-populate table_name_uu_json
        let sql = $"INSERT INTO ($table) \(name, description, table_name_uu_json) VALUES \('($name)', '($description)', ($STK_SCHEMA).get_table_name_uu_json\('($attach_uuid)')) RETURNING uu"
        psql exec $sql
    }
}

# List the 10 most recent requests from the chuck-stack system
#
# Displays requests in chronological order (newest first) to help you
# monitor recent activity, track outstanding requests, or review request
# history. This is typically your starting point for request investigation.
# Use the returned UUIDs with other request commands for detailed work.
#
# Accepts piped input: none
#
# Examples:
#   request list
#   request list | where name == "urgent"
#   request list | where is_revoked == false
#   request list | where is_processed == false
#   request list | select name description created | table
#
# Returns: name, description, table_name_uu_json, is_processed, created, updated, is_revoked, uu
# Note: Only shows the 10 most recent requests - use direct SQL for larger queries
export def "request list" [] {
    psql list-records $STK_SCHEMA $STK_TABLE_NAME $STK_REQUEST_COLUMNS $STK_BASE_COLUMNS $STK_DEFAULT_LIMIT
}

# Retrieve a specific request by its UUID
#
# Fetches complete details for a single request when you need to
# inspect its contents, verify its state, check attachments, or
# extract specific data. Use this when you have a UUID from
# request list or from other system outputs.
#
# Accepts piped input: none
#
# Examples:
#   request get "12345678-1234-5678-9012-123456789abc"
#   request list | get uu.0 | request get $in
#   $request_uuid | request get $in | get table_name_uu_json
#   request get $uu | if $in.is_processed { print "Request completed" }
#
# Returns: name, description, table_name_uu_json, is_processed, created, updated, is_revoked, uu
# Error: Returns empty result if UUID doesn't exist
export def "request get" [
    uu: string  # The UUID of the request to retrieve
] {
    psql get-record $STK_SCHEMA $STK_TABLE_NAME $STK_REQUEST_COLUMNS $STK_BASE_COLUMNS $uu
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
# Accepts piped input: none
#
# Examples:
#   request revoke "12345678-1234-5678-9012-123456789abc"
#   request list | where name == "obsolete" | get uu.0 | request revoke $in
#   request list | where created < (date now) - 30day | each { |row| request revoke $row.uu }
#
# Returns: uu, name, revoked timestamp, and is_revoked status
# Error: Command fails if UUID doesn't exist or request is already revoked
export def "request revoke" [
    uu: string  # The UUID of the request to revoke
] {
    psql revoke-record $STK_SCHEMA $STK_TABLE_NAME $uu
}
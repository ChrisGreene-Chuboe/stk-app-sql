# STK Event Module
# This module provides commands for working with stk_event table

# Module Constants
const STK_SCHEMA = "api"
const STK_PRIVATE_SCHEMA = "private"
const STK_TABLE_NAME = "stk_event"
const STK_REQUEST_TABLE_NAME = "stk_request"  # For event request command
const STK_DEFAULT_LIMIT = 10
const STK_BASE_COLUMNS = "uu, created, updated, is_revoked"
const STK_EVENT_COLUMNS = "name, record_json"

# Append text to the stk_event table with a specified name/topic
#
# This is the primary way to log events in the chuck-stack system.
# The command takes piped text input and stores it as JSON in the
# event's record_json field. Use this for logging user actions,
# system events, audit trails, and any textual data that needs
# to be tracked with timestamps.
#
# Examples:
#   "User login successful" | .append event "authentication"
#   $"Error processing order ($order_id)" | .append event "order-error"
#   get content | to text | .append event "file-backup"
#   http get https://api.example.com | to json | .append event "api-call"
#
# Returns: The UUID of the newly created event record
# Note: The text is automatically wrapped in {"text": "your-content"}
export def ".append event" [
    name: string       # The name/topic of the event (used for categorization and filtering)
] {
    # Create the SQL command
    let table = $"($STK_SCHEMA).($STK_TABLE_NAME)"
    let sql = $"INSERT INTO ($table) \(name,record_json) VALUES \('($name)', jsonb_build_object\('text', '($in)')) RETURNING uu"

    psql exec $sql
}

# List the 10 most recent events from the chuck-stack system
#
# Displays events in chronological order (newest first) to help you
# monitor recent activity, debug issues, or track system behavior.
# This is typically your starting point for event investigation.
# Use the returned UUIDs with other event commands for detailed work.
#
# Examples:
#   event list
#   event list | where name == "authentication" 
#   event list | where is_revoked == false
#   event list | select name created | table
#
# Returns: uu, name, record_json, created, updated, is_revoked
# Note: Only shows the 10 most recent events - use direct SQL for larger queries
export def "event list" [] {
    psql list-records $STK_SCHEMA $STK_TABLE_NAME $STK_BASE_COLUMNS $STK_EVENT_COLUMNS $STK_DEFAULT_LIMIT
}

# Retrieve a specific event by its UUID
#
# Fetches complete details for a single event when you need to
# inspect its contents, verify its state, or extract specific
# data from the record_json field. Use this when you have a
# UUID from event list or from other system outputs.
#
# Examples:
#   event get "12345678-1234-5678-9012-123456789abc"
#   event list | get uu.0 | event get $in
#   $event_uuid | event get $in | get record_json
#   event get $uu | if $in.is_revoked { print "Event was revoked" }
#
# Returns: uu, name, record_json, created, updated, is_revoked
# Error: Returns empty result if UUID doesn't exist
export def "event get" [
    uu: string  # The UUID of the event to retrieve
] {
    psql get-record $STK_SCHEMA $STK_TABLE_NAME $STK_BASE_COLUMNS $STK_EVENT_COLUMNS $uu
}

# Revoke an event by setting its revoked timestamp
#
# This performs a soft delete by setting the revoked column to now().
# Once revoked, events are considered immutable and won't appear in 
# normal selections. Use this instead of hard deleting to maintain
# audit trails and data integrity in the chuck-stack system.
#
# Examples:
#   event revoke "12345678-1234-5678-9012-123456789abc"
#   event list | where name == "test" | get uu.0 | event revoke $in
#   event list | where created < (date now) - 30day | each { |row| event revoke $row.uu }
#
# Returns: uu, name, revoked timestamp, and is_revoked status
# Error: Command fails if UUID doesn't exist or event is already revoked
export def "event revoke" [
    uu: string  # The UUID of the event to revoke
] {
    psql revoke-record $STK_SCHEMA $STK_TABLE_NAME $uu
}

# Create a request attached to a specific event
#
# This creates a request record that is specifically linked to an event,
# enabling you to create follow-up actions, todos, or investigations
# related to logged events. The request is automatically attached to 
# the specified event UUID using the table_name_uu_json convention.
#
# Examples:
#   "investigate this error" | event request $error_event_uuid
#   "follow up on authentication failure" | event request $auth_event_uuid
#   event list | where name == "critical" | get uu.0 | "urgent action needed" | event request $in
#   "review and update documentation" | event request $event_uu
#
# Returns: The UUID of the newly created request record attached to the event
# Error: Command fails if event UUID doesn't exist
export def "event request" [
    uu: string              # The UUID of the event to attach the request to
    --attach(-f): string    # Request text (alternative to pipeline input)
] {
    let request_text = if ($attach | is-empty) { $in } else { $attach }
    let request_table = $"($STK_SCHEMA).($STK_REQUEST_TABLE_NAME)"
    let name = "event-request"
    let sql = $"INSERT INTO ($request_table) \(name, description, table_name_uu_json) VALUES \('($name)', '($request_text)', ($STK_SCHEMA).get_table_name_uu_json\('($uu)')) RETURNING uu"
    
    psql exec $sql
}


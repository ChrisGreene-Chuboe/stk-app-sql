# STK Event Module
# This module provides commands for working with stk_event table

# Module Constants
const STK_SCHEMA = "api"
const STK_PRIVATE_SCHEMA = "private"
const STK_TABLE_NAME = "stk_event"
const STK_REQUEST_TABLE_NAME = "stk_request"  # For event request command
const STK_DEFAULT_LIMIT = 10
const STK_EVENT_COLUMNS = "name, description, record_json"
const STK_BASE_COLUMNS = "created, updated, is_revoked, uu"

# Create a new event in the chuck-stack system
#
# Use this command to log system events for monitoring, debugging, and
# audit trails. Events help track what happened, when it happened, and
# provide context for system behavior analysis.
#
# The event description is provided via the --description parameter.
# Piped input accepts a UUID to link this event to another record.
# The name parameter categorizes the event for easy filtering and analysis.
#
# Accepts piped input:
#   string - UUID of parent record to link this event to (optional)
#
# Examples:
#   .append event "authentication" --description "User login successful"
#   .append event "system-backup" --description $"Database backup completed: ($backup_size) MB"
#   .append event "order-error" --description $"Error processing order ($order_id)"
#   .append event "file-backup" --description (get content | to text)
#   .append event "system-error" --description "Critical system failure" --metadata '{"urgency": "high", "component": "database"}'
#   $parent_record_uuid | .append event "authentication" --description "User John logged in" --metadata '{"user_id": 123, "ip": "192.168.1.1"}'
#
# Returns: The UUID of the newly created event record
# Note: Description goes to description field, metadata goes to record_json field, piped UUID goes to table_name_uu_json field
export def ".append event" [
    name: string                    # The name/topic of the event (used for categorization and filtering)
    --description(-d): string       # The event description text (required)
    --metadata(-m): string          # Optional JSON metadata to store in record_json field
] {
    # Validate required description parameter
    if ($description | is-empty) {
        error make {msg: "Description is required. Use --description to provide event details."}
    }
    
    # Handle optional piped UUID for parent record linking via table_name_uu_json
    let piped_uuid = $in
    let table_name_uu_json = if ($piped_uuid | is-empty) { 
        "'{}'"
    } else { 
        $"($STK_SCHEMA).get_table_name_uu_json\('($piped_uuid)'::uuid)"
    }
    
    # Create the SQL command
    let table = $"($STK_SCHEMA).($STK_TABLE_NAME)"
    let metadata_json = if ($metadata | is-empty) { "'{}'" } else { $"'($metadata)'" }
    let sql = $"INSERT INTO ($table) \(name, description, table_name_uu_json, record_json) VALUES \('($name)', '($description)', ($table_name_uu_json), ($metadata_json)::jsonb) RETURNING uu"

    psql exec $sql
}

# List the 10 most recent events from the chuck-stack system
#
# Displays events in chronological order (newest first) to help you
# monitor recent activity, debug issues, or track system behavior.
# This is typically your starting point for event investigation.
# Use the returned UUIDs with other event commands for detailed work.
#
# Accepts piped input: none
#
# Examples:
#   event list
#   event list | where name == "authentication" 
#   event list | where is_revoked == false
#   event list | select name created | table
#
# Returns: name, description, record_json, created, updated, is_revoked, uu
# Note: Only shows the 10 most recent events - use direct SQL for larger queries
export def "event list" [] {
    psql list-records $STK_SCHEMA $STK_TABLE_NAME $STK_EVENT_COLUMNS $STK_BASE_COLUMNS $STK_DEFAULT_LIMIT
}

# Retrieve a specific event by its UUID
#
# Fetches complete details for a single event when you need to
# inspect its contents, verify its state, or extract specific
# data from the record_json field. Use this when you have a
# UUID from event list or from other system outputs.
#
# Accepts piped input: none
#
# Examples:
#   event get "12345678-1234-5678-9012-123456789abc"
#   event list | get uu.0 | event get $in
#   $event_uuid | event get $in | get description
#   event get $uu | get record_json
#   event get $uu | if $in.is_revoked { print "Event was revoked" }
#
# Returns: name, description, record_json, created, updated, is_revoked, uu
# Error: Returns empty result if UUID doesn't exist
export def "event get" [
    uu: string  # The UUID of the event to retrieve
] {
    psql get-record $STK_SCHEMA $STK_TABLE_NAME $STK_EVENT_COLUMNS $STK_BASE_COLUMNS $uu
}

# Revoke an event by setting its revoked timestamp
#
# This performs a soft delete by setting the revoked column to now().
# Once revoked, events are considered immutable and won't appear in 
# normal selections. Use this instead of hard deleting to maintain
# audit trails and data integrity in the chuck-stack system.
#
# Accepts piped input: 
#   string - The UUID of the event to revoke (required via pipe)
#
# Examples:
#   event list | where name == "test" | get uu.0 | event revoke
#   event list | where created < (date now) - 30day | each { |row| $row.uu | event revoke }
#   "12345678-1234-5678-9012-123456789abc" | event revoke
#
# Returns: uu, name, revoked timestamp, and is_revoked status
# Error: Command fails if UUID doesn't exist or event is already revoked
export def "event revoke" [] {
    let target_uuid = $in
    
    if ($target_uuid | is-empty) {
        error make { msg: "UUID required via piped input" }
    }
    
    psql revoke-record $STK_SCHEMA $STK_TABLE_NAME $target_uuid
}

# Create a request attached to a specific event
#
# This creates a request record that is specifically linked to an event,
# enabling you to create follow-up actions, todos, or investigations
# related to logged events. The request is automatically attached to 
# the specified event UUID using the table_name_uu_json convention.
#
# Accepts piped input: 
#   string - UUID of the event to attach the request to (required via pipe)
#
# Examples:
#   $error_event_uuid | event request --description "investigate this error"
#   $auth_event_uuid | event request --description "follow up on authentication failure"
#   event list | where name == "critical" | get uu.0 | event request --description "urgent action needed"
#   $event_uu | event request --description "review and update documentation"
#
# Returns: The UUID of the newly created request record attached to the event
# Error: Command fails if event UUID doesn't exist or --description not provided
export def "event request" [
    --description(-d): string    # Request description text (required)
] {
    # Validate required description parameter
    if ($description | is-empty) {
        error make {msg: "Request description is required. Use --description to provide request text."}
    }
    
    # Use piped UUID
    let target_uuid = $in
    
    if ($target_uuid | is-empty) {
        error make {msg: "Event UUID is required. Provide as pipe input."}
    }
    
    let request_table = $"($STK_SCHEMA).($STK_REQUEST_TABLE_NAME)"
    let name = "event-request"
    let sql = $"INSERT INTO ($request_table) \(name, description, table_name_uu_json) VALUES \('($name)', '($description)', ($STK_SCHEMA).get_table_name_uu_json\('($target_uuid)')) RETURNING uu"
    
    psql exec $sql
}


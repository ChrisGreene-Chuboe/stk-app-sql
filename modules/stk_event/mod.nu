# STK Event Module
# This module provides commands for working with stk_event table

# Module Constants
const STK_SCHEMA = "api"
const STK_PRIVATE_SCHEMA = "private"
const STK_TABLE_NAME = "stk_event"
const STK_DEFAULT_LIMIT = 10
const STK_EVENT_COLUMNS = "name, description, table_name_uu_json, record_json"
const STK_BASE_COLUMNS = "created, updated, is_revoked, uu"

# Create a new event with optional attachment to another record
#
# This is the primary way to create events in the chuck-stack system.
# You can either pipe in a UUID to attach to, or provide it via --attach.
# The UUID identifies the parent record this event should be linked to.
# Use --description to provide event details and --metadata for structured data.
#
# Accepts piped input:
#   string - UUID of record to attach this event to (optional)
#
# Examples:
#   .append event "authentication" --description "User login successful"
#   "12345678-1234-5678-9012-123456789abc" | .append event "bug-fix" --description "System error occurred"
#   .append event "system-backup" --description "Database backup completed" --attach $backup_uuid
#   event list | get uu.0 | .append event "follow-up" --description "Follow up on this event"
#   .append event "system-error" --description "Critical system failure" --metadata '{"urgency": "high", "component": "database"}'
#
# Returns: The UUID of the newly created event record
# Note: When a UUID is provided (via pipe or --attach), table_name_uu_json is auto-populated
export def ".append event" [
    name: string                    # The name/topic of the event (used for categorization and filtering)
    --description(-d): string = ""  # Description of the event (optional)
    --metadata(-m): string          # Optional JSON metadata to store in record_json field
    --attach(-a): string           # UUID of record to attach this event to (alternative to piped input)
] {
    let piped_uuid = $in
    let table = $"($STK_SCHEMA).($STK_TABLE_NAME)"
    
    # Determine which UUID to use - piped input takes precedence over --attach
    let attach_uuid = if ($piped_uuid | is-empty) {
        $attach
    } else {
        $piped_uuid
    }
    
    # Handle metadata parameter
    let metadata_json = if ($metadata | is-empty) { "'{}'" } else { $"'($metadata)'" }
    
    if ($attach_uuid | is-empty) {
        # Standalone event - no attachment
        let sql = $"INSERT INTO ($table) \(name, description, record_json) VALUES \('($name)', '($description)', ($metadata_json)::jsonb) RETURNING uu"
        psql exec $sql
    } else {
        # Event with attachment - auto-populate table_name_uu_json
        let sql = $"INSERT INTO ($table) \(name, description, table_name_uu_json, record_json) VALUES \('($name)', '($description)', ($STK_SCHEMA).get_table_name_uu_json\('($attach_uuid)'), ($metadata_json)::jsonb) RETURNING uu"
        psql exec $sql
    }
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
# Returns: name, description, table_name_uu_json, record_json, created, updated, is_revoked, uu
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
#   event get $uu | get table_name_uu_json
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



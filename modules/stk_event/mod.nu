# STK Event Module
# This module provides commands for working with stk_event table

# Module Constants
const STK_SCHEMA = "api"
const STK_TABLE_NAME = "stk_event"
const STK_EVENT_COLUMNS = [name, description, table_name_uu_json, record_json]

# Event module overview
export def "event" [] {
    print "Events capture significant occurrences in your system:
logins, errors, transactions, and other activities worth recording.

Events are append-only and immutable for audit integrity.
Use .append event pattern to attach events to any record.

Type 'event <tab>' to see available commands.
"
}

# Create a new event with optional attachment to another record
#
# This is the primary way to create events in the chuck-stack system.
# You can either pipe in a UUID/record to attach to, or provide it via --attach.
# The UUID identifies the parent record this event should be linked to.
# Use --description to provide event details and --json for structured data.
#
# Accepts piped input:
#   string - UUID of record to attach this event to (optional)
#   record - Record with 'uu' field to attach this event to (optional)
#   table - Table of records, uses first row's 'uu' field (optional)
#
# Examples:
#   .append event "authentication" --description "User login successful"
#   "12345678-1234-5678-9012-123456789abc" | .append event "bug-fix" --description "System error occurred"
#   project list | get 0 | .append event "project-update" --description "Project milestone reached"
#   todo list | where priority == "high" | .append event "task-review" --description "Review high priority tasks"
#   .append event "system-backup" --description "Database backup completed" --attach $backup_uuid
#   event list | get uu.0 | .append event "follow-up" --description "Follow up on this event"
#   .append event "system-error" --description "Critical system failure" --json '{"urgency": "high", "component": "database"}'
#
# Returns: The UUID of the newly created event record
# Note: When a UUID is provided (via pipe or --attach), table_name_uu_json is auto-populated
export def ".append event" [
    name: string                    # The name/topic of the event (used for categorization and filtering)
    --description(-d): string = ""  # Description of the event (optional)
    --json(-j): string              # Optional JSON data to store in record_json field
    --attach(-a): string           # UUID of record to attach this event to (alternative to piped input)
] {
    let table = $"($STK_SCHEMA).($STK_TABLE_NAME)"
    
    # Extract attachment data from piped input or --attach parameter
    let attach_data = ($in | extract-attach-from-input $attach)
    
    # Handle json parameter - validate if provided, default to empty object
    let record_json = try { $json | parse-json } catch { error make { msg: $in.msg } }
    
    if ($attach_data | is-empty) {
        # Standalone event - no attachment
        let sql = $"INSERT INTO ($table) \(name, description, record_json) VALUES \('($name)', '($description)', '($record_json)'::jsonb) RETURNING uu"
        psql exec $sql
    } else {
        # Event with attachment - auto-populate table_name_uu_json
        # Get table_name_uu as nushell record (not JSON!)
        let table_name_uu = if ($attach_data.table_name? | is-not-empty) {
            # We have the table name - use it directly (no DB lookup)
            {table_name: $attach_data.table_name, uu: $attach_data.uu}
        } else {
            # No table name - look it up using psql command
            psql get-table-name-uu $attach_data.uu
        }
        
        # Only convert to JSON at the SQL boundary
        let table_name_uu_json = ($table_name_uu | to json)
        let sql = $"INSERT INTO ($table) \(name, description, table_name_uu_json, record_json) VALUES \('($name)', '($description)', '($table_name_uu_json)'::jsonb, '($record_json)'::jsonb) RETURNING uu"
        psql exec $sql
    }
}

# List the 10 most recent events from the chuck-stack system
#
# Displays events in chronological order (newest first) to help you
# monitor recent activity, debug issues, or track system behavior.
# This is typically your starting point for event investigation.
# Use the returned UUIDs with other event commands for detailed work.
# Use --detail to include type information for all events.
#
# Accepts piped input: none
#
# Examples:
#   event list
#   event list --detail
#   event list | where name == "authentication" 
#   event list --detail | where type_enum == "ACTION"
#   event list | where is_revoked == false
#   event list | select name created | table
#
# Using elaborate to resolve foreign key references:
#   event list | elaborate                                               # Resolve with default columns
#   event list | elaborate name table_name                               # Show referenced table names
#   event list | elaborate --all | select name table_name_uu_json_resolved.name  # Show referenced record names
#
# Returns: name, description, table_name_uu_json, record_json, created, updated, is_revoked, uu
# Returns (with --detail): Includes type_enum, type_name, type_description from joined type table
# Note: Only shows the 10 most recent events - use direct SQL for larger queries
export def "event list" [
    --detail(-d)  # Include detailed type information for all events
    --all(-a)     # Include revoked events
] {
    # Build complete arguments array including flags
    let args = [$STK_SCHEMA, $STK_TABLE_NAME] | append $STK_EVENT_COLUMNS
    
    # Add --all flag to args if needed
    let args = if $all { $args | append "--all" } else { $args }
    
    # Choose command and execute with spread - no nested if/else!
    if $detail {
        psql list-records-with-detail ...$args
    } else {
        psql list-records ...$args
    }
}

# Retrieve a specific event by its UUID
#
# Fetches complete details for a single event when you need to
# inspect its contents, verify its state, or extract specific
# data from the record_json field. Use this when you have a
# UUID from event list or from other system outputs.
# Use --detail to include type information.
#
# Accepts piped input:
#   string - The UUID of the event to retrieve
#   record - Record with 'uu' field to retrieve
#   table - Table of records, uses first row's 'uu' field
#
# Examples:
#   # Using piped input
#   "12345678-1234-5678-9012-123456789abc" | event get
#   event list | get 0 | event get
#   event list | where name == "error" | event get
#   
#   # Using --uu parameter
#   event get --uu "12345678-1234-5678-9012-123456789abc"
#   event get --uu $event_uuid --detail
#   
#   # Practical examples
#   $event_uuid | event get | get description
#   event get --uu $uu | get record_json
#   $uu | event get | if $in.is_revoked { print "Event was revoked" }
#
# Returns: name, description, record_json, created, updated, is_revoked, uu
# Returns (with --detail): Includes type_enum, type_name, and other type information
# Error: Returns empty result if UUID doesn't exist
export def "event get" [
    --detail(-d)  # Include detailed type information
    --uu: string  # UUID as parameter (alternative to piped input)
] {
    # Extract UUID from piped input or --uu parameter
    let uu = ($in | extract-uu-with-param $uu)
    
    if $detail {
        psql detail-record $STK_SCHEMA $STK_TABLE_NAME $uu
    } else {
        psql get-record $STK_SCHEMA $STK_TABLE_NAME $STK_EVENT_COLUMNS $uu
    }
}

# Revoke an event by setting its revoked timestamp
#
# This performs a soft delete by setting the revoked column to now().
# Once revoked, events are considered immutable and won't appear in 
# normal selections. Use this instead of hard deleting to maintain
# audit trails and data integrity in the chuck-stack system.
#
# Accepts piped input: 
#   string - The UUID of the event to revoke
#   record - Record with 'uu' field to revoke
#   table - Table of records, uses first row's 'uu' field
#
# Examples:
#   # Using piped input
#   event list | where name == "test" | get 0 | event revoke
#   "12345678-1234-5678-9012-123456789abc" | event revoke
#   
#   # Using --uu parameter
#   event revoke --uu "12345678-1234-5678-9012-123456789abc"
#   event revoke --uu $event_uuid
#   
#   # Bulk operations
#   event list | where created < (date now) - 30day | each { |row| event revoke --uu $row.uu }
#
# Returns: uu, name, revoked timestamp, and is_revoked status
# Error: Command fails if UUID doesn't exist or event is already revoked
export def "event revoke" [
    --uu: string  # UUID as parameter (alternative to piped input)
] {
    # Extract UUID from piped input or --uu parameter
    let target_uuid = ($in | extract-uu-with-param $uu)
    
    psql revoke-record $STK_SCHEMA $STK_TABLE_NAME $target_uuid
}

# List available event types using generic psql list-types command
#
# Shows all available event types that can be used when creating events.
# Use this to see valid type options and their descriptions before
# creating new events with specific types.
#
# Accepts piped input: none
#
# Examples:
#   event types
#   event types | where type_enum == "ACTION"
#   event types | where is_default == true
#   event types | select type_enum name is_default | table
#
# Returns: uu, type_enum, name, description, is_default, created for all event types
# Note: Uses the generic psql list-types command for consistency across chuck-stack
export def "event types" [] {
    psql list-types $STK_SCHEMA $STK_TABLE_NAME
}

# Add an 'events' column to records, fetching associated stk_event records
#
# This command enriches piped records with an 'events' column containing
# their associated event records. It uses the table_name_uu_json pattern
# to find events that reference the input records.
#
# Examples:
#   project list | events                          # Default columns
#   project list | events --all                    # All event columns
#   project list | events name description created # Specific columns
#
# Returns: Original records with added 'events' column containing array of event records
export def events [
    ...columns: string  # Specific columns to include in event records
    --all               # Include all columns (select *)
] {
    $in | psql append-table-name-uu-json "stk_event" "events" ["record_json", "name", "description", "search_key"] ...$columns --all=$all
}



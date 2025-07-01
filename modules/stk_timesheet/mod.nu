# STK Timesheet Module
# This module provides commands for working with timesheet entries built on the stk_event table

# Module Constants
const STK_SCHEMA = "api"
const STK_TABLE_NAME = "stk_event"  # Wrapping stk_event
const STK_TIMESHEET_TYPE_ENUM = ["TIMESHEET"]  # Filter for timesheet events
const STK_TIMESHEET_COLUMNS = [name, description, table_name_uu_json, record_json, processed, is_processed]

# Create a new timesheet entry with attachment to another record
#
# This is the primary way to record time entries in the chuck-stack system.
# Creates an event record with type_enum = 'TIMESHEET'. You must pipe in 
# a UUID to attach the timesheet to (project, project_line, request, etc).
# The time is stored as minutes in record_json along with start_date.
# Use --description to describe what work was performed.
#
# Accepts piped input:
#   string - UUID of record to attach this timesheet to (required)
#   record - Record with 'uu' field to attach this timesheet to (required)
#   table - Table of records, uses first row's 'uu' field (required)
#
# Examples:
#   # Basic time entry with minutes
#   $project_uuid | .append timesheet --minutes 90 --description "Code review"
#   
#   # Time entry with hours (converted to minutes)
#   project get --uu $id | .append timesheet --hours 2.5 --description "Implementation"
#   
#   # Time entry with specific start date
#   $task_uuid | .append timesheet --minutes 45 --start-date "2024-01-15T09:00:00Z"
#   
#   # Attach to project line (task)
#   project line list $project | where type_name == "TASK" | get 0 | .append timesheet --hours 1
#   
#   # Attach to request/ticket
#   request list | where name =~ "Bug" | .append timesheet --minutes 30 --description "Bug investigation"
#
# Returns: The UUID of the newly created timesheet event record
# Error: Fails if no UUID is piped, if minutes exceed 1440, or if JSON schema validation fails
export def ".append timesheet" [
    --minutes(-m): int       # Duration in minutes (0-1440)
    --hours(-h): float      # Duration in hours (0-24) - converted to minutes
    --start-date(-s): string # Start date/time (ISO format, defaults to now())
    --description(-d): string = "" # Description of work performed
] {
    # Validate that we have either minutes or hours (but not both)
    if ($minutes == null and $hours == null) {
        error make {msg: "Either --minutes or --hours must be provided"}
    }
    if ($minutes != null and $hours != null) {
        error make {msg: "Cannot provide both --minutes and --hours"}
    }
    
    # Calculate minutes from hours if needed
    let total_minutes = if ($minutes != null) {
        $minutes
    } else {
        ($hours * 60 | math round | into int)
    }
    
    # Validate minutes range
    if ($total_minutes < 0 or $total_minutes > 1440) {
        error make {msg: $"Minutes must be between 0 and 1440 \(24 hours), got ($total_minutes)"}
    }
    
    # Get start date (default to now if not provided)
    let start_timestamp = if ($start_date | is-empty) {
        (date now | to nuon | str replace --all '"' '')
    } else {
        $start_date
    }
    
    # Extract attachment data from piped input (required for timesheets)
    let attach_data = ($in | extract-attach-from-input "")
    
    if ($attach_data | is-empty) {
        error make {msg: "Timesheet must be attached to a record. Pipe in a UUID, record, or table."}
    }
    
    # Build the record_json for timesheet data
    let timesheet_data = {
        start_date: $start_timestamp,
        minutes: $total_minutes,
        description: $description
    }
    
    # Get the TIMESHEET type UUID
    let type_uu = (psql get-type $STK_SCHEMA $STK_TABLE_NAME --search-key "TIMESHEET" | get uu)
    
    # Get table_name_uu for the attachment
    let table_name_uu = if ($attach_data.table_name? | is-not-empty) {
        # We have the table name - use it directly
        {table_name: $attach_data.table_name, uu: $attach_data.uu}
    } else {
        # No table name - look it up
        psql get-table-name-uu $attach_data.uu
    }
    
    # Build parameters for event creation
    let params = {
        name: "timesheet",
        type_uu: $type_uu,
        description: $description,
        record_json: ($timesheet_data | to json),
        table_name_uu_json: ($table_name_uu | to json)
    }
    
    # Create the event
    psql new-record $STK_SCHEMA $STK_TABLE_NAME $params
}

# List timesheet entries from the chuck-stack system
#
# Displays timesheet entries in chronological order (newest first).
# Only shows events with type_enum = 'TIMESHEET'. By default shows only active 
# (non-revoked) timesheets. Use --all to include cancelled entries.
# Use nushell's pipeline commands to filter, group, and analyze the results.
#
# Accepts piped input: none
#
# Examples:
#   timesheet list
#   timesheet list --detail
#   timesheet list --all
#   
#   # Pipeline filtering examples:
#   timesheet list | where record_json.minutes > 240  # Over 4 hours
#   timesheet list | where record_json.start_date > "2024-01-01"
#   timesheet list | where table_name_uu_json.uu == $project_uuid
#   
#   # Calculate totals:
#   timesheet list | get record_json.minutes | math sum | $in / 60  # Total hours
#   
#   # Group by day:
#   timesheet list | group-by { $in.record_json.start_date | into datetime | format date "%Y-%m-%d" }
#   
#   # With elaborate to see attached records:
#   timesheet list | elaborate name table_name
#
# Returns: name, description, table_name_uu_json, record_json, processed, is_processed, created, updated, is_revoked, uu
# Returns (with --detail): Includes type_enum, type_name, type_description from joined type table
# Note: Results are ordered by creation time and filtered to type_enum = 'TIMESHEET'
export def "timesheet list" [
    --detail(-d)  # Include detailed type information
    --all(-a)     # Include revoked (cancelled) timesheets
] {
    # Build args list with optional --all flag
    let args = if $all {
        [$STK_SCHEMA, $STK_TABLE_NAME] | append $STK_TIMESHEET_COLUMNS | append "--all"
    } else {
        [$STK_SCHEMA, $STK_TABLE_NAME] | append $STK_TIMESHEET_COLUMNS
    }
    
    psql list-records ...$args --enum $STK_TIMESHEET_TYPE_ENUM --detail=$detail
}

# Retrieve a specific timesheet entry by its UUID
#
# Fetches complete details for a single timesheet entry.
# Only retrieves records with type_enum = 'TIMESHEET'.
# Use --detail to include type information.
#
# Accepts piped input:
#   string - The UUID of the timesheet to retrieve
#   record - Record with 'uu' field containing the UUID
#   table - Table with first row containing the timesheet record
#
# Examples:
#   # Using piped input
#   "12345678-1234-5678-9012-123456789abc" | timesheet get
#   timesheet list | get uu.0 | timesheet get
#   timesheet list | get 0 | timesheet get
#   
#   # Using --uu parameter
#   timesheet get --uu "12345678-1234-5678-9012-123456789abc"
#   timesheet get --uu $timesheet_uuid --detail
#   
#   # Extract timesheet data
#   $timesheet_uuid | timesheet get | get record_json.minutes
#   timesheet get --uu $uu | get record_json | $in.minutes / 60  # Get hours
#
# Returns: name, description, table_name_uu_json, record_json, processed, is_processed, created, updated, is_revoked, uu
# Returns (with --detail): Includes type_enum, type_name, and other type information
# Error: Returns empty result if UUID doesn't exist or type_enum != 'TIMESHEET'
export def "timesheet get" [
    --detail(-d)  # Include detailed type information
    --uu: string  # UUID as parameter (alternative to piped input)
] {
    # Extract UUID from piped input or --uu parameter
    let uu = ($in | extract-uu-with-param $uu)
    
    # Get the record with enum filter
    psql get-record $STK_SCHEMA $STK_TABLE_NAME $STK_TIMESHEET_COLUMNS $uu --enum $STK_TIMESHEET_TYPE_ENUM --detail=$detail
}

# Mark a timesheet entry as cancelled (revoke)
#
# This performs a soft delete by setting the revoked column to now().
# Once revoked, timesheets are considered cancelled and won't appear in 
# normal timesheet list views. Only works on records with type_enum = 'TIMESHEET'.
# Use this to cancel incorrectly entered time entries while maintaining 
# the audit trail in the chuck-stack system.
#
# Accepts piped input: 
#   string - The UUID of the timesheet to cancel
#   record - Record with 'uu' field containing the UUID
#   table - Table with first row containing the timesheet record
#
# Examples:
#   # Using piped input
#   timesheet list | where record_json.minutes > 1440 | get uu.0 | timesheet revoke
#   timesheet list | get 0 | timesheet revoke
#   "12345678-1234-5678-9012-123456789abc" | timesheet revoke
#   
#   # Using --uu parameter
#   timesheet revoke --uu "12345678-1234-5678-9012-123456789abc"
#   timesheet revoke --uu $timesheet_uuid
#
# Returns: uu, name, revoked timestamp, and is_revoked status
# Error: Command fails if UUID doesn't exist, is already revoked, or type_enum != 'TIMESHEET'
export def "timesheet revoke" [
    --uu: string  # UUID as parameter (alternative to piped input)
] {
    # Extract UUID from piped input or --uu parameter
    let target_uuid = ($in | extract-uu-with-param $uu)
    
    # Revoke with enum filter
    psql revoke-record $STK_SCHEMA $STK_TABLE_NAME $target_uuid --enum $STK_TIMESHEET_TYPE_ENUM
}

# List available timesheet types
#
# Shows all available event types with type_enum = 'TIMESHEET' that can be 
# used when creating timesheets. Currently there is only one TIMESHEET type,
# but this follows the chuck-stack pattern for consistency and future expansion.
#
# Accepts piped input: none
#
# Examples:
#   timesheet types
#   timesheet types | get 0
#   timesheet types | where is_default == true
#
# Returns: uu, type_enum, search_key, name, description, is_default, created for types with type_enum = 'TIMESHEET'
# Note: Filters psql list-types to show only records with type_enum = 'TIMESHEET'
export def "timesheet types" [] {
    psql list-types $STK_SCHEMA $STK_TABLE_NAME --enum $STK_TIMESHEET_TYPE_ENUM
}
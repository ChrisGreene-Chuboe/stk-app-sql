# STK Project Module
# This module provides commands for working with stk_project and stk_project_line tables

# Module Constants
const STK_SCHEMA = "api"
const STK_PROJECT_TABLE_NAME = "stk_project"
const STK_PROJECT_LINE_TABLE_NAME = "stk_project_line"
const STK_PROJECT_COLUMNS = [name, description, is_template, is_valid, record_json]
const STK_PROJECT_LINE_COLUMNS = [name, description, is_template, is_valid, record_json]

# Create a new project with specified name and type
#
# This is the primary way to create projects in the chuck-stack system.
# Projects represent client work, internal initiatives, research efforts,
# or maintenance activities that can contain multiple line items and tasks.
# The system automatically assigns default values via triggers if type is not specified.
#
# Accepts piped input:
#   string - UUID of parent project for creating sub-projects (optional)
#
# Examples:
#   project new "Website Redesign"
#   project new "CRM Development" --description "Internal CRM system development"
#   project new "AI Research" --type-search-key "research" --description "Research new AI technologies"
#   "12345678-1234-5678-9012-123456789abc" | project new "Sub-project Name"
#   project new "Data Migration" --json '{"priority": "high", "estimated_hours": 120}'
#
# Returns: The UUID and name of the newly created project record
# Note: Uses chuck-stack conventions for automatic entity and type assignment
export def "project new" [
    name: string                    # The name of the project to create
    --type-uu: string              # Type UUID (use 'project types' to find UUIDs)
    --type-search-key: string      # Type search key (unique identifier for type)
    --description(-d): string      # Optional description of the project
    --template                     # Mark this project as a template
    --entity-uu(-e): string        # Optional entity UUID (uses default if not provided)
    --json(-j): string             # Optional JSON data to store in record_json field
] {
    # Validate that only one type parameter is provided
    if (($type_uu | is-not-empty) and ($type_search_key | is-not-empty)) {
        error make {msg: "Specify either --type-uu or --type-search-key, not both"}
    }
    
    # Handle optional piped parent UUID
    let piped_uuid = $in
    let parent_uuid = if ($piped_uuid | is-not-empty) {
        # Validate that the piped UUID exists in the project table
        psql validate-uuid-table $piped_uuid $STK_PROJECT_TABLE_NAME
    } else {
        null
    }
    
    # Resolve type if search key is provided
    let resolved_type_uu = if ($type_search_key | is-not-empty) {
        (psql get-type-by-search-key $STK_SCHEMA $STK_PROJECT_TABLE_NAME $type_search_key | get uu)
    } else {
        $type_uu
    }
    
    # Handle json parameter
    let record_json = if ($json | is-empty) { 
        {}  # Empty object
    } else { 
        ($json | from json)  # Parse JSON string
    }
    
    # Build parameters record internally - eliminates cascading if/else logic
    let params = {
        name: $name
        type_uu: ($resolved_type_uu | default null)
        description: ($description | default null)
        parent_uu: ($parent_uuid | default null)
        is_template: ($template | default false)
        stk_entity_uu: ($entity_uu | default null)
        record_json: ($record_json | to json)  # Convert back to JSON string for psql new-record
    }
    
    # Single call with all parameters - no more cascading logic
    psql new-record $STK_SCHEMA $STK_PROJECT_TABLE_NAME $params
}

# List the 10 most recent projects from the chuck-stack system
#
# Displays projects in chronological order (newest first) to help you
# monitor recent activity, track project status, or review project portfolio.
# This is typically your starting point for project investigation.
# Use the returned UUIDs with other project commands for detailed work.
# Use --detail to include type information for all projects.
#
# Accepts piped input: none
#
# Examples:
#   project list
#   project list --detail
#   project list | where is_template == true
#   project list --detail | where type_enum == "CLIENT"
#   project list | where is_revoked == false
#   project list | select name description | table
#   project list | where name =~ "client"
#   project list | lines  # Add lines column with all project line items
#   project list | lines | where {|p| ($p.lines | length) > 5}  # Projects with more than 5 lines
#   project list | lines | get lines.0 | flatten  # Get all line items from all projects
#
# Create a useful alias:
#   def pl [] { project list | lines | select name description lines }  # Concise project view with lines
#
# Using elaborate to resolve foreign key references:
#   project list | elaborate                                          # Resolve with default columns
#   project list | elaborate name psql_user                          # Show who created each project
#   project list | elaborate --all | select name created_by_uu_resolved.psql_user  # Creator usernames
#
# Returns: name, description, is_template, is_valid, created, updated, is_revoked, uu, table_name
# Returns (with --detail): Includes type_enum, type_name, type_description from joined type table
# Note: Only shows the 10 most recent projects - use direct SQL for larger queries
export def "project list" [
    --detail(-d)  # Include detailed type information for all projects
    --all(-a)     # Include revoked projects
] {
    # Build complete arguments array including flags
    let args = [$STK_SCHEMA, $STK_PROJECT_TABLE_NAME] | append $STK_PROJECT_COLUMNS
    
    # Add --all flag to args if needed
    let args = if $all { $args | append "--all" } else { $args }
    
    # Choose command and execute with spread - no nested if/else!
    if $detail {
        psql list-records-with-detail ...$args
    } else {
        psql list-records ...$args
    }
}

# Retrieve a specific project by its UUID
#
# Fetches complete details for a single project when you need to
# inspect its contents, verify its state, or extract specific
# data. Use this when you have a UUID from project list or from
# other system outputs. Use --detail to include type information.
#
# Accepts piped input:
#   string - The UUID of the project to retrieve (required via pipe)
#
# Examples:
#   "12345678-1234-5678-9012-123456789abc" | project get
#   project list | get uu.0 | project get
#   $project_uuid | project get | get description
#   $project_uuid | project get --detail | get type_enum
#   $uu | project get | if $in.is_revoked { print "Project was revoked" }
#   $project_uuid | project get | lines  # Get project with all its line items
#   $project_uuid | project get | lines | get lines.0  # Extract just the lines
#
# Returns: name, description, is_template, is_valid, created, updated, is_revoked, uu, table_name
# Returns (with --detail): Includes type_enum, type_name, and other type information
# Error: Returns empty result if UUID doesn't exist
export def "project get" [
    --detail(-d)  # Include detailed type information
] {
    let uu = $in
    
    if ($uu | is-empty) {
        error make { msg: "UUID required via piped input" }
    }
    
    if $detail {
        psql detail-record $STK_SCHEMA $STK_PROJECT_TABLE_NAME $uu
    } else {
        psql get-record $STK_SCHEMA $STK_PROJECT_TABLE_NAME $STK_PROJECT_COLUMNS $uu
    }
}

# Revoke a project by setting its revoked timestamp
#
# This performs a soft delete by setting the revoked column to now().
# Once revoked, projects are considered inactive and won't appear in 
# normal selections. Use this instead of hard deleting to maintain
# audit trails and data integrity in the chuck-stack system.
#
# Accepts piped input: 
#   string - The UUID of the project to revoke (required via pipe)
#
# Examples:
#   project list | where name == "obsolete-project" | get uu.0 | project revoke
#   project list | where is_template == true | each { |row| $row.uu | project revoke }
#   "12345678-1234-5678-9012-123456789abc" | project revoke
#
# Returns: uu, name, revoked timestamp, and is_revoked status
# Error: Command fails if UUID doesn't exist or project is already revoked
export def "project revoke" [] {
    let target_uuid = $in
    
    if ($target_uuid | is-empty) {
        error make { msg: "UUID required via piped input" }
    }
    
    psql revoke-record $STK_SCHEMA $STK_PROJECT_TABLE_NAME $target_uuid
}


# List available project types using generic psql list-types command
#
# Shows all available project types that can be used when creating projects.
# Use this to see valid type options and their descriptions before
# creating new projects with specific types.
#
# Accepts piped input: none
#
# Examples:
#   project types
#   project types | where type_enum == "CLIENT"
#   project types | where is_default == true
#   project types | select type_enum name is_default | table
#
# Returns: uu, type_enum, name, description, is_default, created for all project types
# Note: Uses the generic psql list-types command for consistency across chuck-stack
export def "project types" [] {
    psql list-types $STK_SCHEMA $STK_PROJECT_TABLE_NAME
}



# Add a line item to a project with specified name and type
#
# Creates a new project line (task, milestone, deliverable, or resource) 
# associated with a specific project. Project lines are the detailed work 
# items that make up a project and can be tagged with stk_item for billing.
# The system automatically assigns default values via triggers if type is not specified.
#
# Accepts piped input: project UUID (required)
#
# Examples:
#   $project_uuid | project line new "User Auth Implementation"
#   $project_uuid | project line new "Database Design" --description "Complete database design" --type-search-key "TASK"
#   $project_uuid | project line new "Production Deployment" --type-search-key "MILESTONE" --description "Deploy to production server"
#   $project_uuid | project line new "Requirements Analysis" --template
#   $project_uuid | project line new "API Integration" --json '{"estimated_hours": 40, "priority": "high"}'
#
# Returns: The UUID and name of the newly created project line record
# Note: Uses chuck-stack conventions for automatic entity and type assignment
export def "project line new" [
    name: string                    # The name of the project line
    --type-uu: string              # Type UUID (use 'project line types' to find UUIDs)
    --type-search-key: string      # Type search key (unique identifier for type)
    --description(-d): string      # Optional description of the line
    --template                     # Mark this line as a template
    --entity-uu(-e): string        # Optional entity UUID (uses default if not provided)
    --json(-j): string             # Optional JSON data to store in record_json field
] {
    let project_uu = $in
    
    if ($project_uu | is-empty) {
        error make {msg: "Project UUID is required via piped input."}
    }
    
    # Validate that only one type parameter is provided
    if (($type_uu | is-not-empty) and ($type_search_key | is-not-empty)) {
        error make {msg: "Specify either --type-uu or --type-search-key, not both"}
    }
    
    # Resolve type if search key is provided
    let resolved_type_uu = if ($type_search_key | is-not-empty) {
        (psql get-type-by-search-key $STK_SCHEMA $STK_PROJECT_LINE_TABLE_NAME $type_search_key | get uu)
    } else {
        $type_uu
    }
    
    # Handle json parameter
    let record_json = if ($json | is-empty) { 
        {}  # Empty object
    } else { 
        ($json | from json)  # Parse JSON string
    }
    
    # Build parameters record internally - eliminates cascading if/else logic
    let params = {
        name: $name
        type_uu: ($resolved_type_uu | default null)
        description: ($description | default null)
        is_template: ($template | default false)
        stk_entity_uu: ($entity_uu | default null)
        record_json: ($record_json | to json)  # Convert back to JSON string for psql new-record
    }
    
    # Single call with all parameters - no more cascading logic
    psql new-line-record $STK_SCHEMA $STK_PROJECT_LINE_TABLE_NAME $project_uu $params
}

# List project lines for a specific project
#
# Displays all line items associated with a project to help you
# view project breakdown, track progress, or manage project tasks.
# Shows the most recent lines first for easy review.
#
# Accepts piped input: project UUID (required)
#
# Examples:
#   $project_uuid | project line list
#   $project_uuid | project line list | where is_template == false
#   $project_uuid | project line list | select name description | table
#   $project_uuid | project line list | where name =~ "test"
#   $project_uuid | project line list | elaborate  # Resolve all UUID references
#   $project_uuid | project line list | elaborate | get type_uu_resolved  # See line type details
#
# Returns: name, description, is_template, is_valid, created, updated, is_revoked, uu, table_name
# Note: By default shows only active lines, use --all to include revoked
export def "project line list" [
    --all(-a)  # Include revoked project lines
] {
    let project_uu = $in
    
    if ($project_uu | is-empty) {
        error make {msg: "Project UUID is required via piped input."}
    }
    
    # Build arguments array
    let args = [$STK_SCHEMA, $STK_PROJECT_LINE_TABLE_NAME, $project_uu] | append $STK_PROJECT_LINE_COLUMNS
    
    # Add --all flag if needed
    let args = if $all { $args | append "--all" } else { $args }
    
    psql list-line-records ...$args
}

# Retrieve a specific project line by its UUID
#
# Fetches complete details for a single project line when you need to
# inspect its contents, verify its state, or extract specific
# data. Use this when you have a UUID from project line list or from
# other system outputs. Use --detail to include type information.
#
# Accepts piped input: 
#   string - The UUID of the project line to retrieve (required via pipe)
#
# Examples:
#   project line list $project_uuid | get uu.0 | project line get
#   $line_uuid | project line get | get description
#   $line_uuid | project line get --detail | get type_enum
#   "12345678-1234-5678-9012-123456789abc" | project line get
#
# Returns: name, description, is_template, is_valid, created, updated, is_revoked, uu
# Returns (with --detail): Includes type_enum, type_name, and other type information
# Error: Returns empty result if UUID doesn't exist
export def "project line get" [
    --detail(-d)  # Include detailed type information
] {
    let target_uuid = $in
    
    if ($target_uuid | is-empty) {
        error make {msg: "Project line UUID is required via piped input."}
    }
    
    if $detail {
        psql detail-record $STK_SCHEMA $STK_PROJECT_LINE_TABLE_NAME $target_uuid
    } else {
        psql get-record $STK_SCHEMA $STK_PROJECT_LINE_TABLE_NAME $STK_PROJECT_LINE_COLUMNS $target_uuid
    }
}

# Revoke a project line by setting its revoked timestamp
#
# This performs a soft delete by setting the revoked column to now().
# Once revoked, project lines are considered inactive and won't appear in 
# normal selections. Use this instead of hard deleting to maintain
# audit trails and data integrity in the chuck-stack system.
#
# Accepts piped input: 
#   string - The UUID of the project line to revoke (required via pipe)
#   list - Multiple UUIDs to revoke in bulk
#
# Examples:
#   project line list $project_uuid | where name == "obsolete-task" | get uu.0 | project line revoke
#   project line list $project_uuid | where created < (date now) - 30day | get uu | project line revoke
#   "12345678-1234-5678-9012-123456789abc" | project line revoke
#   [$uuid1, $uuid2, $uuid3] | project line revoke
#
# Returns: uu, name, revoked timestamp, and is_revoked status for each revoked line
# Error: Command fails if UUID doesn't exist or line is already revoked
export def "project line revoke" [] {
    let input_data = $in
    
    if ($input_data | is-empty) {
        error make { msg: "UUID required via piped input" }
    }
    
    # Handle both single UUID (string) and multiple UUIDs (list)
    if ($input_data | describe) == "string" {
        psql revoke-record $STK_SCHEMA $STK_PROJECT_LINE_TABLE_NAME $input_data
    } else if ($input_data | describe) =~ "list" {
        $input_data | each { |uuid| 
            psql revoke-record $STK_SCHEMA $STK_PROJECT_LINE_TABLE_NAME $uuid
        }
    } else {
        error make { msg: "Input must be a string UUID or list of UUIDs" }
    }
}


# List available project line types using generic psql list-types command
#
# Shows all available project line types that can be used when creating lines.
# Use this to see valid type options and their descriptions before
# creating new project lines with specific types.
#
# Accepts piped input: none
#
# Examples:
#   project line types
#   project line types | where type_enum == "MILESTONE"
#   project line types | where is_default == true
#   project line types | select type_enum name is_default | table
#
# Returns: uu, type_enum, name, description, is_default, created for all project line types
# Note: Uses the generic psql list-types command for consistency across chuck-stack
export def "project line types" [] {
    psql list-types $STK_SCHEMA $STK_PROJECT_LINE_TABLE_NAME
}


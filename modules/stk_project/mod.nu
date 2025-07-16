# STK Project Module
# This module provides commands for working with stk_project and stk_project_line tables

# Module Constants
const STK_SCHEMA = "api"
const STK_PROJECT_TABLE_NAME = "stk_project"
const STK_PROJECT_LINE_TABLE_NAME = "stk_project_line"
const STK_PROJECT_COLUMNS = [name, description, is_template, is_valid, record_json]
const STK_PROJECT_LINE_COLUMNS = [name, description, is_template, is_valid, record_json]

# Project module overview
export def "project" [] {
    r#'Projects organize work and financial activities with hierarchical structure.
Projects can contain sub-projects and line items for detailed tracking.

Templates enable reusable project structures.
Projects integrate with timesheets and financial reporting.

Type 'project <tab>' to see available commands.
'#
}

# Create a new project with specified name and type
#
# This is the primary way to create projects in the chuck-stack system.
# Projects represent client work, internal initiatives, research efforts,
# or maintenance activities that can contain multiple line items and tasks.
# The system automatically assigns default values via triggers if type is not specified.
#
# Accepts piped input:
#   string - UUID of parent project for creating sub-projects (optional)
#   record - A record containing a 'uu' field
#   table - A single-row table from commands like 'project list | where'
#
# Examples:
#   project new "Website Redesign"
#   project new "CRM Development" --description "Internal CRM system development"
#   project new "AI Research" --type-search-key "research" --description "Research new AI technologies"
#   "12345678-1234-5678-9012-123456789abc" | project new "Sub-project Name"
#   project list | where name == "Parent Project" | project new "Sub-project Name"
#   project list | first | project new "Child Project" --description "Part of parent project"
#   project new "Data Migration" --json '{"priority": "high", "estimated_hours": 120}'
#   
#   # Interactive examples:
#   project new "Q1 Initiative" --type-search-key INTERNAL --interactive
#   project new "Client Portal" --interactive --description "New customer portal"
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
    --interactive                  # Interactively build JSON data using the type's schema
] {
    # Handle optional piped parent UUID
    let piped_input = $in
    let parent_uuid = if ($piped_input | is-not-empty) {
        # Extract UUID from various input types
        let uuid = ($piped_input | extract-single-uu)
        # Validate that the UUID exists in the project table
        psql validate-uuid-table $uuid $STK_PROJECT_TABLE_NAME
    } else {
        null
    }
    
    # Resolve type using utility function
    let type_record = (resolve-type --schema $STK_SCHEMA --table $STK_PROJECT_TABLE_NAME --type-uu $type_uu --type-search-key $type_search_key)
    
    # Handle JSON input - one line replaces multiple lines of boilerplate
    let record_json = (resolve-json $json $interactive $type_record)
    
    # Build parameters record internally - eliminates cascading if/else logic
    let params = {
        name: $name
        type_uu: ($type_record.uu? | default null)
        description: ($description | default null)
        parent_uu: ($parent_uuid | default null)
        is_template: ($template | default false)
        stk_entity_uu: ($entity_uu | default null)
        record_json: $record_json  # Already a JSON string from parse-json
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
# Type information is always included for all projects.
#
# Accepts piped input: none
#
# Examples:
#   project list
#   project list | where is_template == true
#   project list | where type_enum == "CLIENT"
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
#   project list | elaborate --detail | select name created_by_uu_resolved.psql_user  # Creator usernames
#
# Returns: name, description, is_template, is_valid, created, updated, is_revoked, uu, table_name, type_enum, type_name, type_description
# Note: Only shows the 10 most recent projects - use direct SQL for larger queries
export def "project list" [
    --all(-a)     # Include revoked projects
] {
    # Build complete arguments array including flags
    let args = [$STK_SCHEMA, $STK_PROJECT_TABLE_NAME] | append $STK_PROJECT_COLUMNS
    
    # Add --all flag to args if needed
    let args = if $all { $args | append "--all" } else { $args }
    
    # Execute query
    psql list-records ...$args
}

# Retrieve a specific project by its UUID
#
# Fetches complete details for a single project when you need to
# inspect its contents, verify its state, or extract specific
# data. Use this when you have a UUID from project list or from
# other system outputs. Type information is always included.
#
# Accepts piped input:
#   string - The UUID of the project to retrieve
#   record - A record containing a 'uu' field
#   table - A single-row table from commands like 'project list | where'
#
# Examples:
#   "12345678-1234-5678-9012-123456789abc" | project get
#   project list | get uu.0 | project get
#   project list | where name == "Website Redesign" | project get
#   project list | first | project get
#   $project_uuid | project get | get description
#   $project_uuid | project get | get type_enum
#   $uu | project get | if $in.is_revoked { print "Project was revoked" }
#   $project_uuid | project get | lines  # Get project with all its line items
#   $project_uuid | project get | lines | get lines.0  # Extract just the lines
#   project get --uu "12345678-1234-5678-9012-123456789abc"
#   project get --uu $my_project_uuid
#
# Returns: name, description, is_template, is_valid, created, updated, is_revoked, uu, table_name, type_enum, type_name, and other type information
# Error: Returns empty result if UUID doesn't exist
export def "project get" [
    --uu: string  # UUID as a parameter instead of piped input
] {
    # Extract UUID from piped input or --uu parameter
    let uu = ($in | extract-uu-with-param $uu)
    
    psql get-record $STK_SCHEMA $STK_PROJECT_TABLE_NAME $STK_PROJECT_COLUMNS $uu
}

# Revoke a project by setting its revoked timestamp
#
# This performs a soft delete by setting the revoked column to now().
# Once revoked, projects are considered inactive and won't appear in 
# normal selections. Use this instead of hard deleting to maintain
# audit trails and data integrity in the chuck-stack system.
#
# Accepts piped input: 
#   string - The UUID of the project to revoke
#   record - A record containing a 'uu' field
#   table - A single-row table from commands like 'project list | where'
#
# Examples:
#   project list | where name == "obsolete-project" | get uu.0 | project revoke
#   project list | where name == "obsolete-project" | project revoke
#   project list | where is_template == true | each { |row| $row.uu | project revoke }
#   "12345678-1234-5678-9012-123456789abc" | project revoke
#   project revoke --uu "12345678-1234-5678-9012-123456789abc"
#   project revoke --uu $obsolete_project_uuid
#
# Returns: uu, name, revoked timestamp, and is_revoked status
# Error: Command fails if UUID doesn't exist or project is already revoked
export def "project revoke" [
    --uu: string  # UUID as a parameter instead of piped input
] {
    # Extract UUID from piped input or --uu parameter
    let target_uuid = ($in | extract-uu-with-param $uu)
    
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
# Accepts piped input:
#   string - The UUID of the project (required)
#   record - A record containing a 'uu' field
#   table - A single-row table from commands like 'project list | where'
#
# Examples:
#   $project_uuid | project line new "User Auth Implementation"
#   project list | where name == "My Project" | project line new "Database Design" --description "Complete database design" --type-search-key "TASK"
#   project list | first | project line new "Production Deployment" --type-search-key "MILESTONE" --description "Deploy to production server"
#   $project_uuid | project line new "Requirements Analysis" --template
#   $project_uuid | project line new "API Integration" --json '{"estimated_hours": 40, "priority": "high"}'
#   
#   # Interactive examples:
#   $project_uuid | project line new "Phase 1 Deliverable" --type-search-key MILESTONE --interactive
#   project list | first | project line new "Security Audit" --interactive
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
    --interactive                  # Interactively build JSON data using the type's schema
] {
    # Extract UUID from piped input
    let project_uu = ($in | extract-single-uu --error-msg "Project UUID is required via piped input")
    
    # Resolve type using utility function
    let type_record = (resolve-type --schema $STK_SCHEMA --table $STK_PROJECT_LINE_TABLE_NAME --type-uu $type_uu --type-search-key $type_search_key)
    
    # Handle JSON input - one line replaces multiple lines of boilerplate
    let record_json = (resolve-json $json $interactive $type_record)
    
    # Build parameters record internally - eliminates cascading if/else logic
    let params = {
        name: $name
        type_uu: ($type_record.uu? | default null)
        description: ($description | default null)
        is_template: ($template | default false)
        stk_entity_uu: ($entity_uu | default null)
        record_json: $record_json  # Already a JSON string from parse-json
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
# Accepts piped input:
#   string - The UUID of the project (required)
#   record - A record containing a 'uu' field
#   table - A single-row table from commands like 'project list | where'
#
# Examples:
#   $project_uuid | project line list
#   project list | where name == "My Project" | project line list
#   project list | first | project line list | where is_template == false
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
    # Extract UUID from piped input
    let project_uu = ($in | extract-single-uu --error-msg "Project UUID is required via piped input")
    
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
# other system outputs. Type information is always included.
#
# Accepts piped input: 
#   string - The UUID of the project line to retrieve
#   record - A record containing a 'uu' field
#   table - A single-row table from commands like 'project line list | where'
#
# Examples:
#   $project_uuid | project line list | get uu.0 | project line get
#   $project_uuid | project line list | where name == "Database Design" | project line get
#   $project_uuid | project line list | first | project line get
#   $line_uuid | project line get | get description
#   $line_uuid | project line get | get type_enum
#   "12345678-1234-5678-9012-123456789abc" | project line get
#   project line get --uu "12345678-1234-5678-9012-123456789abc"
#   project line get --uu $my_line_uuid
#
# Returns: name, description, is_template, is_valid, created, updated, is_revoked, uu, type_enum, type_name, and other type information
# Error: Returns empty result if UUID doesn't exist
export def "project line get" [
    --uu: string  # UUID as a parameter instead of piped input
] {
    # Extract UUID from piped input or --uu parameter
    let target_uuid = if ($in | is-empty) {
        if ($uu | is-empty) {
            error make {msg: "Project line UUID is required via piped input or --uu parameter."}
        }
        $uu
    } else {
        ($in | extract-single-uu)
    }
    
    psql get-record $STK_SCHEMA $STK_PROJECT_LINE_TABLE_NAME $STK_PROJECT_LINE_COLUMNS $target_uuid
}

# Revoke a project line by setting its revoked timestamp
#
# This performs a soft delete by setting the revoked column to now().
# Once revoked, project lines are considered inactive and won't appear in 
# normal selections. Use this instead of hard deleting to maintain
# audit trails and data integrity in the chuck-stack system.
#
# Accepts piped input: 
#   string - The UUID of the project line to revoke
#   record - A record containing a 'uu' field
#   table - A single-row table from commands like 'project line list | where'
#   list - Multiple UUIDs to revoke in bulk
#
# Examples:
#   $project_uuid | project line list | where name == "obsolete-task" | get uu.0 | project line revoke
#   $project_uuid | project line list | where name == "obsolete-task" | project line revoke
#   $project_uuid | project line list | where created < (date now) - 30day | get uu | project line revoke
#   "12345678-1234-5678-9012-123456789abc" | project line revoke
#   [$uuid1, $uuid2, $uuid3] | project line revoke
#   project line revoke --uu "12345678-1234-5678-9012-123456789abc"
#   project line revoke --uu $obsolete_line_uuid
#
# Returns: uu, name, revoked timestamp, and is_revoked status for each revoked line
# Error: Command fails if UUID doesn't exist or line is already revoked
export def "project line revoke" [
    --uu: string  # UUID as a parameter instead of piped input
] {
    # Extract UUID from piped input or --uu parameter
    let target_uuid = ($in | extract-uu-with-param $uu)
    
    psql revoke-record $STK_SCHEMA $STK_PROJECT_LINE_TABLE_NAME $target_uuid
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


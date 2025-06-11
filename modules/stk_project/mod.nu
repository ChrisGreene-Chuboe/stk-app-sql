# STK Project Module
# This module provides commands for working with stk_project and stk_project_line tables

# Module Constants
const STK_SCHEMA = "api"
const STK_PRIVATE_SCHEMA = "private"
const STK_PROJECT_TABLE_NAME = "stk_project"
const STK_PROJECT_LINE_TABLE_NAME = "stk_project_line"
const STK_PROJECT_TYPE_TABLE_NAME = "stk_project_type"
const STK_PROJECT_LINE_TYPE_TABLE_NAME = "stk_project_line_type"
const STK_REQUEST_TABLE_NAME = "stk_request"
const STK_DEFAULT_LIMIT = 10
const STK_PROJECT_COLUMNS = "name, description, is_template, is_valid"
const STK_PROJECT_LINE_COLUMNS = "name, description, is_template, is_valid"  
const STK_BASE_COLUMNS = "created, updated, is_revoked, uu"

# Create a new project with specified name and type
#
# This is the primary way to create projects in the chuck-stack system.
# Projects represent client work, internal initiatives, research efforts,
# or maintenance activities that can contain multiple line items and tasks.
# The system automatically assigns default values via triggers if type is not specified.
#
# Accepts piped input: none
#
# Examples:
#   project new "Website Redesign"
#   project new "CRM Development" --description "Internal CRM system development"
#   project new "AI Research" --type "RESEARCH" --description "Research new AI technologies"
#   project new "Server Maintenance" --type "MAINTENANCE" --parent $parent_project_uu
#
# Returns: The UUID and name of the newly created project record
# Note: Uses chuck-stack conventions for automatic entity and type assignment
export def "project new" [
    name: string                    # The name of the project to create
    --type(-t): string             # Project type: CLIENT, INTERNAL, RESEARCH, MAINTENANCE
    --description(-d): string      # Optional description of the project
    --parent(-p): string           # Optional parent project UUID for sub-projects
    --template                     # Mark this project as a template
    --entity-uu(-e): string        # Optional entity UUID (uses default if not provided)
] {
    # Build parameters record internally - eliminates cascading if/else logic
    let params = {
        name: $name
        type_uu: (if ($type | is-empty) { 
            null 
        } else { 
            psql resolve-type $STK_SCHEMA $STK_PROJECT_TYPE_TABLE_NAME $type
        })
        description: ($description | default null)
        parent_uu: ($parent | default null)
        is_template: ($template | default false)
        entity_uu: ($entity_uu | default null)
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
#
# Accepts piped input: none
#
# Examples:
#   project list
#   project list | where is_template == true
#   project list | where is_revoked == false
#   project list | select name description | table
#   project list | where name =~ "client"
#
# Returns: name, description, is_template, is_valid, created, updated, is_revoked, uu
# Note: Only shows the 10 most recent projects - use direct SQL for larger queries
export def "project list" [] {
    psql list-records $STK_SCHEMA $STK_PROJECT_TABLE_NAME $STK_PROJECT_COLUMNS $STK_BASE_COLUMNS $STK_DEFAULT_LIMIT
}

# Retrieve a specific project by its UUID
#
# Fetches complete details for a single project when you need to
# inspect its contents, verify its state, or extract specific
# data. Use this when you have a UUID from project list or from
# other system outputs.
#
# Accepts piped input: none
#
# Examples:
#   project get "12345678-1234-5678-9012-123456789abc"
#   project list | get uu.0 | project get $in
#   $project_uuid | project get $in | get description
#   project get $uu | if $in.is_revoked { print "Project was revoked" }
#
# Returns: name, description, is_template, is_valid, created, updated, is_revoked, uu
# Error: Returns empty result if UUID doesn't exist
export def "project get" [
    uu: string  # The UUID of the project to retrieve
] {
    psql get-record $STK_SCHEMA $STK_PROJECT_TABLE_NAME $STK_PROJECT_COLUMNS $STK_BASE_COLUMNS $uu
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

# Show detailed project information including type using generic psql detail-record command
#
# Provides a comprehensive view of a project by joining with its type
# information. Use this when you need to see the complete context
# of a project including its classification and parent relationships.
#
# Accepts piped input: none
#
# Examples:
#   project detail "12345678-1234-5678-9012-123456789abc"
#   project list | get uu.0 | project detail $in
#   $project_uuid | project detail $in
#
# Returns: Complete project details with type_enum, type_name, and other information
# Note: Uses the generic psql detail-record command for consistency across chuck-stack
export def "project detail" [
    uu: string  # The UUID of the project to get details for
] {
    psql detail-record $STK_SCHEMA $STK_PROJECT_TABLE_NAME $STK_PROJECT_TYPE_TABLE_NAME $uu
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
    psql list-types $STK_SCHEMA $STK_PROJECT_TYPE_TABLE_NAME
}


# Create a request attached to a specific project
#
# This creates a request record that is specifically linked to a project,
# enabling you to create follow-up actions, todos, or investigations
# related to projects. The request is automatically attached to 
# the specified project UUID using the table_name_uu_json convention.
#
# Accepts piped input: 
#   string - UUID of the project to attach the request to (required via pipe)
#
# Examples:
#   $project_uuid | project request --description "need approval for budget increase"
#   "12345678-1234-5678-9012-123456789abc" | project request --description "follow up on client requirements"
#   project list | where name == "critical" | get uu.0 | project request --description "urgent review needed"
#   $project_uu | project request --description "update project documentation"
#
# Returns: The UUID of the newly created request record attached to the project
# Error: Command fails if project UUID doesn't exist or --description not provided
export def "project request" [
    --description(-d): string   # Request description text (required)
] {
    # Validate required description parameter
    if ($description | is-empty) {
        error make {msg: "Request description is required. Use --description to provide request text."}
    }
    
    # Use piped UUID
    let target_uuid = $in
    
    if ($target_uuid | is-empty) {
        error make {msg: "Project UUID is required. Provide as pipe input."}
    }
    
    let request_table = $"($STK_SCHEMA).($STK_REQUEST_TABLE_NAME)"
    let name = "project-request"
    let sql = $"INSERT INTO ($request_table) \(name, description, table_name_uu_json) VALUES \('($name)', '($description)', ($STK_SCHEMA).get_table_name_uu_json\('($target_uuid)')) RETURNING uu"
    
    psql exec $sql
}

# Add a line item to a project with specified name and type
#
# Creates a new project line (task, milestone, deliverable, or resource) 
# associated with a specific project. Project lines are the detailed work 
# items that make up a project and can be tagged with stk_item for billing.
# The system automatically assigns default values via triggers if type is not specified.
#
# Accepts piped input: none
#
# Examples:
#   project line new $project_uuid "User Auth Implementation"
#   project line new $project_uuid "Database Design" --description "Complete database design" --type "TASK"
#   project line new $project_uuid "Production Deployment" --type "MILESTONE" --description "Deploy to production server"
#   project line new $project_uuid "Requirements Analysis" --template
#
# Returns: The UUID and name of the newly created project line record
# Note: Uses chuck-stack conventions for automatic entity and type assignment
export def "project line new" [
    project_uu: string              # The UUID of the project to add the line to
    name: string                    # The name of the project line
    --type(-t): string             # Line type: TASK, MILESTONE, DELIVERABLE, RESOURCE
    --description(-d): string      # Optional description of the line
    --template                     # Mark this line as a template
    --entity-uu(-e): string        # Optional entity UUID (uses default if not provided)
] {
    # Build parameters record internally - eliminates cascading if/else logic
    let params = {
        name: $name
        type_uu: (if ($type | is-empty) { 
            null 
        } else { 
            psql resolve-type $STK_SCHEMA $STK_PROJECT_LINE_TYPE_TABLE_NAME $type
        })
        description: ($description | default null)
        is_template: ($template | default false)
        entity_uu: ($entity_uu | default null)
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
# Accepts piped input: none
#
# Examples:
#   project line list $project_uuid
#   project line list $project_uuid | where is_template == false
#   project line list $project_uuid | select name description | table
#   project line list $project_uuid | where name =~ "test"
#
# Returns: name, description, is_template, is_valid, created, updated, is_revoked, uu
# Note: Shows all non-revoked lines for the specified project
export def "project line list" [
    project_uu: string  # The UUID of the project whose lines to list
] {
    let table = $"($STK_SCHEMA).($STK_PROJECT_LINE_TABLE_NAME)"
    let sql = $"SELECT ($STK_PROJECT_LINE_COLUMNS), ($STK_BASE_COLUMNS) FROM ($table) WHERE header_uu = '($project_uu)' AND is_revoked = false ORDER BY created DESC"
    
    psql exec $sql
}

# Retrieve a specific project line by its UUID
#
# Fetches complete details for a single project line when you need to
# inspect its contents, verify its state, or extract specific
# data. Use this when you have a UUID from project line list or from
# other system outputs.
#
# Accepts piped input: 
#   string - The UUID of the project line to retrieve (required via pipe)
#
# Examples:
#   project line list $project_uuid | get uu.0 | project line get
#   $line_uuid | project line get | get description
#   "12345678-1234-5678-9012-123456789abc" | project line get
#
# Returns: name, description, is_template, is_valid, created, updated, is_revoked, uu
# Error: Returns empty result if UUID doesn't exist
export def "project line get" [] {
    let target_uuid = $in
    
    if ($target_uuid | is-empty) {
        error make {msg: "Project line UUID is required via piped input."}
    }
    
    psql get-record $STK_SCHEMA $STK_PROJECT_LINE_TABLE_NAME $STK_PROJECT_LINE_COLUMNS $STK_BASE_COLUMNS $target_uuid
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

# Show detailed project line information including type using generic psql detail-record command
#
# Provides a comprehensive view of a project line by joining with its type
# information. Use this when you need to see the complete context
# of a line including its classification and project relationship.
#
# Accepts piped input: 
#   string - The UUID of the project line to get details for (required via pipe)
#
# Examples:
#   "12345678-1234-5678-9012-123456789abc" | project line detail
#   project line list $project_uuid | get uu.0 | project line detail
#   $line_uuid | project line detail
#
# Returns: Complete project line details with type_enum, type_name, and other information
# Note: Uses the generic psql detail-record command for consistency across chuck-stack
export def "project line detail" []: string -> record {
    let target_uuid = $in
    
    if ($target_uuid | is-empty) {
        error make {msg: "Project line UUID is required via piped input."}
    }
    
    psql detail-record $STK_SCHEMA $STK_PROJECT_LINE_TABLE_NAME $STK_PROJECT_LINE_TYPE_TABLE_NAME $target_uuid
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
    psql list-types $STK_SCHEMA $STK_PROJECT_LINE_TYPE_TABLE_NAME
}

# Create a request attached to a specific project line
#
# This creates a request record that is specifically linked to a project line,
# enabling you to create follow-up actions, todos, or investigations
# related to specific line items. The request is automatically attached to 
# the specified line UUID using the table_name_uu_json convention.
#
# Accepts piped input: 
#   string - UUID of the project line to attach the request to (required via pipe)
#
# Examples:
#   $line_uuid | project line request --description "need clarification on requirements"
#   "12345678-1234-5678-9012-123456789abc" | project line request --description "blocked waiting for client approval"
#   project line list $project_uuid | where name == "critical" | get uu.0 | project line request --description "urgent assistance needed"
#   $line_uu | project line request --description "update time estimate"
#
# Returns: The UUID of the newly created request record attached to the project line
# Error: Command fails if project line UUID doesn't exist or --description not provided
export def "project line request" [
    --description(-d): string   # Request description text (required)
] {
    # Validate required description parameter
    if ($description | is-empty) {
        error make {msg: "Request description is required. Use --description to provide request text."}
    }
    
    # Use piped UUID
    let target_uuid = $in
    
    if ($target_uuid | is-empty) {
        error make {msg: "Project line UUID is required. Provide as pipe input."}
    }
    
    let request_table = $"($STK_SCHEMA).($STK_REQUEST_TABLE_NAME)"
    let name = "project-line-request"
    let sql = $"INSERT INTO ($request_table) \(name, description, table_name_uu_json) VALUES \('($name)', '($description)', ($STK_SCHEMA).get_table_name_uu_json\('($target_uuid)')) RETURNING uu"
    
    psql exec $sql
}
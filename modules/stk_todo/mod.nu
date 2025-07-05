# STK Todo Module
# This module provides commands for working with todo lists built on the stk_request table

# Module Constants
const STK_SCHEMA = "api"
const STK_TABLE_NAME = "stk_request"
const STK_TODO_TYPE_ENUM = ["TODO"]  # Array for future flexibility - defines module scope
const STK_TODO_COLUMNS = [name, description, table_name_uu_json, record_json, is_processed]

# Todo module overview
export def "todo" [] {
    print "Todos are lightweight tasks built on the request system.
Each todo can have sub-todos for breaking down complex work.

Todos support attachments to link tasks to any chuck-stack record.
Use hierarchical todos to organize work at any level of detail.

Type 'todo <tab>' to see available commands.
"
}

# Create a new todo item with optional attachment to parent todo
#
# This is the primary way to create todos in the chuck-stack system.
# Creates a request record with type_enum in ['TODO']. By default uses 
# the is_default TODO type, or you can specify a specific TODO type.
# You can either pipe in a UUID to attach to a parent todo, or create
# a standalone todo list. The UUID identifies the parent todo this 
# item should be linked to. Use --description for details and --json
# for structured data like due dates or priorities.
#
# Accepts piped input:
#   string - UUID of parent todo to attach this item to (optional)
#   record - Record with 'uu' field to use as parent (optional)
#   table - Table with first row containing parent record (optional)
#
# Examples:
#   todo new "Weekend Projects" --description "Tasks for the weekend"
#   "12345678-1234-5678-9012-123456789abc" | todo new "Fix garden fence" --description "Replace broken posts"
#   todo list | where name == "Home Tasks" | get uu.0 | todo new "Clean garage"
#   todo list | get 0 | todo new "Sub-task" --description "Part of parent todo"
#   todo list | where name == "Home Tasks" | todo new "Paint bedroom"
#   todo new "Buy groceries" --json '{"due_date": "2024-12-31", "priority": "high"}'
#   $parent_uuid | todo new "Mow lawn" --description "Front and back yard"
#   todo new "Work task" --type "work-todo"  # Use specific TODO type
#
# Returns: The UUID of the newly created todo record
# Note: When a UUID is provided via pipe, table_name_uu_json is auto-populated to create hierarchy
export def "todo new" [
    name: string                    # The name of the todo item (required)
    --description(-d): string = ""  # Description of the todo (optional)
    --json(-j): string              # Optional JSON data to store in record_json field
    --type(-t): string              # Specific TODO type name to use (optional, uses default if not specified)
] {
    # Extract parent UUID from piped input (optional for todos)
    let parent_uuid = try {
        ($in | extract-single-uu)
    } catch {
        null  # No parent UUID provided
    }
    
    # Handle json parameter - validate if provided, default to empty object
    let record_json = try { $json | parse-json } catch { error make { msg: $in.msg } }
    
    # Build parameters for psql new-record
    mut params = {
        name: $name,
        description: $description
    }
    
    # Add record_json if provided
    if ($json | is-not-empty) {
        $params = ($params | merge {record_json: $record_json})
    }
    
    # Use enum-aware psql command with parent UUID piped if available
    if ($parent_uuid | is-empty) {
        psql new-record $STK_SCHEMA $STK_TABLE_NAME $params --enum $STK_TODO_TYPE_ENUM --type-name $type
    } else {
        $parent_uuid | psql new-record $STK_SCHEMA $STK_TABLE_NAME $params --enum $STK_TODO_TYPE_ENUM --type-name $type
    }
}

# List todo items from the chuck-stack system
#
# Displays todos in a hierarchical view showing todo lists and their items.
# Only shows requests with type_enum in ['TODO']. By default shows only active 
# (non-revoked) todos. Use --all to include completed (revoked) items. 
# This is typically your starting point for todo management. Use the 
# returned UUIDs with other todo commands. Use --detail to include type 
# information for all todos.
#
# Accepts piped input: none
#
# Examples:
#   todo list
#   todo list --detail
#   todo list --all
#   todo list | where name =~ "Weekend"
#   todo list | where ($it.table_name_uu_json.uu | is-not-empty)  # Show only todo items
#   todo list | where ($it.table_name_uu_json.uu | is-empty)  # Show only todo lists
#   todo list --detail | where type_name == "work-todo"
#
# Using elaborate to resolve foreign key references:
#   todo list | elaborate                                               # Resolve with default columns
#   todo list | elaborate name table_name                               # Show parent todo names
#   todo list | elaborate --all | select name table_name_uu_json_resolved.name  # Show parent names
#
# Returns: name, description, table_name_uu_json, record_json, is_processed, created, updated, is_revoked, uu
# Returns (with --detail): Includes type_enum, type_name, type_description from joined type table
# Note: Results are ordered by creation time and filtered to type_enum in ['TODO']
export def "todo list" [
    --detail(-d)  # Include detailed type information for all todos
    --all(-a)     # Include revoked (completed) todos
] {
    # Build args list with optional --all flag
    let args = if $all {
        [$STK_SCHEMA, $STK_TABLE_NAME] | append $STK_TODO_COLUMNS | append "--all"
    } else {
        [$STK_SCHEMA, $STK_TABLE_NAME] | append $STK_TODO_COLUMNS
    }
    
    psql list-records ...$args --enum $STK_TODO_TYPE_ENUM --detail=$detail
}

# Retrieve a specific todo by its UUID
#
# Fetches complete details for a single todo when you need to
# inspect its contents, verify its state, or extract specific
# data from the record_json field. Only retrieves records with
# type_enum in ['TODO']. Use this when you have a UUID from todo 
# list or from other system outputs. Use --detail to include 
# type information.
#
# Accepts piped input:
#   string - The UUID of the todo to retrieve
#   record - Record with 'uu' field containing the UUID
#   table - Table with first row containing the todo record
#
# Examples:
#   # Using piped input
#   "12345678-1234-5678-9012-123456789abc" | todo get
#   todo list | get uu.0 | todo get
#   todo list | get 0 | todo get
#   todo list | where name == "Buy groceries" | todo get
#   
#   # Using --uu parameter
#   todo get --uu "12345678-1234-5678-9012-123456789abc"
#   todo get --uu $todo_uuid --detail
#   
#   # Practical examples
#   $todo_uuid | todo get | get description
#   todo get --uu $uu | get record_json
#   $uu | todo get | if $in.is_revoked { print "Todo was completed" }
#
# Returns: name, description, table_name_uu_json, record_json, is_processed, created, updated, is_revoked, uu
# Returns (with --detail): Includes type_enum, type_name, and other type information
# Error: Returns empty result if UUID doesn't exist or type_enum not in ['TODO']
export def "todo get" [
    --detail(-d)  # Include detailed type information
    --uu: string  # UUID as parameter (alternative to piped input)
] {
    # Extract UUID from piped input or --uu parameter
    let uu = ($in | extract-uu-with-param $uu)
    
    # Note: psql get-record takes uu as parameter, not piped input
    psql get-record $STK_SCHEMA $STK_TABLE_NAME $STK_TODO_COLUMNS $uu --enum $STK_TODO_TYPE_ENUM --detail=$detail
}

# Mark a todo item as done (revoke)
#
# This performs a soft delete by setting the revoked column to now().
# Once revoked, todos are considered completed and won't appear in 
# normal todo list views. Only works on records with type_enum in ['TODO'].
# Use this to mark tasks as finished while maintaining the audit trail 
# in the chuck-stack system.
#
# Accepts piped input: 
#   string - The UUID of the todo to mark as done
#   record - Record with 'uu' field containing the UUID
#   table - Table with first row containing the todo record
#
# Examples:
#   # Using piped input
#   todo list | where name == "Clean garage" | get uu.0 | todo revoke
#   todo list | get 0 | todo revoke
#   todo list | where name == "Clean garage" | todo revoke
#   "12345678-1234-5678-9012-123456789abc" | todo revoke
#   
#   # Using --uu parameter
#   todo revoke --uu "12345678-1234-5678-9012-123456789abc"
#   todo revoke --uu $todo_uuid
#   
#   # Bulk operations
#   todo list | where created < (date now) - 7day | each { |row| todo revoke --uu $row.uu }
#
# Returns: uu, name, revoked timestamp, and is_revoked status
# Error: Command fails if UUID doesn't exist, is already revoked, or type_enum not in ['TODO']
export def "todo revoke" [
    --uu: string  # UUID as parameter (alternative to piped input)
] {
    # Extract UUID from piped input or --uu parameter
    let target_uuid = ($in | extract-uu-with-param $uu)
    
    # Note: psql revoke-record takes uu as parameter, not piped input
    psql revoke-record $STK_SCHEMA $STK_TABLE_NAME $target_uuid --enum $STK_TODO_TYPE_ENUM
}

# List available TODO types using filtered psql list-types command
#
# Shows all available request types with type_enum in ['TODO'] that can be 
# used when creating todos. This helps you understand the different TODO
# type options available in your system (e.g., personal-todo, work-todo,
# project-todo). The default TODO type is marked with is_default = true.
#
# Accepts piped input: none
#
# Examples:
#   todo types
#   todo types | where is_default == true
#   todo types | where name == "work-todo"
#   todo types | select name description is_default | table
#
# Returns: uu, type_enum, search_key, name, description, is_default, created for types with type_enum in ['TODO']
# Note: Filters psql list-types to show only records with type_enum in ['TODO']
export def "todo types" [] {
    psql list-types $STK_SCHEMA $STK_TABLE_NAME --enum $STK_TODO_TYPE_ENUM
}
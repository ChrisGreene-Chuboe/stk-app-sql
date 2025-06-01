# STK Todo List Module
# This module provides commands for working with todo lists built on the stk_request table

# Module Constants
const STK_SCHEMA = "api"
const STK_PRIVATE_SCHEMA = "private"
const STK_TABLE_NAME = "stk_request"
const STK_DEFAULT_LIMIT = 10
const STK_BASE_COLUMNS = "uu, created, updated, is_revoked"
const STK_TODO_COLUMNS = "name, description, parent_uu"

# Private helper to detect if a string looks like a UUID
def is_uuid_like [
    identifier: string
] {
    ($identifier | str length) == 36 and ($identifier | str contains "-")
}

# Add a new todo list or todo item
#
# This is the primary way to create todos in the chuck-stack system.
# The command takes piped text input and stores it as the todo name.
# Use --parent to specify either the todo list name or UUID directly.
# If no parent is specified, creates a new todo list (top-level item).
#
# Examples:
#   todo add "Weekend Projects"  # Creates a new todo list
#   todo add "Fix garden fence" --parent "Weekend Projects"  # Add item to list by name
#   todo add "Clean garage" --parent "123e4567-e89b-12d3-a456-426614174000"  # Add by UUID
#   "Mow lawn" | todo add --parent "Weekend Projects"  # Pipe in task name
#   "Buy groceries" | todo add  # Creates standalone todo item
#
# Returns: The UUID of the newly created todo record
# Error: Command fails if parent name/UUID doesn't exist
export def "todo add" [
    todo_name?: string           # The name of the todo (optional if piped)
    --parent(-p): string         # Name or UUID of parent todo list
] {
    let name = if ($todo_name | is-empty) { $in } else { $todo_name }
    let table = $"($STK_SCHEMA).($STK_TABLE_NAME)"

    if (not ($parent | is-empty)) {
        # Determine if parent is UUID or name and get the UUID
        let parent_uuid = if (is_uuid_like $parent) {
            # Parent is a UUID - validate it exists
            let parent_lookup = psql exec $"SELECT uu FROM ($table) WHERE uu = '($parent)' AND is_revoked = false LIMIT 1"
            if ($parent_lookup | is-empty) {
                error make { msg: $"Parent todo with UUID '($parent)' not found" }
            }
            $parent
        } else {
            # Parent is a name - look up the UUID
            let parent_lookup = psql exec $"SELECT uu FROM ($table) WHERE name = '($parent)' AND is_revoked = false AND parent_uu IS NULL LIMIT 1"
            if ($parent_lookup | is-empty) {
                error make { msg: $"Parent todo list '($parent)' not found" }
            }
            $parent_lookup | get uu.0
        }
        let sql = $"INSERT INTO ($table) \(name, description, parent_uu) VALUES \('($name)', '($name)', '($parent_uuid)') RETURNING uu"
        psql exec $sql
    } else {
        # Create top-level todo list
        let sql = $"INSERT INTO ($table) \(name, description) VALUES \('($name)', '($name)') RETURNING uu"
        psql exec $sql
    }
}

# List todo lists and items
#
# Displays todos in a hierarchical view showing todo lists and their items.
# By default shows only active (non-revoked) todos. Use --all to include
# completed (revoked) items. Use --parent to show only items under a
# specific todo list.
#
# Examples:
#   todo list  # Show all active todo lists and items
#   todo list --all  # Include completed items
#   todo list --parent "Weekend Projects"  # Show only items in specific list
#   todo list | where parent_uu != null  # Show only todo items (not lists)
#   todo list | where parent_uu == null  # Show only todo lists (not items)
#
# Returns: uu, name, description, parent_uu, created, updated, is_revoked
# Note: Results are ordered by creation time within each hierarchy level
export def "todo list" [
    --all(-a)                    # Include completed (revoked) todos
    --parent(-p): string         # Show only items under this parent list name
] {
    let table = $"($STK_SCHEMA).($STK_TABLE_NAME)"
    let columns = $"($STK_BASE_COLUMNS), ($STK_TODO_COLUMNS)"
    let revoked_filter = if $all { "" } else { "AND is_revoked = false" }

    if (not ($parent | is-empty)) {
        # Show items under specific parent
        let parent_lookup = psql exec $"SELECT uu FROM ($table) WHERE name = '($parent)' AND is_revoked = false AND parent_uu IS NULL LIMIT 1"
        if ($parent_lookup | is-empty) {
            error make { msg: $"Parent todo list '($parent)' not found" }
        }
        let parent_uuid = $parent_lookup | get uu.0
        psql exec $"SELECT ($columns) FROM ($table) WHERE parent_uu = '($parent_uuid)' ($revoked_filter) ORDER BY created ASC"
    } else {
        # Show all todos with hierarchy indication
        psql exec $"SELECT ($columns) FROM ($table) WHERE name IS NOT NULL ($revoked_filter) ORDER BY COALESCE\(parent_uu::text, uu::text), created ASC"
    }
}

# Mark a todo item as done (revoked)
#
# This performs a soft delete by setting the revoked column to now().
# Once revoked, todos are considered completed and won't appear in 
# normal todo list views. Use this to mark tasks as finished while
# maintaining the audit trail in the chuck-stack system.
#
# Examples:
#   todo revoke "Clean garage"  # Mark todo item as done by name
#   todo revoke "12345678-1234-5678-9012-123456789abc"  # Mark done by UUID
#   todo list | where name == "completed task" | get uu.0 | todo revoke $in
#   "task completed successfully" | todo revoke "Fix fence"
#
# Returns: uu, name, revoked timestamp, and is_revoked status
# Error: Command fails if todo doesn't exist or is already revoked
export def "todo revoke" [
    todo_identifier: string      # Name or UUID of the todo to mark as done
] {
    let table = $"($STK_SCHEMA).($STK_TABLE_NAME)"

    # Try to find by UUID first, then by name
    let todo_record = if (is_uuid_like $todo_identifier) {
        # Looks like a UUID
        psql exec $"SELECT uu FROM ($table) WHERE uu = '($todo_identifier)' AND is_revoked = false LIMIT 1"
    } else {
        # Treat as name
        psql exec $"SELECT uu FROM ($table) WHERE name = '($todo_identifier)' AND is_revoked = false LIMIT 1"
    }

    if ($todo_record | is-empty) {
        error make { msg: $"Todo '($todo_identifier)' not found or already completed" }
    }

    let todo_uuid = $todo_record | get uu.0
    psql exec $"UPDATE ($table) SET revoked = now\() WHERE uu = '($todo_uuid)' RETURNING uu, name, revoked, is_revoked"
}

# Restore a completed todo item (un-revoke)
#
# This undoes the revocation by clearing the revoked timestamp,
# making the todo active again. Use this when you need to reopen
# a task that was marked as completed but still needs work.
#
# Examples:
#   todo restore "Clean garage"  # Reopen todo item by name
#   todo restore "12345678-1234-5678-9012-123456789abc"  # Reopen by UUID
#   todo list --all | where name == "needs more work" | get uu.0 | todo restore $in
#
# Returns: uu, name, and is_revoked status (should be false after restore)
# Error: Command fails if todo doesn't exist or is not revoked
export def "todo restore" [
    todo_identifier: string      # Name or UUID of the todo to restore
] {
    let table = $"($STK_SCHEMA).($STK_TABLE_NAME)"

    # Try to find by UUID first, then by name
    let todo_record = if (is_uuid_like $todo_identifier) {
        # Looks like a UUID
        psql exec $"SELECT uu FROM ($table) WHERE uu = '($todo_identifier)' AND is_revoked = true LIMIT 1"
    } else {
        # Treat as name
        psql exec $"SELECT uu FROM ($table) WHERE name = '($todo_identifier)' AND is_revoked = true LIMIT 1"
    }

    if ($todo_record | is-empty) {
        error make { msg: $"Completed todo '($todo_identifier)' not found" }
    }

    let todo_uuid = $todo_record | get uu.0
    psql exec $"UPDATE ($table) SET revoked = null WHERE uu = '($todo_uuid)' RETURNING uu, name, is_revoked"
}

# STK Todo Module

The chuck-stack todo module provides a hierarchical task management system built on the `stk_request` table. It enables creation of todo lists with nested items, tracking work from inception to completion.

## Conceptual Overview

The todo module demonstrates chuck-stack's approach to domain-specific functionality:

- **Hierarchical Structure**: Uses `table_name_uu_json` to create parent-child relationships between todos
- **Request Foundation**: Leverages the full power of the chuck-stack request system
- **Soft Deletion**: Completed todos are revoked, not deleted, maintaining audit trails
- **Type Safety**: Uses the TODO type from `stk_request_type_enum` for proper categorization

## Integration with Chuck-Stack

Todo lists integrate seamlessly with chuck-stack patterns:

- **Pipeline Philosophy**: All UUID operations follow the pipeline-only pattern
- **Generic Commands**: Uses `psql` commands for all database operations
- **Entity Ownership**: Inherits multi-tenant isolation from `stk_request`
- **Convention Compliance**: Follows all [postgres conventions](../../chuckstack.github.io/src-ls/postgres-convention/)

## Available Commands

The todo module provides standard chuck-stack commands:

```nu
todo new        # Create new todo items
todo list       # Browse todos with optional filters
todo get        # Retrieve specific todo details
todo revoke     # Mark todos as completed
todo types      # List available request types
```

**For detailed usage, examples, and parameters, use the built-in help:**

```nu
todo new --help
todo list --help
todo get --help
todo revoke --help
todo types --help
```

## Quick Start Pattern

```nu
# Import the module
use modules *

# Create a top-level todo list
todo new "Weekend Projects" --description "Tasks for the weekend"

# Add items to the list using pipeline
todo list | where name == "Weekend Projects" | get uu.0 | todo new "Fix garden fence"

# View todos
todo list                    # All active todos
todo list --detail           # Include type information
todo list --all              # Include completed todos

# Mark as done
todo list | where name == "Fix garden fence" | get uu.0 | todo revoke

# Get detailed help
todo new --help
```

## Learn More

- [Module Development Standards](../MODULE_DEVELOPMENT.md) - Chuck-stack module patterns
- [STK Request Module](../stk_request/) - Understanding the underlying table
- [Pipeline Patterns](../../chuckstack.github.io/src-ls/postgres-convention/nushell.md) - Nushell integration
- [STK Event Module](../stk_event/) - Canonical example of module structure
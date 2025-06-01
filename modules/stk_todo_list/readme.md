# STK Todo List Module

The chuck-stack todo list system provides a hierarchical way to organize and track tasks through completion. Todo lists manage active work - from simple flat lists to complex nested project structures with unlimited depth.

## Conceptual Overview

**Parent-Child Hierarchy**: Todo lists use the `stk_request` table's `parent_uu` column to create hierarchical relationships. Parent records become list names, while child records become individual todo items.

**Unlimited Depth**: The recursive nature allows for complex nested structures - a project can contain sub-projects, which contain tasks, which contain subtasks. The system prevents circular references while maintaining this flexibility.

**Built on Requests**: Todo lists leverage the full power of the chuck-stack request system, inheriting features like soft deletion, entity ownership, and the complete audit trail.

## Integration with Chuck-Stack

Todo lists integrate with the broader chuck-stack ecosystem:

- **Request Foundation**: Built on `stk_request` table architecture for consistency and power
- **Entity Ownership**: Todo lists belong to specific `stk_entity` records for multi-tenant data isolation
- **Revocation Model**: Uses chuck-stack's `is_revoked` pattern - non-revoked items are active todos, revoked items are done
- **Convention Compliance**: Follows all chuck-stack [postgres conventions](../../chuckstack.github.io/src-ls/postgres-convention/) for consistency

## Available Commands

This module provides commands optimized for todo list workflows:

```nu
todo list           # Browse todo lists and items
todo add            # Add new lists or items
todo revoke         # Mark items as done (revoked)
todo restore        # Reopen items (un-revoke)
```

**For complete usage details, examples, and best practices, use the built-in help:**

```nu
todo list --help
todo add --help
todo revoke --help
todo restore --help
```

## Quick Start

```nu
# Import the module
use modules *

# Create a new todo list
todo add "Weekend Projects"

# Add items to the list (by parent name)
todo add "Fix garden fence" --parent "Weekend Projects"
todo add "Clean garage" --parent "Weekend Projects"

# Add items using parent UUID
todo add "Organize shed" --parent "123e4567-e89b-12d3-a456-426614174000"

# Pipe in a task name
"Mow lawn" | todo add --parent "Weekend Projects"

# View your lists and items
todo list

# Mark an item as done
todo revoke "Clean garage"

# Reopen an item if needed
todo restore "Clean garage"

# Get detailed help for any command
todo add --help
```

## Learn More

- [Chuck-Stack Postgres Conventions](../../chuckstack.github.io/src-ls/postgres-convention/)
- [Column Conventions](../../chuckstack.github.io/src-ls/postgres-convention/column-convention.md) - Understanding parent_uu and is_revoked patterns
- [Sample Table Convention](../../chuckstack.github.io/src-ls/postgres-convention/sample-table-convention.md) - How requests follow chuck-stack patterns
- [STK Request Module](../stk_request/readme.md) - Understanding the underlying request architecture
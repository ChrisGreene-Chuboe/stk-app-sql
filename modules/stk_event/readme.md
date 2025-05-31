# STK Event Module

The chuck-stack event system provides a centralized way to log, track, and audit activity throughout your application. Events capture what happened, when it happened, and preserve an immutable record for compliance, debugging, and business intelligence.

## Conceptual Overview

**Events as Audit Trail**: Every meaningful action in chuck-stack can generate an event - user logins, data changes, system errors, business processes. This creates a comprehensive audit trail that answers "what happened when?"

**Soft Deletion Model**: Events use chuck-stack's revocation pattern rather than hard deletes. This preserves data integrity and maintains complete historical records while marking events as inactive.

**JSON Flexibility**: Events store structured data in JSONB format, allowing rich context while maintaining query performance. This supports both simple text logging and complex structured data.

## Integration with Chuck-Stack

Events integrate with the broader chuck-stack ecosystem:

- **Entity Ownership**: Events belong to specific `stk_entity` records for multi-tenant data isolation
- **Type System**: Events use the chuck-stack type pattern for categorization and automation
- **Convention Compliance**: Follows all chuck-stack [postgres conventions](../../chuckstack.github.io/src-ls/postgres-convention/) for consistency

## Available Commands

This module provides four core commands for event management:

```nu
event list      # Browse recent activity
event get       # Inspect specific events  
event revoke    # Soft delete events
.append event   # Log new events (primary usage)
```

**For complete usage details, examples, and best practices, use the built-in help:**

```nu
event list --help
event get --help  
event revoke --help
.append event --help
```

## Quick Start

```nu
# Import the module
use modules *

# Log an event
"User completed onboarding" | .append event "user-milestone"

# Check recent activity
event list

# Get detailed help for any command
event revoke --help
```

## Learn More

- [Chuck-Stack Postgres Conventions](../../chuckstack.github.io/src-ls/postgres-convention/)
- [Column Conventions](../../chuckstack.github.io/src-ls/postgres-convention/column-convention.md) - Understanding revoked/is_revoked patterns
- [Sample Table Convention](../../chuckstack.github.io/src-ls/postgres-convention/sample-table-convention.md) - How events follow chuck-stack patterns
# STK Event Module

The chuck-stack event system provides a centralized way to log, track, and audit activity throughout your application. Events capture what happened, when it happened, and preserve an immutable record for compliance, debugging, and business intelligence.

## Conceptual Overview

**Events as Audit Trail**: Every meaningful action in chuck-stack can generate an event - user logins, data changes, system errors, business processes. This creates a comprehensive audit trail that answers "what happened when?"

**Soft Deletion Model**: Events use chuck-stack's revocation pattern rather than hard deletes. This preserves data integrity and maintains complete historical records while marking events as inactive.

**Text and Metadata Separation**: Events store primary content in the `description` field for unlimited text, while `record_json` holds structured metadata. This design leverages each field's strengths - direct text storage for content and JSONB for searchable metadata.

**User-Friendly Column Ordering**: Event listings prioritize human-readable content first (name, description, metadata), followed by timestamps and status, with technical identifiers (UUID) last. This "content-first" approach improves usability while keeping all data accessible.

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

# Log simple event
"User completed onboarding" | .append event "user-milestone"

# Log event with metadata
"Login failed" | .append event "authentication" --metadata '{"user_id": 123, "ip": "192.168.1.1"}'

# Check recent activity (shows: name, description, record_json, created, updated, is_revoked, uu)
event list

# Get detailed help for any command
event revoke --help
```

## Learn More

- [Chuck-Stack Postgres Conventions](../../chuckstack.github.io/src-ls/postgres-convention/)
- [Column Conventions](../../chuckstack.github.io/src-ls/postgres-convention/column-convention.md) - Understanding revoked/is_revoked patterns
- [Sample Table Convention](../../chuckstack.github.io/src-ls/postgres-convention/sample-table-convention.md) - How events follow chuck-stack patterns
# STK Request Module

The `stk_request` module provides commands for creating and managing requests in the chuck-stack system. Requests represent calls to action that can exist independently or be attached to any record in the database.

## Core Concepts

**Standalone Requests**: Independent requests that represent general calls to action, todos, or notes that don't need to be tied to specific records.

**Attached Requests**: Requests linked to specific records anywhere in the database using the `table_name_uu_json` convention. The system automatically discovers which table contains the target UUID.

**Request Lifecycle**: Requests flow from creation → processing → completion, with soft deletion via revocation when needed.

## Quick Start

```nushell
# Create standalone request
"Review quarterly budget" | .append request "budget-review"

# Create request attached to existing record
"Fix critical authentication bug" | .append request "auth-fix" --attach $user_uuid

# List recent requests
request list

# Get detailed request info
request get $request_uuid

# Mark request as completed
request process $request_uuid
```

## Integration with Chuck-Stack

Requests integrate with the chuck-stack workflow by:

- **Following postgres conventions**: Standard columns, UUID primary keys, soft deletion
- **Supporting attachments**: Link requests to any record using the `table_name_uu_json` pattern
- **Maintaining audit trails**: Full creation/update tracking with timestamps
- **Enabling automation**: Structured data supports future workflow automation

## Command Overview

Use `<command> --help` for detailed usage, examples, and return values:

- `.append request` - Create new requests with optional record attachment
- `request list` - View recent requests with filtering capabilities  
- `request get` - Retrieve complete request details by UUID
- `request process` - Mark requests as completed
- `request revoke` - Soft delete requests while preserving audit trail

## Learn More

- [Column Conventions](../../chuckstack.github.io/src-ls/postgres-convention/column-convention.md) - Understanding table_name_uu_json pattern
- [stk_event Module](../stk_event/readme.md) - Related event logging functionality
- [Request Database Schema](../../migrations/20241103210360_stk-request.sql) - Complete table structure
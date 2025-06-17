# STK Tag Module

The chuck-stack tag system provides flexible metadata attachment to any record in your database. Tags enable you to add structured or unstructured data to existing records without modifying their schemas, with optional JSON Schema validation for data integrity.

## Conceptual Overview

**Tags as Flexible Metadata**: Tags allow you to attach additional information to any record - addresses to projects, contact details to invoices, notes to items. This creates a flexible extension system that grows with your needs without database migrations.

**Type-Driven Validation**: Each tag has a type that can define JSON Schema validation rules. This ensures data quality - an ADDRESS tag requires street, city, and postal code, while a NOTE tag accepts any text.

**Universal Attachment**: Tags use the `table_name_uu_json` pattern to attach to any record in chuck-stack. This creates a unified way to extend any table with additional attributes.

**Soft Deletion Model**: Tags follow chuck-stack's revocation pattern, preserving historical metadata while marking tags as inactive when no longer needed.

## Integration with Chuck-Stack

Tags integrate with the broader chuck-stack ecosystem:

- **Type System**: Tags use the chuck-stack type pattern for categorization and validation rules
- **Entity Ownership**: Tags belong to specific `stk_entity` records for multi-tenant data isolation
- **Convention Compliance**: Follows all chuck-stack [postgres conventions](../../chuckstack.github.io/src-ls/postgres-convention/) for consistency

## Available Commands

This module provides commands for tag management:

```nu
.append tag    # Attach metadata to any record (primary usage)
tag list       # Browse existing tags
tag get        # Inspect specific tags
tag revoke     # Soft delete tags
tag types      # View available tag types and schemas
```

**For complete usage details, examples, and best practices, use the built-in help:**

```nu
.append tag --help
tag list --help
tag get --help
tag revoke --help
tag types --help
```

## Quick Start

```nu
# Import the module
use modules *

# Tag a project with an address
project list | get uu.0 | .append tag --type-search-key ADDRESS --json '{
    "address1": "123 Main St",
    "city": "Austin", 
    "postal": "78701"
}'

# Add a simple note
$invoice_uu | .append tag --type-search-key NOTE --description "Requires special handling"

# List all tags (shows: search_key, description, table_name_uu_json, record_json, created, updated, is_revoked, uu)
tag list

# View available tag types and their schemas
tag types

# Get detailed help for any command
.append tag --help
```

## Tag Types

Chuck-stack includes predefined tag types with validation schemas:

- **ADDRESS** - Physical addresses with required fields
- **EMAIL** - Email contact information
- **PHONE** - Phone contact information
- **NOTE** - Free-form text notes
- **NONE** - General purpose with no validation

View all available types and their schemas with `tag types`.

## Learn More

- [Chuck-Stack Postgres Conventions](../../chuckstack.github.io/src-ls/postgres-convention/)
- [Table Name UU JSON Pattern](../../chuckstack.github.io/src-ls/postgres-convention/table-name-uu-json.md) - How tags attach to records
- [Type System](../../chuckstack.github.io/src-ls/postgres-convention/sample-table-convention.md) - Understanding chuck-stack types
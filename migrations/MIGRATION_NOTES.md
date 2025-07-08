# Chuck-Stack Migration Notes

This document provides chuck-stack specific guidance for creating database migrations. For migration execution and management, see the [chuck-stack-nushell-psql-migration](/chuck-stack-nushell-psql-migration/) tool documentation - reference as 'documentation' from here on.

## Table of Contents

- [Quick Start](#quick-start)
- [Chuck-Stack Migration Patterns](#chuck-stack-migration-patterns)
  - [Creating New First-Class Citizens](#creating-new-first-class-citizens)
  - [Type Tables and Enums](#type-tables-and-enums)
  - [Extending Existing Enums](#extending-existing-enums)
- [Key Design Decisions](#key-design-decisions)
- [Testing Migrations](#testing-migrations)
- [Migration Checklist](#migration-checklist)
- [References](#references)
- [Document Maintenance Guidelines](#document-maintenance-guidelines)

## Quick Start

1. **Create migration file**: `YYYYMMDDHHMMSS_track_description.sql`
2. **Follow sample table convention**: Copy from [sample-table-convention.md](../../chuckstack.github.io/src-ls/postgres-convention/sample-table-convention.md)
4. **Test locally**: Use test environment (see [TESTING_NOTES.md](../test/TESTING_NOTES.md))

## Tracks

The default track is 'core'. See 'documentation' for more information about track.

## Not In Production

Note that the chuck-stack is not in production yet. As a result, you may modify exiting migration scripts as you deem appropriate.

## Enum Modification

There are times when you need to update an existing enum and types to support new migrations. The business partner is a great example. We needed to add new stk_tags to support maintaining business partners.

Note that when adding additional enum comment records that we need to call the following to propagate the respective tag type records.

```
SELECT private.stk_table_type_create('stk_tag_type');
```

## Chuck-Stack Migration Patterns

### Type Tables and Enums

**Key Pattern**: Store JSON schemas nested under `json_schema` key in `enum_comment.record_json`.

**Example**: Search for "ADDRESS" in `20241104143010_core_stk-tag.sql` to see the standard pattern.

**Important**: Always nest schemas under `json_schema` key. This allows `record_json` to store additional metadata beyond just the schema.

The system automatically creates type records via `stk_table_type_create()`.

### Extending Existing Enums

For adding values to existing enums (like new tag types):

```sql
-- Add enum value
ALTER TYPE private.stk_tag_type_enum ADD VALUE IF NOT EXISTS 'BP_CUSTOMER';

-- Document with schema
INSERT INTO private.enum_comment (enum_type, enum_value, comment, is_default, record_json) VALUES
('stk_tag_type_enum', 'BP_CUSTOMER', 'Business Partner customer role', false, 
    '{"pg_jsonschema": {...}}'::jsonb);

-- Create type records
SELECT private.stk_table_type_create('stk_tag_type');
```

## Migration Checklist

- [ ] Used sample table convention as template
- [ ] Documented all prompting decisions in SQL comments
- [ ] Stored JSON schemas in enum_comment.record_json
- [ ] Called `stk_trigger_create()` after table creation
- [ ] Called `stk_table_type_create()` for type records
- [ ] Tested in local test environment
- [ ] Migration is idempotent where possible

## References

- **Migration Execution**: [chuck-stack-nushell-psql-migration](../../../chuck-stack-nushell-psql-migration/) - Tool for applying migrations
- **Table Creation Template**: [sample-table-convention.md](../../chuckstack.github.io/src-ls/postgres-convention/sample-table-convention.md) - Copy and modify
- **Testing Environment**: [TESTING_NOTES.md](../test/TESTING_NOTES.md) - Local testing setup
- **Column Conventions**: [column-convention.md](../../chuckstack.github.io/src-ls/postgres-convention/column-convention.md)
- **Postgres Conventions**: [postgres-convention/](../../chuckstack.github.io/src-ls/postgres-convention/) directory

## Document Maintenance Guidelines

### Core Principles
- **Clear and concise**: Remove redundancy, focus on essential information
- **Logical flow**: Start with overview, progress to specifics, end with references
- **Serve AI needs**: Provide concrete templates that can be directly applied
- **Prioritize references over examples**: If there is existing code that serves as an example, provide the search term to find the code
- **Avoid line numbers**: Use searchable string references (e.g., "see Parameters Record Pattern")
- **Avoid direct file references**: use searchable string references instead
- **Current patterns only**: Remove historical context and deprecated approaches
- **Maintain TOC**: Update table of contents when adding or removing major sections

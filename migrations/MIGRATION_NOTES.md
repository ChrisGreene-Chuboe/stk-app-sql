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

1. **Get timestamp**: `date +%Y%m%d%H%M%S`
2. **Copy template**: `cp sample-table.sql.template YYYYMMDDHHMMSS_core_stk-tablename.sql`
3. **Convert to partitioned** (if needed): `./sample-table-convert-to-partition.sh YYYYMMDDHHMMSS_core_stk-tablename.sql`
4. **Replace changeme**: `sed -i 's/changeme/tablename/g' YYYYMMDDHHMMSS_core_stk-tablename.sql`
5. **Make design decisions**: Search for `----Prompt:` and work through each one individually:
   - Read the prompt question
   - Think about your specific use case
   - Uncomment the line if needed
   - Make one decision at a time
6. **Test locally**: Use test environment (see Testing Migrations section below)

## Creating New Tables - Step by Step

### The Iterative Decision Process

When creating a new table, work through the template methodically:

1. **Search for prompts**: Use your editor to search for `----Prompt:`
2. **Process one at a time**: Each prompt asks a specific question about your table's needs
3. **Think before uncommenting**: Consider your use case carefully for each decision
4. **Document your reasoning**: Add a comment explaining why you made each choice

### Common Prompt Decisions

The template includes these key decision points:

- **Entity assignment**: Do records need accounting/billing/permissions? → Uncomment `stk_entity_uu`
- **JSON storage**: Need flexible metadata? → Uncomment `record_json`
- **Table references**: Need to link to other tables? → Uncomment `table_name_uu_json`
- **Templates**: Need reusable configurations? → Uncomment `is_template`
- **Validation**: Need data validation? → Uncomment `is_valid`
- **Hierarchies**: Need parent/child in same table? → Uncomment `parent_uu`
- **Master/detail**: Is this a line item table? → Uncomment `header_uu`
- **Processing**: Need to track processing status? → Uncomment `processed`/`is_processed`

### Example Decision Flow

```bash
# Search for prompts
grep -n "----Prompt:" 20250713120000_core_stk-request.sql

# For each prompt, ask yourself:
# 1. What is this feature for?
# 2. Does my use case need it?
# 3. What are the implications of including it?

# Example: "Do you need to assign this record to a specific entity?"
# Think: Will requests be associated with specific customers/vendors?
# Decision: Yes → Uncomment the stk_entity_uu line
```

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

### File Creation
- [ ] Generated timestamp with `date +%Y%m%d%H%M%S`
- [ ] Copied from `sample-table.sql.template`
- [ ] Decided on partitioning strategy (if needed, converted early)
- [ ] Replaced all instances of `changeme` with your table name

### Design Decisions
- [ ] Searched for all `----Prompt:` comments
- [ ] Made each decision one at a time
- [ ] Uncommented only the features needed
- [ ] Added comments explaining key decisions

### Chuck-Stack Requirements
- [ ] Enum values documented in `enum_comment` table
- [ ] Type table has appropriate default enum value
- [ ] Called `stk_trigger_create()` after table creation
- [ ] Called `stk_table_type_create()` for type records
- [ ] Removed all `----partition:` markers (if converted)

### Testing
- [ ] Tested in local test environment
- [ ] Verified all constraints work as expected
- [ ] Checked that triggers fire correctly
- [ ] Confirmed enum and type records created

## References

### Templates and Tools
- **Table Template**: `sample-table.sql.template` - Starting point for all new tables
- **Partition Converter**: `sample-table-convert-to-partition.sh` - Converts normal tables to partitioned
- **Migration Execution**: [chuck-stack-nushell-psql-migration](../../../chuck-stack-nushell-psql-migration/) - Tool for applying migrations

### Testing and Development
- **Testing Environment**: [TESTING_NOTES.md](../test/TESTING_NOTES.md) - Local testing setup
- **Module Development**: [MODULE_DEVELOPMENT.md](../modules/MODULE_DEVELOPMENT.md) - Creating nushell modules for new tables

### Conventions and Standards
- **Table Creation Template**: [sample-table-convention.md](../../chuckstack.github.io/src-ls/postgres-convention/sample-table-convention.md) - Historical reference
- **Column Conventions**: [column-convention.md](../../chuckstack.github.io/src-ls/postgres-convention/column-convention.md)
- **Enum and Type Conventions**: [enum-type-convention.md](../../chuckstack.github.io/src-ls/postgres-convention/enum-type-convention.md)
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

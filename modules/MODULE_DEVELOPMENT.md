# Chuck-Stack Module Development Guide

This guide provides patterns for creating chuck-stack nushell modules. Modules expose database functionality through pipeline-oriented commands following consistent patterns.

## Table of Contents

- [Quick Start](#quick-start)
- [Business Logic Placement](#business-logic-placement)
- [Module Structure](#module-structure)
- [Module Categories](#module-categories)
- [Database Schema Context](#database-schema-context)
- [Core Patterns](#core-patterns)
  - [1. Flag Convention: --all vs --detail](#1-flag-convention-all-vs-detail)
  - [2. Unnamed Parameter Convention](#2-unnamed-parameter-convention)
  - [3. Parameters Record Pattern](#3-parameters-record-pattern)
  - [4. UUID Input Operations](#4-uuid-input-operations)
  - [5. Generic PSQL Commands](#5-generic-psql-commands)
  - [6. Module Constants](#6-module-constants)
  - [7. Type Support](#7-type-support)
  - [8. Header-Line Pattern](#8-header-line-pattern)
  - [9. Parent-Child Pattern](#9-parent-child-pattern)
  - [10. JSON Parameter Pattern](#10-json-parameter-pattern)
  - [11. JSON Column Convention](#11-json-column-convention)
  - [12. Dynamic Command Building](#12-dynamic-command-building)
  - [13. UUID Input Enhancement Pattern](#13-uuid-input-enhancement-pattern)
  - [14. Utility Functions Pattern](#14-utility-functions-pattern)
  - [15. Data Enrichment Pattern](#15-data-enrichment-pattern)
  - [16. Template Pattern](#16-template-pattern)
  - [17. Foreign Key Pipeline Pattern](#17-foreign-key-pipeline-pattern)
  - [18. Edit Pattern (Update in CRUD)](#18-edit-pattern-update-in-crud)
  - [19. Transactional Document Pattern](#19-transactional-document-pattern)
- [Implementation Guide](#implementation-guide)
- [Module Development Checklist](#module-development-checklist)
- [Documentation Standards](#documentation-standards)
- [Reference Implementations](#reference-implementations)
- [Appendix: Common Pitfalls](#appendix-common-pitfalls)
- [Document Maintenance Guidelines](#document-maintenance-guidelines)

## Quick Start

To create a new module:
1. Copy an existing module (e.g., `stk_item` for single table, `stk_project` for header-line)
2. Update constants (schema, table name, columns)
3. Adjust command parameters for your business logic
4. Write conceptual README
5. Test all command variations

## Business Logic Placement

**Critical Rule**: Business logic belongs in the database, not in nushell modules. This ensures consistency across CLI and PostgREST API access.

**Database**: Calculations, validations, defaults, state transitions, data integrity rules
**Nushell**: Command parsing, output formatting, user interaction, database function orchestration

See `stk_invoice` (future) for complex business logic patterns.

## Module Structure

```nushell
# STK [Module] Module
# This module provides commands for working with stk_[table] tables

# Module Constants
const STK_SCHEMA = "api"
const STK_TABLE_NAME = "stk_module"
const STK_MODULE_COLUMNS = [name, description, is_template, is_valid]
# Add record_json if table has this column:
# const STK_MODULE_COLUMNS = [name, description, is_template, is_valid, record_json]

# Module overview (see Documentation Standards for details)
export def "module" [] { ... }

# Commands: new, list, get, revoke, types
```

### File Organization
```
stk_module/
├── mod.nu      # Module implementation
└── README.md   # Conceptual documentation
```

## Module Categories

Chuck-stack modules fall into three primary categories:

### 1. Database Table Modules
Most chuck-stack modules expose database tables and follow standard CRUD patterns:
- **Pattern**: Implement new, list, get, revoke, and optionally types commands
- **Constants**: STK_SCHEMA, STK_TABLE_NAME, STK_[TABLE]_COLUMNS
- **Implementation**: Follow [Core Patterns](#core-patterns) and [Implementation Guide](#implementation-guide)
- **Examples**: See [Database Table Modules](#database-table-modules-1) in Reference Implementations

### 2. System Wrapper Modules  
Utility modules that wrap external commands and system tools:
- **Pattern**: Provide nushell-friendly interfaces to external tools
- **Constants**: Tool-specific (e.g., STK_AI_TOOL, STK_DEFAULT_MODEL)
- **Key Considerations**:
  - Error handling for external command failures
  - Use `complete` pattern for external commands
  - Provide clear documentation about prerequisites
- **Examples**: See [System Wrapper Modules](#system-wrapper-modules-1) in Reference Implementations

### 3. Domain Wrapper Modules
Modules that provide specialized interfaces to existing tables:
- **Pattern**: Add domain-specific commands while delegating to base modules
- **Constants**: Reference wrapped table (STK_TABLE_NAME points to wrapped table)
- **Key Considerations**:
  - Use `.append` pattern for attachments (see [Pattern 9](#9-parent-child-pattern))
  - Handle `table_name_uu_json` explicitly when wrapping event/request tables
  - Delegate to base module's generic commands
- **Examples**: See [Domain Wrapper Modules](#domain-wrapper-modules-1) in Reference Implementations

Choose your module category before proceeding with implementation patterns below.

## Database Schema Context

### First-Class Citizen Tables
Chuck-stack concepts (first-class citizen tables) always include:
- Main table (e.g., `stk_project`)
- Accompanying `_type` table (e.g., `stk_project_type`)
- Standard columns and triggers for chuck-stack behavior

**Creating new concepts**: 
- Refer to sample-table-convention in postgres-convention documentation for the complete migration template and prompting process
- See [MIGRATION_NOTES.md](../migrations/MIGRATION_NOTES.md) for chuck-stack specific migration patterns, type tables, enums, and testing guidance

### Working with Existing Tables
Most modules expose existing tables. Before implementing:
- Verify table structure and column names
- Check for existing `_type` table
- Understand any special relationships (header-line, attachments)

## Core Patterns

### 1. Flag Convention: --all vs --detail

Chuck-stack uses consistent flag meanings across all commands:

**`--all` Flag**
- Purpose: Include ALL records (both active and revoked)
- Usage: Only for commands that filter records by revocation status
- SQL Impact: Removes `WHERE is_revoked = false` clause
- Example: `project list --all` returns active AND revoked projects

**`--detail` Flag**
- Purpose: Include ALL columns in the output (select *)
- Usage: For any command that returns columnar data
- SQL Impact: Changes from specific column list to `SELECT *`
- Example: `lines --detail` returns all columns for each line record

**Reference**: See `lines` command in stk_psql for the correct implementation pattern.

### 2. Unnamed Parameter Convention

Commands use unnamed positional parameters for their most common use case, with flags for alternative/advanced options:

```nushell
# Primary use case gets unnamed parameter
project new "Project Name"           # Name is always needed
item new "Widget"                    # Name is the primary input
.append address "123 Main St"        # Natural language is expected default

# Alternative/advanced cases use flags
.append address --json '{"address1": "123 Main St"}'  # Direct JSON is advanced
todo new "Task" --json '{"priority": "high"}'         # JSON metadata is optional
```

**Key principles:**
- Most common/natural input gets the unnamed parameter
- Alternative methods use explicit flags (--json, --file, etc.)
- Makes simple things simple, complex things possible
- Reduces cognitive load for common operations

This pattern creates intuitive UX where the default behavior matches user expectations.

### 3. Parameters Record Pattern

Creation commands use a parameters record to eliminate cascading if/else logic:

```nushell
# Build parameters record
let params = {
    name: $name
    type_uu: ($resolved_type_uu | default null)
    description: ($description | default null)
    parent_uu: ($parent | default null)  # For parent-child relationships
    is_template: ($template | default false)
    entity_uu: ($entity_uu | default null)
}

# Single call with all parameters
psql new-record $STK_SCHEMA $STK_TABLE_NAME $params
```

### 4. UUID Input Operations

Commands operating on existing records accept UUIDs via piped input or --uu parameter:

```nushell
# String UUID (traditional)
$uuid | project get
$uuid | project revoke
$project_uuid | project line list

# Table input (from list/where commands)
project list | where name == "My Project" | project get
project list | where name == "My Project" | project line list

# Record input
project list | first | project revoke

# Parameter option
project get --uu $uuid
```

For consistent implementation across all commands:
- Use `extract-single-uu` utility from stk_utility module
- Support string, record, and table input types
- See Pattern 12 for implementation details

### 5. Generic PSQL Commands

All modules use standardized commands from `stk_psql`:
- `psql new-record` - Create with parameters record
- `psql new-line-record` - Create header-line records  
- `psql list-records` - List records (always includes type information)
- `psql list-line-records` - List lines for header
- `psql get-record` - Retrieve single record (always includes type information)
- `psql revoke-record` - Soft delete
- `psql list-types` - List available types
- `psql get-type` - Resolve type by key or name

### 6. Module Constants

```nushell
const STK_SCHEMA = "api"
const STK_TABLE_NAME = "stk_module"  
const STK_MODULE_COLUMNS = [name, description, is_template, is_valid]
# Add record_json if table has this column:
# const STK_MODULE_COLUMNS = [name, description, is_template, is_valid, record_json]
```

**Column Priority Pattern**: The STK_MODULE_COLUMNS constant defines column display priority, not data filtering. All commands return complete data (SELECT *), but columns listed here appear first in the output. This ensures important business data is immediately visible while maintaining access to all fields.

Note: Base columns (created, updated, uu, etc.) are handled by psql commands.

### 7. Type Support

Modules with business classification include:
- Type resolution in creation (--type-uu or --type-search-key)
- `module types` command to list available types
- Type information is always included in get/list commands (no flag needed)

### 8. Header-Line Pattern

For related tables (e.g., project/project_line):
- Line creation receives header UUID via pipe (accepts string/record/table)
- Line listing receives header UUID via pipe (accepts string/record/table)
- Line operations receive line UUID via pipe
- Supports bulk operations on lists
- Use `extract-single-uu` utility for flexible input handling
- Line numbers auto-generate as 10, 20, 30... via database trigger

**Automatic Line Numbering**:
Chuck-stack provides automatic line numbering for header-line tables through the `t10120_stk_line_number` trigger function:
- Generates sequential numbers (10, 20, 30...) when search_key not provided
- Allows manual override by providing specific search_key value
- Applied to tables listed in `stk_trigger_mgt` table
- To enable for your line table: Search for "t10120_stk_line_number" in migrations

For data enrichment, see:
- `lines` command in stk_psql for adding line data to headers
- Pattern #15: Data Enrichment Pattern

### 9. Parent-Child Pattern

For hierarchical relationships within the same table (e.g., project sub-projects):
- Parent is provided via piped input to creation command
- Accepts flexible input types: UUID string, record with 'uu' field, or table
- Validation ensures parent UUID exists in the same table
- Enables tree structures for categories, organizations, or project hierarchies

```nushell
# Create parent
let parent = (project new "Q4 Initiative")

# Create child - multiple input options:
# Option 1: Pipe UUID string
$parent.uu.0 | project new "Phase 1 - Research"

# Option 2: Pipe table (from list/where commands)
project list | where name == "Q4 Initiative" | project new "Phase 2 - Implementation"

# Option 3: Pipe record
project list | first | project new "Phase 3 - Deployment"

# Implementation pattern using extract-single-uu utility
let piped_input = $in
let parent_uuid = if ($piped_input | is-not-empty) {
    # Extract UUID from various input types
    let uuid = ($piped_input | extract-single-uu)
    # Validate parent exists in same table
    psql validate-uuid-table $uuid $STK_TABLE_NAME
} else {
    null
}
```

For data enrichment, see:
- `children` command in stk_psql for adding child data to parents
- Pattern #15: Data Enrichment Pattern

### 10. JSON Parameter Pattern

For tables with `record_json` column, provide structured metadata storage with both direct and interactive input methods:

```nushell
# Parameter definition in creation commands
--json(-j): string      # Optional JSON data to store in record_json field
--interactive           # Interactively build JSON data using the type's schema
```

**Standard implementation with resolve-json utility:**
```nushell
# Resolve type and JSON in two clean lines
let type_record = (resolve-type --schema $STK_SCHEMA --table $STK_TABLE_NAME --type-uu $type_uu --type-search-key $type_search_key)
let record_json = (resolve-json $json $interactive $type_record)
```

**How resolve-json works:**
- Validates --json and --interactive are mutually exclusive
- For interactive: Validates type has schema, launches interactive builder
- For direct JSON: Validates syntax and returns string
- Returns "{}" when neither is provided
- Single line replaces 15+ lines of conditional logic

**Interactive mode features:**
- Guided input based on JSON schema from type record
- Field validation (required fields, data types, enums)
- Review before accepting
- Edit capability to refine data
- Type-specific prompts and help text

**Reference implementations:**
- **Complete pattern**: See `contact new` for full implementation
- **Interactive flow**: See `interactive-json` in stk_utility module
- **Type schemas**: See migration files for json_schema definitions in type tables

**Key principles:**
- Two lines of code handle all JSON scenarios (type + JSON resolution)
- Support both programmatic (--json) and interactive input
- Validate JSON syntax before sending to database
- Let pg_jsonschema handle schema validation
- Consistent error messages across all modules
- Available for all creation commands (.append, new, add)

### 11. JSON Column Convention

Chuck-stack uses strict naming conventions for JSON columns that enable automatic JSONB handling:

**Core Rules:**
- All JSON columns end with `_json` suffix (e.g., `record_json`, `table_name_uu_json`)
- All JSON columns use PostgreSQL `jsonb` type (never `json`)
- Never embed SQL in modules - use psql commands which auto-detect `_json` columns

**Reference implementations:**
- **JSONB auto-detection**: Search for "str ends-with _json" in stk_psql
- **Usage pattern**: See `.append request` in stk_request for params usage
- **Migration**: Search for "jsonb" in migrations for table definitions

### 12. Dynamic Command Building
Optional flags are passed via args array to enable clean command composition:

```nushell
# Build args array with optional flags
let args = [$STK_SCHEMA, $STK_TABLE_NAME] | append $STK_MODULE_COLUMNS
let args = if $all { $args | append "--all" } else { $args }
let args = if $templates { $args | append "--templates" } else { $args }

# Single invocation point
psql list-records ...$args
```

This pattern avoids nested if/else blocks when combining optional parameters.

### 13. UUID Input Enhancement Pattern

Commands accept UUIDs through multiple input types:
- String UUID (backward compatible)
- Single record with 'uu' field  
- Table (uses first row)
- --uu parameter (alternative to piped input)

Uses `extract-uu-table-name` and `extract-uu-with-param` utilities from stk_utility.
Reference: stk_request module for complete implementation.

### 14. Utility Functions Pattern

Utility functions in `stk_utility` reduce boilerplate and standardize common patterns across modules.

**Design Philosophy**:
- **Internal use**: Utilities are called from module code, not directly by end users
- **Positional over flags**: For utilities, prefer positional arguments to enable clean one-liners
- **Trade-offs accepted**: Less self-documenting interfaces are acceptable for internal functions
- **Consistency**: All modules should use the same utilities for the same patterns

**When to Use Positional Arguments**:
```nushell
# Utility functions: Use positional for composability
let record_json = (resolve-json $json $interactive $type_record)

# End-user commands: Use flags for clarity
contact new "John" --json '{"email": "john@example.com"}' --interactive
```

**Current Utility Functions**:

**Type and JSON Resolution**:
- `resolve-type`: Resolves type record from various parameters or fetches default
- `resolve-json`: Handles JSON validation and interactive mode in one line

**UUID Extraction**:
- `extract-single-uu`: UUID extraction with validation from piped input only
- `extract-uu-with-param`: UUID extraction from piped input OR --uu parameter
- `extract-uu-table-name`: Extract both UUID and table name with flexible input
- `extract-attach-from-input`: Attachment data extraction

**Key Principles**:
- Positional arguments enable single-line usage without conditional branching
- The "unkindness" of positional arguments is hidden from end users
- Module developers understand the patterns and parameter order
- Utilities should handle all validation and error messages consistently

**Reference implementations**:
- See `resolve-type` and `resolve-json` in stk_utility for positional patterns
- See `contact new` for one-line utility usage replacing 15+ lines of boilerplate

### 15. Data Enrichment Pattern

Chuck-stack enriches records through pipeline commands that add columns containing related data. Two utilities handle different relationship types.

#### Polymorphic References (table_name_uu_json)
**Utility**: `psql append-table-name-uu-json`
- Finds records that **point TO** the input records
- The enriching table has a `table_name_uu_json` column that can reference any table
- Example: "Find all tags attached to this project"
- Query pattern: `WHERE table_name_uu_json = {table_name: "stk_project", uu: "..."}`
- Module wrappers: `tags`, `events`, `requests`

#### Traditional Foreign Keys
**Utility**: `psql append-foreign-key`  
- Finds records that **reference** the input via specific FK column
- The enriching table has dedicated FK columns (e.g., `stk_business_partner_uu`)
- Example: "Find all contacts belonging to this business partner"
- Query pattern: `WHERE stk_business_partner_uu = "..."`
- FK column is dynamically determined from input table name
- Module wrapper: `contacts`

#### Built-in Enrichments
Generic commands for structural relationships:
- `lines` - Header-line pattern (`_line` tables)
- `children` - Parent-child relationships
- `elaborate` - Inline FK resolution

#### Implementation
Modules create one-line wrappers:
```nushell
export def tags [...columns: string --detail(-d) --all(-a)] {
    $in | psql append-table-name-uu-json $STK_SCHEMA $STK_TABLE_NAME "tags" $STK_TAG_COLUMNS ...$columns --detail=$detail --all=$all
}
```

Reference: Search for `psql append-table-name-uu-json` and `psql append-foreign-key` commands

### 16. Template Pattern

Templates provide reusable configurations that serve as starting points for creating new records. They are excluded from normal operational listings to keep the interface focused on active data.

#### Behavior Rules
1. **Default List**: Excludes templates (`WHERE is_template = false`)
2. **Template List**: Shows only templates with `--templates` flag
3. **Complete List**: Shows everything with `--all` flag (templates AND revoked records)
4. **Direct Access**: Templates can be retrieved by UUID with `get` command

#### Implementation in psql
The `psql list-records` command handles template filtering automatically:
- Default: `WHERE is_revoked = false AND is_template = false`
- `--templates`: `WHERE is_template = true`
- `--all`: No WHERE clause (shows everything)

Tables without an `is_template` column continue to work normally.

#### Key Principles
- Templates are operational data, not system configuration
- Template filtering is handled by psql for consistency
- The `--all` flag shows ALL data: active, revoked, and templates
- Template creation uses `--template` flag on `new` command
- Only tables with `is_template` column support templates
- Templates can have tags just like regular records

#### Future Considerations
Templates with tags present interesting design questions that need further exploration:
- Should template tags be copied when creating records from templates?
- How should tag inheritance work in template hierarchies?
- Should there be template-specific tag types?

These questions will be addressed in a future project focused on template-tag interactions.

Reference implementation: `bp list` in stk_business_partner/mod.nu

### 17. Foreign Key Pipeline Pattern

Creates cross-table relationships by piping parent records into creation commands.

**Distinct from Parent-Child Pattern**: This handles relationships between different tables (e.g., business_partner → contact), not hierarchical same-table relationships.

**Implementation approach**:
1. Extract piped input with `extract-uu-table-name` utility
2. Build foreign key column name: `{table_name}_uu`
3. Validate column exists with `column-exists` from stk_psql
4. Error clearly if invalid: "Cannot link X to Y - no foreign key relationship exists"
5. Add to params with `upsert`

**Key principles**:
- Pipeline input overrides explicit parameters
- Validate before attempting database insert
- User-friendly errors instead of PostgreSQL internals
- Maintains backward compatibility with UUID parameters

**Reference**: See `contact new` for complete implementation including column validation and error handling.

### 18. Edit Pattern (Update in CRUD)

Provides update capability for existing records, focusing on modifying specific fields while preserving others.

**Implementation approach**:
1. Extract UUID from piped input or `--uu` parameter
2. Fetch existing record with `psql get-record`
3. Validate record exists (handle empty results gracefully)
4. Update specific fields based on mode:
   - Direct update with `--json` parameter
   - Interactive update with `--interactive` flag
5. Execute UPDATE via `psql exec`
6. Return complete updated record

**Key design decisions**:
- Start with single field updates (e.g., `record_json` only)
- Use `edit` command name (shorter and clearer than `update`)
- Support both programmatic and interactive modes
- Validate inputs before database operations
- Return full record for verification

**Interactive mode integration**:
- Leverage existing `interactive-json --edit` functionality
- Show current values during editing
- Type-aware with JSON schema validation
- Consistent with creation patterns

**Reference**: See `contact edit` for implementation with JSON field updates.

### 19. Transactional Document Pattern

Specialized variant of the header-line pattern for financial and transactional documents that require specific constraints.

**Key characteristics**:
- No `name` column - uses `search_key` for document numbering
- Required `stk_entity_uu` - all transactions must be entity-assigned
- Header-line structure with transactional semantics
- Often includes `processed/is_processed` columns
- Direct foreign key relationships (e.g., to business partners)

**Implementation differences from standard header-line**:
1. **Module constants** - exclude `name` from column lists:
   ```nushell
   const STK_INVOICE_COLUMNS = [search_key, description, is_template, is_valid, record_json]
   ```
2. **Creation commands** - accept search_key instead of name:
   ```nushell
   export def "invoice new" [
       search_key: string  # The unique identifier/number (e.g., "INV-2024-001")
   ```
3. **Line numbering** - search_key used for line numbers:
   ```nushell
   # Lines use numeric search_keys: "10", "20", "30" for ordering
   $invoice_uuid | invoice line new "10" --description "First line item"
   ```

**Document numbering patterns**:
- Headers: Document-type prefixed (INV-2024-001, BILL-2024-001)
- Lines: Numeric sequence (10, 20, 30) allowing insertions

**When to use**:
- Financial documents (invoices, bills, credit memos)
- Formal transactions requiring audit trails
- Documents with legal/compliance requirements
- Any header-line that represents a transaction vs. master data

**Reference**: See `stk_invoice` for complete transactional document implementation including both header and line handling.

## Implementation Guide

### Step 1: Define Module Constants

```nushell
const STK_SCHEMA = "api"
const STK_TABLE_NAME = "stk_module"
const STK_MODULE_COLUMNS = [name, description, is_template, is_valid]
# Add record_json if table has this column:
# const STK_MODULE_COLUMNS = [name, description, is_template, is_valid, record_json]
```

### Step 2: Identify Required Patterns

Examine your table structure to determine which patterns to implement:

**Table Structure → Pattern Mapping:**
- Foreign key columns (e.g., `stk_business_partner_uu`) → **Foreign Key Pipeline Pattern**
- `parent_uu` column → **Parent-Child Pattern**
- Associated line table (e.g., `stk_project_line`) → **Header-Line Pattern**
- `is_template` column → **Template Pattern**
- `record_json` column → **JSON Parameter Pattern**
- Associated `_type` table → **Type Support**
- `table_name_uu_json` column → **UUID Input Enhancement Pattern**
- No `name` column + required `stk_entity_uu` + line table → **Transactional Document Pattern**

**Common Pattern Combinations:**
- Single table with types: Type Support + JSON Parameter Pattern
- Master-detail relationships: Header-Line Pattern + Type Support
- Hierarchical data: Parent-Child Pattern + Type Support
- Cross-table relationships: Foreign Key Pipeline Pattern + Type Support
- Financial documents: Transactional Document Pattern + Type Support + Foreign Key Pipeline

### Step 3: Implement Commands Based on Patterns

**Base Commands (all modules):**
- `new` - Create record
- `list` - List records with `--all` flag
- `get` - Retrieve single record
- `revoke` - Soft delete record

**Pattern-Specific Commands:**

**Edit Pattern** adds:
- `edit` - Update existing records
- Support for `--json` and/or `--interactive` modes
- Focus on specific fields (often `record_json` first)

**Type Support** adds:
- `types` command to list available types
- `--type-uu` and `--type-search-key` parameters to `new`

**Header-Line Pattern** adds:
- `line new` - Create lines for a header
- `line list` - List lines for a header
- `line get` - Get specific line
- `line revoke` - Revoke line(s)

**Parent-Child Pattern** enhances:
- `new` command accepts parent via pipeline

**Foreign Key Pipeline Pattern** enhances:
- `new` command accepts foreign records via pipeline

**Template Pattern** enhances:
- `list` command with `--templates` flag
- `new` command with `--template` flag

**JSON Parameter Pattern** enhances:
- Creation commands with `--json` parameter

**Reference Implementations by Pattern:**
- **Basic CRUD only**: `stk_item`
- **+ Foreign Key Pipeline**: `stk_contact` 
- **+ Header-Line + Parent-Child**: `stk_project`
- **+ Type Support + Templates**: `stk_business_partner`
- **+ Attachment patterns**: `stk_event`
- **Domain wrapper**: `stk_todo` (wraps `stk_request`)

## Module Development Checklist

Choose the appropriate checklist based on your module category:

### For Database Table Modules:
- [ ] Define module constants (schema, table, columns)
- [ ] Add module overview command (e.g., `export def "module" []`)
- [ ] Check if table has `record_json` column
- [ ] If yes, include `record_json` in column constants
- [ ] Implement `new` command with parameters record
- [ ] If table has `record_json`, add `--json` parameter to creation commands
- [ ] Implement `list` command with --all flag
- [ ] Implement `get` command with pipeline UUID input
- [ ] Implement `revoke` command with pipeline UUID input
- [ ] Add --uu parameter to get/revoke commands
- [ ] Use stk_utility functions for UUID/attachment extraction
- [ ] Add `types` command if table has associated types
- [ ] Add header-line commands if applicable
- [ ] Write comprehensive help documentation
- [ ] Create README.md focusing on concepts
- [ ] Test all command variations (see "Testing Requirements" in TESTING_NOTES.md)
- [ ] Test JSON functionality: valid JSON, invalid JSON, empty/missing JSON
- [ ] Test string/record/table input modes
- [ ] Add module export to parent `modules/mod.nu` file

### For System Wrapper Modules:
- [ ] Define tool-specific constants
- [ ] Add module overview command if appropriate
- [ ] Implement error handling for external commands
- [ ] Document prerequisites and installation requirements
- [ ] Use `complete` pattern for external command execution
- [ ] Write comprehensive help documentation
- [ ] Create README.md explaining tool integration
- [ ] Test with and without external tool available

### For Domain Wrapper Modules:
- [ ] Define constants referencing wrapped table
- [ ] Add module overview command (e.g., `export def "todo" []`)
- [ ] Implement domain-specific commands using `.append` or similar patterns
- [ ] Delegate to base module commands appropriately
- [ ] Write comprehensive help documentation
- [ ] Create conceptual README
- [ ] Test integration with base module

## Documentation Standards

### Module Overview Command
Each module should export a base command (e.g., `bp`, `item`, `project`) that provides module discovery:
```nushell
# Module overview command (place after module constants)
export def "module" [] {
    r#'Brief description of what this module manages.
One-line explanation of key concepts or relationships.

Additional context if needed (types, patterns, integrations).
Keep to 4-6 lines maximum.

Type 'module <tab>' to see available commands.
'#
}
```

This command:
- Executes when users type the module name alone
- Returns a raw string (not prints) for clean test integration
- Provides immediate context about the module's purpose
- Guides users to tab completion for command discovery
- Keeps output minimal (under 8 lines total)
- Includes trailing newline for visual spacing
- Uses raw string syntax `r#'...'#` for clean multiline text

### Command Help
Each command must include:
- Purpose and context
- Pipeline input specification
- Multiple practical examples
- Return value description
- Error conditions

### Module README
Focus on:
- Module purpose and chuck-stack integration
- Conceptual overview (not command details)
- Quick start examples
- Links to related documentation

## Reference Implementations

### Database Table Modules
- **`stk_tag`** - Uses new one-line `parse-json` pattern for `--json` parameter ✓
- **`stk_item`** - Clean single-table module with `--json` parameter ✓
- **`stk_project`** - Complete header-line pattern with `--json` for both header and lines ✓
- **`stk_contact`** - Foreign key pipeline pattern with column validation, Edit pattern ✓
- **`stk_event`** - Specialized attachment patterns with `--json` parameter ✓
- **`stk_request`** - Uses `--json` with direct SQL construction ✓
- **`stk_todo`** - Domain wrapper with `--json` parameter ✓
- **`stk_business_partner`** - Business entity module with `--json` parameter ✓

All modules now use the modern one-line JSON pattern:
`let record_json = try { $json | parse-json } catch { error make { msg: $in.msg } }`

UUID extraction patterns:
- Modern `extract-uu-with-param`: stk_request, stk_todo, stk_tag
- Older manual pattern: stk_item, stk_project, stk_event

### System Wrapper Modules
- **`stk_psql`** - PostgreSQL command wrapper with structured output parsing
- **`stk_ai`** - AI tool wrapper for text transformation

### Domain Wrapper Modules
- **`stk_todo`** - Wraps `stk_request` table for todo list functionality
- **`stk_address`** - Wraps `stk_tag` table with AI-powered address parsing and JSON schema validation
- **`stk_timesheet`** - Wraps `stk_event` table for time tracking

## Appendix: Common Pitfalls

### Nushell Syntax
- **Escape parentheses in SQL**: `$"SELECT COUNT\(*) FROM table"`  
- **No mutable captures in closures**: Create immutable copy before closure: `let final = $mutable`
- **Variable declarations**: Use `let` for immutable, `mut` for mutable (NOT `let mut`)
- **Optional parameters**: Omit them, don't pass `null` (e.g., use `some-func` not `some-func null`)

### Design Guidelines
- **Pipeline-only UUIDs**: Never accept UUID as optional parameter
- **No custom SQL**: Always use psql generic commands
- **Include type support**: If table has `_type` companion
- **Support bulk operations**: Accept lists where logical
- **Type handling**: PostgreSQL results may return `list<any>` - extract-uu-table-name handles this automatically
- **Flag consistency**: Use `--all` only for including revoked records, use `--detail` for all columns (see Flag Convention pattern and `lines` command in stk_psql)

## Document Maintenance Guidelines

### Core Principles
- **Clear and concise**: Remove redundancy, focus on essential information
- **Logical flow**: Start with overview, progress to specifics, end with references
- **Serve AI needs**: Provide concrete templates that can be directly applied
- **Prioritize references over examples**: If there is existing code that serves as an example, provide the search term to find the code
- **Avoid line numbers**: Use searchable string references (e.g., "see Parameters Record Pattern")
- **Avoid direct file references**: use searchable string references instead
- **Avoid pattern numbers**: Reference patterns by name only as sections may be reordered
- **Current patterns only**: Remove historical context and deprecated approaches
- **Maintain TOC**: Update table of contents when adding or removing major sections

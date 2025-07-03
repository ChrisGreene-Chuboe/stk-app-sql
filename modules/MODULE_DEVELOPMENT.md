# Chuck-Stack Module Development Guide

This guide provides patterns for creating chuck-stack nushell modules. Modules expose database functionality through pipeline-oriented commands following consistent patterns.

## Table of Contents

- [Quick Start](#quick-start)
- [Business Logic Placement](#business-logic-placement)
- [Module Structure](#module-structure)
- [Module Categories](#module-categories)
- [Database Schema Context](#database-schema-context)
- [Core Patterns](#core-patterns)
  - [1. Parameters Record Pattern](#1-parameters-record-pattern)
  - [2. UUID Input Operations](#2-uuid-input-operations)
  - [3. Generic PSQL Commands](#3-generic-psql-commands)
  - [4. Module Constants](#4-module-constants)
  - [5. Type Support](#5-type-support)
  - [6. Header-Line Pattern](#6-header-line-pattern)
  - [7. Parent-Child Pattern](#7-parent-child-pattern)
  - [8. JSON Parameter Pattern](#8-json-parameter-pattern)
  - [9. Dynamic Command Building](#9-dynamic-command-building)
  - [10. UUID Input Enhancement Pattern](#10-uuid-input-enhancement-pattern)
  - [11. Utility Functions Pattern](#11-utility-functions-pattern)
  - [12. Data Enrichment Pattern](#12-data-enrichment-pattern)
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
  - Use `.append` pattern for attachments (see [Pattern 7](#7-parent-child-pattern))
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

**Creating new concepts**: Refer to sample-table-convention in postgres-convention documentation for the complete migration template and prompting process.

### Working with Existing Tables
Most modules expose existing tables. Before implementing:
- Verify table structure and column names
- Check for existing `_type` table
- Understand any special relationships (header-line, attachments)

## Core Patterns

### 1. Parameters Record Pattern

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

### 2. UUID Input Operations

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
- See Pattern 10 for implementation details

### 3. Generic PSQL Commands

All modules use standardized commands from `stk_psql`:
- `psql new-record` - Create with parameters record
- `psql new-line-record` - Create header-line records  
- `psql list-records` - List with optional --detail
- `psql list-line-records` - List lines for header
- `psql get-record` - Retrieve single record
- `psql detail-record` - Get with type information
- `psql revoke-record` - Soft delete
- `psql list-types` - List available types
- `psql get-type` - Resolve type by key or name

### 4. Module Constants

```nushell
const STK_SCHEMA = "api"
const STK_TABLE_NAME = "stk_module"  
const STK_MODULE_COLUMNS = [name, description, is_template, is_valid]
# Add record_json if table has this column:
# const STK_MODULE_COLUMNS = [name, description, is_template, is_valid, record_json]
```

Note: Base columns (created, updated, uu, etc.) are handled by psql commands.

### 5. Type Support

Modules with business classification include:
- Type resolution in creation (--type-uu or --type-search-key)
- `module types` command to list available types
- `--detail` flag on get/list commands for type information

### 6. Header-Line Pattern

For related tables (e.g., project/project_line):
- Line creation receives header UUID via pipe (accepts string/record/table)
- Line listing receives header UUID via pipe (accepts string/record/table)
- Line operations receive line UUID via pipe
- Supports bulk operations on lists
- Use `extract-single-uu` utility for flexible input handling

For data enrichment, see:
- `lines` command in stk_psql for adding line data to headers
- Pattern #12: Data Enrichment Pattern

### 7. Parent-Child Pattern

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
- Pattern #12: Data Enrichment Pattern

### 8. JSON Parameter Pattern

For tables with `record_json` column, provide structured metadata storage:

```nushell
# Parameter definition in creation commands
--json(-j): string  # Optional JSON data to store in record_json field

# Standard handling pattern
let record_json = if ($json | is-empty) { 
    {}  # Empty object (default behavior)
} else { 
    ($json | from json)  # Parse JSON string
}

# Include in parameters record
let params = {
    name: $name
    type_uu: ($resolved_type_uu | default null)
    description: ($description | default null)
    # ... other fields ...
    record_json: ($record_json | to json)  # Convert back to JSON string for psql
}
```

**Key principles:**
- Parameter name is always `--json` (not --metadata or other variants)
- Default to empty object `{}` when not provided
- Parse on input, stringify for database
- Available for all creation commands (.append, new, add)

### 9. Dynamic Command Building
Optional flags are passed via args array to enable clean command composition:

```nushell
# Build args array with optional flag
let args = [$STK_SCHEMA, $STK_TABLE_NAME] | append $STK_MODULE_COLUMNS
let args = if $all { $args | append "--all" } else { $args }

# Single invocation point
if $detail {
    psql list-records-with-detail ...$args
} else {
    psql list-records ...$args
}
```

This pattern avoids nested if/else blocks when combining optional parameters.

### 10. UUID Input Enhancement Pattern

Commands accept UUIDs through multiple input types:
- String UUID (backward compatible)
- Single record with 'uu' field  
- Table (uses first row)
- --uu parameter (alternative to piped input)

Uses `extract-uu-table-name` and `extract-single-uu` utilities from stk_utility.
Reference: stk_request module for complete implementation.

### 11. Utility Functions Pattern

Reduce boilerplate with stk_utility functions:
- `extract-single-uu`: UUID extraction with validation
- `extract-attach-from-input`: Attachment data extraction

Reference: stk_request `.append request` for both utilities.

### 12. Data Enrichment Pattern

Chuck-stack provides data enrichment through pipeline commands that add columns containing related records.

#### Generic Commands (stk_psql)
- `lines` - Adds header-line data (see `lines --help` for examples)
- `children` - Adds parent-child data (see `children --help` for examples)
- `psql append-table-name-uu-json` - Generic pattern for module-specific enrichment

#### Module-Specific Commands
Modules wrap the generic pattern:
- `tags` in stk_tag
- `events` in stk_event
- `requests` in stk_request

#### Key Principles
- Graceful degradation (empty arrays for unsupported patterns)
- Consistent column selection: default, specific columns, or --all
- Pipeline composability
- Automatic capability detection

Reference implementations:
- `lines` command in stk_psql/mod.nu
- `children` command in stk_psql/mod.nu
- `tags` command in stk_tag/mod.nu for module pattern

## Implementation Guide

### Step 1: Define Module Constants

```nushell
const STK_SCHEMA = "api"
const STK_TABLE_NAME = "stk_module"
const STK_MODULE_COLUMNS = [name, description, is_template, is_valid]
# Add record_json if table has this column:
# const STK_MODULE_COLUMNS = [name, description, is_template, is_valid, record_json]
```

### Step 2: Implement Core Commands

#### Creation Command
```nushell
export def "module new" [
    name: string
    --type-uu: string
    --type-search-key: string  
    --description(-d): string
    --template
    --entity-uu(-e): string
    --json(-j): string       # Optional JSON data (if table has record_json column)
] {
    # Type resolution
    let resolved_type_uu = if ($type_search_key | is-not-empty) {
        (psql get-type $STK_SCHEMA $STK_TABLE_NAME --search-key $type_search_key | get uu)
    } else {
        $type_uu
    }
    
    # Handle JSON parameter (if table has record_json column)
    let record_json = if ($json | is-empty) { 
        {}  # Empty object
    } else { 
        ($json | from json)  # Parse JSON string
    }
    
    # Build parameters
    let params = {
        name: $name
        type_uu: ($resolved_type_uu | default null)
        description: ($description | default null)
        is_template: ($template | default false)
        entity_uu: ($entity_uu | default null)
        # record_json: ($record_json | to json)  # Add if table has record_json column
    }
    
    # For .append commands with attachments, use extract-attach-from-input - see stk_request
    psql new-record $STK_SCHEMA $STK_TABLE_NAME $params
}
```

#### List Command  
```nushell
export def "module list" [
    --detail(-d)
    --all(-a)
] {
    let args = [$STK_SCHEMA, $STK_TABLE_NAME] | append $STK_MODULE_COLUMNS
    let args = if $all { $args | append "--all" } else { $args }
    
    if $detail {
        psql list-records-with-detail ...$args
    } else {
        psql list-records ...$args
    }
}
```

#### Get Command
```nushell
export def "module get" [
    --detail(-d)
    --uu: string  # UUID as parameter (alternative to piped input)
] {
    # Extract UUID using utility function
    let uu = ($in | extract-single-uu --uu $uu)
    
    if $detail {
        psql detail-record $STK_SCHEMA $STK_TABLE_NAME $uu
    } else {
        psql get-record $STK_SCHEMA $STK_TABLE_NAME $STK_MODULE_COLUMNS $uu
    }
}
```

#### Revoke Command
```nushell
export def "module revoke" [
    --uu: string  # UUID as parameter (alternative to piped input)
] {
    # Extract UUID using utility function
    let target_uuid = ($in | extract-single-uu --uu $uu)
    
    psql revoke-record $STK_SCHEMA $STK_TABLE_NAME $target_uuid
}
```

#### Types Command (if applicable)
```nushell
export def "module types" [] {
    psql list-types $STK_SCHEMA $STK_TABLE_NAME
}
```

### Step 3: Add Header-Line Commands (if needed)

For modules with line tables, add:
- `module line new` - Creates lines for a header
- `module line list` - Lists lines for a header  
- `module line get` - Gets specific line
- `module line revoke` - Revokes line(s)

## Module Development Checklist

Choose the appropriate checklist based on your module category:

### For Database Table Modules:
- [ ] Define module constants (schema, table, columns)
- [ ] Check if table has `record_json` column
- [ ] If yes, include `record_json` in column constants
- [ ] Implement `new` command with parameters record
- [ ] If table has `record_json`, add `--json` parameter to creation commands
- [ ] Implement `list` command with --detail and --all flags
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

### For System Wrapper Modules:
- [ ] Define tool-specific constants
- [ ] Implement error handling for external commands
- [ ] Document prerequisites and installation requirements
- [ ] Use `complete` pattern for external command execution
- [ ] Write comprehensive help documentation
- [ ] Create README.md explaining tool integration
- [ ] Test with and without external tool available

### For Domain Wrapper Modules:
- [ ] Define constants referencing wrapped table
- [ ] Implement domain-specific commands using `.append` or similar patterns
- [ ] Delegate to base module commands appropriately
- [ ] Write comprehensive help documentation
- [ ] Create conceptual README
- [ ] Test integration with base module

## Documentation Standards

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
- **`stk_item`** - Clean single-table module with `--json` parameter
- **`stk_project`** - Complete header-line pattern with `--json` for both header and lines
- **`stk_event`** - Specialized attachment patterns with `--json` parameter
- **`stk_tag`** - Advanced `--json` usage with schema validation (see `stk_address` for implementation)
- **`stk_request`** - Simple `--json` implementation

Enhanced modules with UUID input pattern: stk_request, stk_todo, stk_tag, stk_event, stk_item, stk_project

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

### Design Guidelines
- **Pipeline-only UUIDs**: Never accept UUID as optional parameter
- **No custom SQL**: Always use psql generic commands
- **Include type support**: If table has `_type` companion
- **Support bulk operations**: Accept lists where logical
- **Type handling**: PostgreSQL results may return `list<any>` - extract-uu-table-name handles this automatically

## Document Maintenance Guidelines

### Core Principles
- **Clear and concise**: Remove redundancy, focus on essential information
- **Logical flow**: Start with overview, progress to specifics, end with references
- **Serve AI needs**: Provide concrete examples and templates that can be directly applied
- **Avoid line numbers**: Use searchable string references (e.g., "see Parameters Record Pattern")
- **Current patterns only**: Remove historical context and deprecated approaches
- **Maintain table of contents**: Update TOC when adding/removing major sections
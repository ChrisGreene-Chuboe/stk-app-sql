# Chuck-Stack Module Development Guide

This guide provides patterns for creating chuck-stack nushell modules. Modules expose database functionality through pipeline-oriented commands following consistent patterns.

## Table of Contents

- [Quick Start](#quick-start)
- [Module Structure](#module-structure)
- [Database Schema Context](#database-schema-context)
- [Core Patterns](#core-patterns)
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

## Module Structure

```nushell
# STK [Module] Module
# This module provides commands for working with stk_[table] tables

# Module Constants
const STK_SCHEMA = "api"
const STK_TABLE_NAME = "stk_module"
const STK_MODULE_COLUMNS = [name, description, is_template, is_valid]

# Commands: new, list, get, revoke, types
```

### File Organization
```
stk_module/
├── mod.nu      # Module implementation
└── README.md   # Conceptual documentation
```

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
    parent_uu: ($parent | default null)
    is_template: ($template | default false)
    entity_uu: ($entity_uu | default null)
}

# Single call with all parameters
psql new-record $STK_SCHEMA $STK_TABLE_NAME $params
```

### 2. Pipeline-Only UUID Operations

Commands operating on existing records require UUIDs via piped input:

```nushell
# Examples
$uuid | project get
$uuid | project revoke
$project_uuid | project line list
```

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
- `psql get-type-by-search-key` - Resolve type by key

### 4. Module Constants

```nushell
const STK_SCHEMA = "api"
const STK_TABLE_NAME = "stk_module"  
const STK_MODULE_COLUMNS = [name, description, is_template, is_valid]
```

Note: Base columns (created, updated, uu, etc.) are handled by psql commands.

### 5. Type Support

Modules with business classification include:
- Type resolution in creation (--type-uu or --type-search-key)
- `module types` command to list available types
- `--detail` flag on get/list commands for type information

### 6. Header-Line Pattern

For related tables (e.g., project/project_line):
- Line creation receives header UUID via pipe
- Line listing receives header UUID via pipe
- Line operations receive line UUID via pipe
- Supports bulk operations on lists

### 7. Dynamic Command Building
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

## Implementation Guide

### Step 1: Define Module Constants

```nushell
const STK_SCHEMA = "api"
const STK_TABLE_NAME = "stk_module"
const STK_MODULE_COLUMNS = [name, description, is_template, is_valid]
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
] {
    # Type resolution
    let resolved_type_uu = if ($type_search_key | is-not-empty) {
        (psql get-type-by-search-key $STK_SCHEMA $STK_TABLE_NAME $type_search_key | get uu)
    } else {
        $type_uu
    }
    
    # Build parameters
    let params = {
        name: $name
        type_uu: ($resolved_type_uu | default null)
        description: ($description | default null)
        is_template: ($template | default false)
        entity_uu: ($entity_uu | default null)
    }
    
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
] {
    let uu = $in
    
    if ($uu | is-empty) {
        error make { msg: "UUID required via piped input" }
    }
    
    if $detail {
        psql detail-record $STK_SCHEMA $STK_TABLE_NAME $uu
    } else {
        psql get-record $STK_SCHEMA $STK_TABLE_NAME $STK_MODULE_COLUMNS $uu
    }
}
```

#### Revoke Command
```nushell
export def "module revoke" [] {
    let target_uuid = $in
    
    if ($target_uuid | is-empty) {
        error make { msg: "UUID required via piped input" }
    }
    
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

- [ ] Define module constants (schema, table, columns)
- [ ] Implement `new` command with parameters record
- [ ] Implement `list` command with --detail and --all flags
- [ ] Implement `get` command with pipeline UUID input
- [ ] Implement `revoke` command with pipeline UUID input
- [ ] Add `types` command if table has associated types
- [ ] Add header-line commands if applicable
- [ ] Write comprehensive help documentation
- [ ] Create README.md focusing on concepts
- [ ] Test all command variations

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

- **`stk_item`** - Clean single-table module
- **`stk_project`** - Complete header-line pattern
- **`stk_psql`** - Generic command implementations
- **`stk_event`** - Specialized attachment patterns

## Appendix: Common Pitfalls

### Nushell Syntax
- **Escape parentheses in SQL**: `$"SELECT COUNT\(*) FROM table"`  
- **No mutable captures in closures**: Use immutable variables or reduce pattern

### Design Guidelines
- **Pipeline-only UUIDs**: Never accept UUID as optional parameter
- **No custom SQL**: Always use psql generic commands
- **Include type support**: If table has `_type` companion
- **Support bulk operations**: Accept lists where logical

## Document Maintenance Guidelines

### Core Principles
- **Clear and concise**: Remove redundancy, focus on essential information
- **Logical flow**: Start with overview, progress to specifics, end with references
- **Serve AI needs**: Provide concrete examples and templates that can be directly applied
- **Avoid line numbers**: Use searchable string references (e.g., "see Parameters Record Pattern")
- **Current patterns only**: Remove historical context and deprecated approaches
- **Maintain table of contents**: Update TOC when adding/removing major sections
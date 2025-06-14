# Chuck-Stack Module Development Guide (Updated 2025)

This guide reflects the evolved practices for creating chuck-stack nushell modules as of 2025, based on patterns established in recent implementations.

## CRITICAL: Nushell SQL Syntax Issue

### Parentheses Escaping in SQL Strings

**IMPORTANT**: In nushell string interpolation, opening parentheses `(` have special meaning for command calls and MUST be escaped when used in SQL or other literal contexts.

**❌ WRONG - causes parse errors:**
```nushell
let sql = $"INSERT INTO table (column) VALUES ('value')"
let sql = $"SELECT COUNT(*) FROM table"
let sql = $"SELECT EXISTS (SELECT 1 FROM table)"
```

**✅ CORRECT - escape opening parentheses:**
```nushell
let sql = $"INSERT INTO table \(column) VALUES \('value')"
let sql = $"SELECT COUNT\(*) FROM table"
let sql = $"SELECT EXISTS \(SELECT 1 FROM table)"
```

**Common SQL patterns requiring escaping:**
- `COUNT(*)` → `COUNT\(*)`
- `EXISTS (subquery)` → `EXISTS \(subquery)`
- `INSERT INTO table (col1, col2)` → `INSERT INTO table \(col1, col2)`
- `COALESCE(value, default)` → `COALESCE\(value, default)`
- Function calls: `NOW()` → `NOW\()`, `gen_random_uuid()` → `gen_random_uuid\()`

This is a recurring issue that causes "invalid characters after closing delimiter" errors. **ALWAYS** escape opening parentheses in SQL strings within nushell modules.

### Mutable Variable Capture in Closures

**IMPORTANT**: Nushell does not allow capturing mutable variables in closures (like `each`, `where`, `reduce` blocks).

**❌ WRONG - causes "Capture of mutable variable" error:**
```nushell
mut cache = {}
$input | each { |item|
    if ($item in $cache) {  # Error: cannot capture mutable $cache
        $cache | get $item
    }
}
```

**✅ CORRECT - use immutable variables or build cache upfront:**
```nushell
# Option 1: Build cache upfront
let cache = $items | reduce -f {} { |item, acc|
    $acc | insert $item (compute-value $item)
}
$input | each { |item|
    $cache | get $item  # OK: $cache is immutable
}

# Option 2: Return updated values from closure
let result = $input | reduce -f {cache: {}, results: []} { |item, acc|
    # Update and return the accumulator
    {
        cache: ($acc.cache | insert $item (compute-value $item))
        results: ($acc.results | append $processed_item)
    }
}
```

## Key Changes Since Original Guide

### 1. **Parameters Record Pattern** 
**New Standard**: Creation commands now use parameters record approach to eliminate cascading if/else logic.

**See**: `stk_project/mod.nu:32-57` and `stk_item/mod.nu:33-53` for complete examples.

**Key Benefits**:
- Single call to `psql new-record` with all parameters
- Cleaner null handling with `default null`
- Eliminates cascading conditional logic

### 2. **Pipeline-Only UUID Operations**
**New Standard**: Commands operating on existing records require UUIDs via piped input only.

**See**: `stk_project/mod.nu:121-129` (project revoke) and `stk_project/mod.nu:267-275` (project line get) for examples.

**Breaking Change**: No more optional UUID parameters - pipeline input is required.

### 3. **Generic PSQL Commands**
**New Standard**: All modules must use standardized commands from `stk_psql/mod.nu`.

**Replace custom SQL with**:
- `psql new-record` - Creation with parameters record
- `psql new-line-record` - Header-line creation  
- `psql list-records` - Standard listing
- `psql get-record` - Single record retrieval
- `psql revoke-record` - Soft delete
- `psql get-type-by-search-key` - Type lookup by search key
- `psql list-types` - Type listing
- `psql detail-record` - Record with type details

### 4. **Header-Line Pattern**
**New Pattern**: Standardized support for header-line relationships (project/project_line).

**See**: `stk_project/mod.nu:174-359` for complete header-line implementation including:
- Line creation via piped header UUID
- Line listing via piped header UUID  
- Line operations via piped line UUID
- Bulk operations support

### 5. **Type Management Integration**
**New Standard**: All modules with types must include:
- `module types` - List available types
- `module detail <uu>` - Show record with type information
- Type resolution in creation commands

**See**: `item types` and `project types` commands for examples.

### 6. **List-Based Column Definitions**
**New Standard**: All column definitions must use nushell lists:

```nushell
# Module Constants
const STK_SCHEMA = "api"
const STK_TABLE_NAME = "stk_module"
const STK_MODULE_COLUMNS = [name, description, is_template, is_valid]  # List syntax, no quotes
```

**Key Changes**:
- Column definitions changed from comma-separated strings to lists
- Base columns are centralized (see `stk_psql/mod.nu` module constants)
- Type table names are auto-derived using `{table}_type` convention
- Minimal constants per module - only what's unique

**Reference Implementation**: See `stk_item` module for clean single-table pattern.

### 7. **Simplified PSQL Function Signatures**
**Updated**: PSQL functions no longer require base_columns parameter:

```nushell
# Old pattern (removed)
psql list-records $schema $table $specific_cols $base_cols $limit

# New pattern
psql list-records $schema $table $specific_cols
psql list-line-records $schema $table $specific_cols $header_uu  # header-line pattern
```

**Available Functions**: See `psql` commands in `stk_psql/mod.nu` for complete list.

### 8. **Bulk Operations Support**
**New Feature**: Commands can handle both single UUIDs and lists where appropriate.

**See**: `project line revoke` command in `stk_project` module for bulk implementation.

## Implementation Patterns

### Basic Module (Single Table)
**Reference**: `stk_item` module - Clean example with minimal constants and list-based columns.

**Key Commands**:
- `item new` - Parameters record creation
- `item list` - Generic listing with `--detail` option
- `item get` - Standard retrieval with `--detail` option
- `item revoke` - Pipeline-only soft delete
- `item types` - Type listing

### Header-Line Module (Related Tables)
**Reference**: `stk_project` module - Complete header-line implementation using `psql list-line-records`.

**Key Commands**:
- `project new` - Header creation
- `project line new` - Line creation via piped header UUID
- `project line list` - Lines via piped header UUID
- `project line get` - Line via piped line UUID
- `project line revoke` - Bulk-capable line deletion

### Legacy Patterns (Attachment/Linking)
**Reference**: `stk_event/mod.nu` and `stk_request/mod.nu` - Specialized attachment patterns.

**Key Commands**:
- `.append event` - Attachment-based creation
- Uses `table_name_uu_json` for cross-entity linking

## Migration Checklist

When updating existing modules to evolved patterns:

- [ ] **Update constants** - Add type table names and include `table_name` in `STK_BASE_COLUMNS`
- [ ] **Refactor creation** - Use `psql new-record` with parameters record
- [ ] **Convert UUID operations** - Pipeline-only, no optional parameters  
- [ ] **Replace custom SQL** - Use generic `psql` commands
- [ ] **Add type commands** - `types` and `detail` where applicable
- [ ] **Update help docs** - Reflect pipeline-only and new patterns
- [ ] **Test thoroughly** - Ensure compatibility with workflows

## Quality Standards

### Documentation
- **README**: Concepts and discovery (see `stk_event/readme.md`)
- **Command Help**: Implementation details and examples
- **Pipeline Specification**: Required for all commands

### Testing  
- **See**: `../test/TESTING_NOTES.md` for comprehensive standards
- **Test all patterns**: Creation, pipeline operations, bulk operations
- **Reference**: `test-project.nu` for header-line testing patterns

### Integration
- **Generic Commands**: Use `stk_psql` functions exclusively
- **Type Support**: Implement where business logic requires
- **Cross-Module**: Support pipeline workflows between modules

## Reference Implementations

### Primary References
- **`stk_project/mod.nu`** - Complete evolved patterns with header-line support
- **`stk_item/mod.nu`** - Clean single-table implementation  
- **`stk_psql/mod.nu`** - All generic commands and modern nushell patterns

### Legacy References  
- **`stk_event/mod.nu`** - Attachment pattern for specialized use cases
- **`stk_request/mod.nu`** - Cross-entity linking pattern

### Testing References
- **`test-project.nu`** - Header-line testing patterns
- **`test-item.nu`** - Single-table testing patterns

## Breaking Changes Summary

1. **Creation Commands**: Must use parameters record pattern
2. **UUID Operations**: Must use pipeline-only approach (no optional parameters)
3. **SQL Operations**: Must use generic `psql` commands (no custom SQL)
4. **Type Integration**: Required for modules with business classification
5. **Constants**: Must include type table references where applicable

These changes reflect the maturation of chuck-stack patterns and significantly improve code consistency, maintainability, and functionality across all modules.
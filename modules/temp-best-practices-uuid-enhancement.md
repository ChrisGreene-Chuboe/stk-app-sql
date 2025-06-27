# Temporary Best Practices - UUID Enhancement & Utility Refactoring

## Overview
This document captures the observed best practices from implementing UUID parameter enhancement and utility refactoring across chuck-stack modules. These patterns should be used as a reference for ensuring consistency.

## 1. UUID Input Handling Standards

### 1.1 Input Types Accepted
All commands that accept UUID input should support:
- **String**: Direct UUID string
- **Record**: Object with 'uu' field (and optionally 'table_name')
- **Table**: Table where first row contains 'uu' field
- **List**: For bulk operations (only where explicitly needed)

### 1.2 Parameter Patterns

#### Pattern A: Piped Input Only
Used when the command naturally expects piped input:
```nushell
# Extract UUID from piped input
let uu = ($in | extract-single-uu)
```

#### Pattern B: Dual Input (Piped OR --uu Parameter)
Used for commands that benefit from parameter flexibility:
```nushell
export def "module get" [
    --uu: string  # UUID as parameter (alternative to piped input)
] {
    # Extract UUID from piped input or --uu parameter
    let uu = if ($in | is-empty) {
        if ($uu | is-empty) {
            error make { msg: "UUID required via piped input or --uu parameter" }
        }
        $uu
    } else {
        ($in | extract-single-uu)
    }
}
```

### 1.3 Current Implementation Status
- **Dual Input Support**: item get/revoke, project get/revoke, project line get/revoke
- **Piped Only**: request get/revoke, todo get/revoke, tag get/revoke, event get/revoke

## 2. Utility Function Usage

### 2.1 extract-single-uu
**Purpose**: Extract a single UUID from various input types
**Usage**: 
```nushell
let uu = ($in | extract-single-uu)
# With custom error message
let uu = ($in | extract-single-uu --error-msg "UUID required: pipe in record to revoke")
```

### 2.2 extract-attach-from-input
**Purpose**: Handle attachment data from piped input or --attach parameter
**Usage**:
```nushell
# Extract attachment data from piped input or --attach parameter
let attach_data = ($in | extract-attach-from-input $attach)
```
**Returns**: `{uu: string, table_name: string|null}` or `null`

### 2.3 extract-uu-table-name
**Purpose**: Normalize various input types to a table format
**Note**: Used internally by other utilities, rarely called directly

## 3. Command-Specific Patterns

### 3.1 .append Commands
For commands that create relationships:
```nushell
export def ".append something" [
    name: string
    --attach(-a): string  # Alternative to piped UUID
] {
    # Extract attachment data from piped input or --attach parameter
    let attach_data = ($in | extract-attach-from-input $attach)
    
    # Handle table_name optimization
    let table_name_uu = if ($attach_data | is-not-empty) {
        if ($attach_data.table_name? | is-not-empty) {
            # We have the table name - use it directly (no DB lookup)
            {table_name: $attach_data.table_name, uu: $attach_data.uu}
        } else {
            # No table name - look it up using psql command
            psql get-table-name-uu $attach_data.uu
        }
    } else {
        null
    }
    
    # Convert to JSON only at SQL boundary
    let table_name_uu_json = if ($table_name_uu | is-empty) {
        "null"
    } else {
        $"'($table_name_uu | to json)'::jsonb"
    }
}
```

### 3.2 get Commands
Standard pattern for retrieving records:
```nushell
export def "module get" [
    --detail(-d)  # Include detailed information
    --uu: string  # UUID as parameter (alternative to piped input)
] {
    # Extract UUID from piped input or --uu parameter
    let uu = if ($in | is-empty) {
        if ($uu | is-empty) {
            error make { msg: "UUID required via piped input or --uu parameter" }
        }
        $uu
    } else {
        ($in | extract-single-uu)
    }
}
```

### 3.3 revoke Commands
Standard pattern for deletion:
```nushell
export def "module revoke" [
    --uu: string  # UUID as parameter (alternative to piped input)
] {
    # Same pattern as get commands
    let uu = if ($in | is-empty) {
        if ($uu | is-empty) {
            error make { msg: "UUID required via piped input or --uu parameter" }
        }
        $uu
    } else {
        ($in | extract-single-uu)
    }
}
```

### 3.4 new Commands
Pattern varies by relationship type:
```nushell
# For parent-child relationships (e.g., todo new)
export def "module new" [
    name: string
    --parent: string  # Parent UUID as parameter
] {
    let piped_input = $in
    
    # Handle optional parent UUID
    let parent_uu = try {
        if ($piped_input | is-empty) {
            if ($parent | is-empty) { null } else { $parent }
        } else {
            ($piped_input | extract-single-uu --error-msg "Parent UUID must be valid")
        }
    } catch {
        null  # Parent is optional
    }
}
```

## 4. Help Documentation Standards

### 4.1 Command Documentation Structure
```nushell
# Brief one-line description
#
# Detailed explanation of what the command does and when to use it.
#
# Accepts piped input:
#   string - UUID of the record
#   record - Single record containing 'uu' field
#   table  - Table where first row contains 'uu' field
#
# Examples:
#   # String UUID
#   "uuid-string" | module command
#   
#   # Single record from list
#   module list | get 0 | module command
#   
#   # Filtered table
#   module list | where name == "test" | module command
#
# Returns:
#   Description of return value
#
# Errors:
#   - When UUID is not provided
#   - When record doesn't exist
```

### 4.2 Parameter Documentation
```nushell
--uu: string      # UUID as parameter (alternative to piped input)
--attach(-a): string  # UUID to attach (alternative to piped input)
--detail(-d)      # Include detailed information
```

## 5. Error Handling Standards

### 5.1 Error Messages
Consistent error messages for common scenarios:
```nushell
# Missing UUID
"UUID required via piped input"
"UUID required via piped input or --uu parameter"

# Specific context
"UUID required: pipe in the UUID of the record you want to tag"
"UUID required: pipe in record to revoke"

# Invalid input
"Input must be a string UUID, record with 'uu' field, or table"
```

### 5.2 Validation Patterns
```nushell
# Check mutually exclusive parameters
if ($param1 | is-not-empty) and ($param2 | is-not-empty) {
    error make { msg: "Cannot use both --param1 and --param2" }
}

# Validate required fields
if ($required_field | is-empty) {
    error make { msg: "Field 'required_field' is required" }
}
```

## 6. Module Constants

### 6.1 Standard Constants
Every module should define:
```nushell
const STK_SCHEMA = "api"
const STK_TABLE_NAME = "stk_modulename"
const STK_MODULENAME_COLUMNS = [
    "uu",
    "created_tmsp",
    "updated_tmsp",
    # ... module-specific columns in order
]
```

### 6.2 Column Ordering
Columns should be ordered as they appear in the database table definition.

## 7. Special Patterns

### 7.1 Table Name Optimization
When working with table_name_uu_json:
```nushell
# Check if table_name is available to avoid DB lookup
let table_name_uu = if ($attach_data.table_name? | is-not-empty) {
    {table_name: $attach_data.table_name, uu: $attach_data.uu}
} else {
    psql get-table-name-uu $attach_data.uu
}
```

### 7.2 JSON Parameter Handling
```nushell
# Handle optional JSON parameters
let record_json = if ($json | is-empty) { "'{}'" } else { $"'($json)'" }
```

### 7.3 Bulk Operations
For commands that support multiple UUIDs:
```nushell
# Handle both single UUID and list of UUIDs
let uuids = if ($input | describe | str starts-with "list") {
    $input
} else {
    [$input]  # Convert single UUID to list
}
```

## 8. Testing Requirements

### 8.1 Input Type Testing
Every command should have tests for:
- String UUID input
- Single record input
- Single-row table input
- Empty table input (where applicable)
- Multi-row table input (uses first row)
- --uu parameter (where implemented)

### 8.2 Error Case Testing
- Missing required UUID
- Invalid UUID format
- Non-existent UUID
- Mutually exclusive parameters

## 9. Recommendations for Full Consistency

### 9.1 Standardize get/revoke Commands
All get and revoke commands should support both piped input and --uu parameter for consistency.

### 9.2 Use Utility Functions
Replace all manual UUID extraction with utility functions to ensure consistent behavior.

### 9.3 Document Piped Input Types
All commands that accept piped input should clearly document accepted types in help text.

### 9.4 Error Message Consistency
Use standard error messages across all modules for similar scenarios.

### 9.5 Test Coverage
Ensure all input modes are tested for every command that accepts UUID input.
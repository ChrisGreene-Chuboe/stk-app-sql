# Chuck-Stack Testing Guide

This guide provides patterns for testing chuck-stack nushell modules in the test environment.

## Table of Contents

- [Quick Start](#quick-start)
- [Testing Philosophy](#testing-philosophy)
- [Test Environment](#test-environment)
- [Template-Based Testing](#template-based-testing)
- [Writing Tests](#writing-tests)
  - [Test Data Idempotency](#test-data-idempotency)
- [Testing JSON Parameters](#testing-json-parameters)
- [Running Tests](#running-tests)
  - [Running Chuck-Stack Commands](#running-chuck-stack-commands)
- [Common Issues](#common-issues)
  - [Permission Denied](#permission-denied)
  - [Module Not Found](#module-not-found)
  - [Database Results and the .0 Pattern](#database-results-and-the-0-pattern)
  - [NULL Values Returned as Strings](#null-values-returned-as-strings)
  - [Assertion Syntax Error](#assertion-syntax-error)
  - [List Access Error](#list-access-error)
  - [Nushell String Escaping](#nushell-string-escaping)
  - [JSON Parameter Issues](#json-parameter-issues)
  - [Test Output Not Visible (print vs echo)](#test-output-not-visible-print-vs-echo)
  - [Error Handling Patterns](#error-handling-patterns)
- [Maintenance Tasks](#maintenance-tasks)
- [Document Maintenance Guidelines](#document-maintenance-guidelines)

## Quick Start

Run existing tests:
```bash
cd test
nix-shell --run "./suite/test-simple.nu"
nix-shell --run "./suite/test-project.nu"
nix-shell --run "cd suite && ./test-all.nu"
```

Create new test using templates (recommended):
```bash
# See templates/README.md for complete instructions
cp templates/test-module-template.nu suite/test-yourmodule.nu
# Replace MODULE with your module name, copy relevant patterns
chmod +x suite/test-yourmodule.nu
```

Create new test manually:
```bash
# Create test file with executable permissions
echo '#!/usr/bin/env nu' > suite/test-feature.nu
chmod +x suite/test-feature.nu
# Edit test following patterns in suite/test-simple.nu
# Note: Use 'test-module.nu' not 'test-stk-module.nu' for consistency
```

## Testing Philosophy

### Purpose
Chuck-stack tests validate that:
- Module commands work as documented
- Database operations execute correctly
- Help examples actually function
- Pipeline patterns integrate properly

### Help Example Testing
Commands include examples in their `--help` documentation. Tests validate these examples work in practice, ensuring documentation stays accurate.

### Assertion-Based Testing
Tests use nushell's `assert` command to verify expected outcomes rather than just checking execution success. See `suite/test-simple.nu` for the reference pattern.

## Test Environment

### Architecture
The test environment uses a **nushell-first architecture**:
- PostgreSQL setup via `start-test.nu`
- Database migrations via `chuck-stack-nushell-psql-migration`
- Automatic cleanup via `stop-test.nu`
- Isolated `/tmp/stk-test-*` workspace

### Test Directory Structure
When `nix-shell` runs, it creates a temporary test workspace:
```
/tmp/stk-test-XXXXX/
├── modules/          # Copied from ../modules
├── migrations/       # Database migrations
├── suite/            # Test scripts
│   ├── test-*.nu
│   └── ...
└── ...              # Other test files
```

**IMPORTANT**: The modules are copied to `./modules` within the test directory, while test files are in `./suite`, which is why test files use `use ../modules *` to access the modules.

### Key Components
- **nix-shell**: Provides PostgreSQL and dependencies
- **start-test.nu**: Initializes database and runs migrations
- **migrate command**: Manages database migrations
- **psql commands**: Execute database operations

### Environment Variables
- `PGHOST`, `PGUSER`, `PGDATABASE`: Standard PostgreSQL connection
- `STK_PG_ROLE`: Current database role
- `STK_TEST_DIR`: Test workspace directory

### Database Access
Always use the `api` schema for function calls:
```sql
-- Correct
SELECT api.get_table_name_uu_json('uuid-here'::uuid);

-- Incorrect (permission denied)
SELECT private.get_table_name_uu_json('uuid-here'::uuid);
```

## Template-Based Testing

Chuck-stack uses test templates to ensure consistent, comprehensive testing across all modules. See `templates/README.md` for usage instructions.

### Critical: Template Maintenance

**With every new module test, evaluate the templates:**

1. **Are patterns complete?** Did the new module require test patterns not in templates?
2. **Best practices?** Does the new test reveal better ways to test existing patterns?
3. **New edge cases?** Did testing uncover scenarios the templates don't handle?
4. **Simplifications?** Can we make the templates clearer or more concise?

**When templates need updates:**
- Update the pattern template files, not individual tests
- Update the `Template Version: YYYY-MM-DD` timestamp in each modified template
- Consider if existing tests should be regenerated with improved templates
- Use `grep -r "Template Version:" suite/` to find tests using older templates
- Document why the change was needed in git commit

**Example improvements discovered through usage:**
- Better assertion patterns for flexible type checking
- Cleaner UUID input validation sequences
- More robust error handling patterns

The templates are living documents that improve with each module implementation.

## Writing Tests

### Test Structure Template
```nushell
#!/usr/bin/env nu

# === Testing module functionality ===

# Import modules and assertions
use ../modules *
use std/assert

# Test basic functionality
# === Testing basic command ===
# print "=== Testing basic command ===" # COMMENTED OUT - uncomment only for debugging
let result = (command parameters)

# Verify with assertions
assert (($result | length) > 0) "Should return results"
assert ($result.field.0 | str contains "expected") "Field should match"

# Return success message for test harness (don't use print here)
"=== All tests completed successfully ==="
```

### Key Patterns

#### 1. Always Make Tests Executable
```bash
chmod +x suite/test-new.nu  # Required before first run
```

#### 2. Import Requirements
```nushell
use ../modules *    # Access module commands (test files are in suite/)
use std/assert      # Enable assertions
```

#### 3. Assertion Syntax - CRITICAL PATTERN
**GOLDEN RULE: Always wrap the entire condition in parentheses!**

```nushell
# ✅ CORRECT - condition wrapped in parentheses
assert (($result | length) > 0) "Error message"
assert (($result.field == "value")) "Field should match"
assert ((($result | describe) == "record")) "Should be a record"
assert (("uu" in ($record | columns))) "Should have uu field"

# ❌ WRONG - will cause "extra positional argument" error
assert ($result | length) > 0 "Error message"  # FAILS!
assert $result.field == "value" "Field should match"  # FAILS!
assert ($result | describe) == "record" "Should be record"  # FAILS!
```

**Why this happens**: Nushell's parser needs parentheses to distinguish the boolean condition from the error message string. Without parentheses, it can't tell where the condition ends.

**Common patterns that need parentheses**:
```nushell
# Comparisons
assert (($value == "expected")) "message"
assert (($count > 0)) "message"
assert (($status != "failed")) "message"

# Pipeline operations
assert (($list | length) > 0) "message"
assert (($data | describe) == "table") "message"
assert (($result | is-empty)) "message"

# String operations
assert (($text | str contains "substring")) "message"
assert (($path | str starts-with "/tmp")) "message"

# List/record checks
assert (("field" in $columns)) "message"
assert (($list | any {|x| $x > 10})) "message"

# Access list elements with .0
assert (($result.field.0 == "value")) "Field should match"

# Flexible type checking - useful when exact type may vary
assert ((($result | describe) | str starts-with "table")) "Should be a table type"
assert ((($result | describe) | str starts-with "record")) "Should be a record type"
# Note: Empty tables/lists return as list<any>, not the original type
```

#### 4. Standard Output
End all tests by returning the success string (not printing):
```nushell
# Return this string as the last expression (no print/echo)
"=== All tests completed successfully ==="
```

### Test Data Idempotency

Tests must be idempotent - they should pass whether run once, multiple times, or as part of the test suite. To achieve this, all test data must use unique identifiers that prevent conflicts.

#### Standard Test Suffix Pattern

Every test file should define a unique test suffix combining:
1. A module-specific prefix (2 letters)
2. A randomly generated suffix (2 alphanumeric characters)

```nushell
#!/usr/bin/env nu

# Test script for stk_todo module
"=== Testing stk_todo Module ==="

# Test-specific suffix to ensure test isolation and idempotency
# Generate random 2-char suffix from letters (upper/lower) and numbers
let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
let random_suffix = (0..1 | each {|_| 
    let idx = (random int 0..($chars | str length | $in - 1))
    $chars | str substring $idx..($idx + 1)
} | str join)
let test_suffix = $"_st($random_suffix)"  # st for stk_todo + 2 random chars

# REQUIRED: Import modules and assert
use ../modules *
use std/assert
```

#### Module Prefix Convention

Each module test should use a consistent 2-letter prefix. Here are examples:
- `_st` - stk_todo
- `_se` - stk_event  
- `_sp` - stk_project
- `_sr` - stk_request
- `_si` - stk_item
- `_sa` - stk_address
- `_sg` - stk_tag
- `_sl` - stk_lines
- `_ai` - stk_ai

#### Using the Test Suffix

Apply the suffix to all test data names:

```nushell
# Create test data with unique names
let project_name = $"Test Project($test_suffix)"
let item_name = $"Widget($test_suffix)"
let todo_name = $"Fix bug($test_suffix)"

let project = (project new $project_name)
let item = (item new $item_name --description "Test item")
let todo = (todo new $todo_name)
```

#### Filtering Test Data

When verifying counts or lists, filter by the test suffix:

```nushell
# Count only items created by this test run
let test_items = (item list | where name =~ $test_suffix)
assert (($test_items | length) == 1) "Should have exactly 1 test item"

# Verify revoked items
let all_todos = (todo list --all | where name =~ $test_suffix)
let active_todos = (todo list | where name =~ $test_suffix)
assert (($all_todos | length) > ($active_todos | length)) "Should have revoked todos"
```

#### Benefits

1. **Test Isolation**: Each test run uses unique data
2. **Idempotency**: Tests pass reliably in any context
3. **Debugging**: Easy to identify which test created data
4. **No Cleanup Required**: Old test data doesn't affect new runs

This pattern ensures tests work correctly whether run:
- Individually (`./test-todo.nu`)
- Multiple times in succession
- As part of the test suite (`./test-all.nu`)
- After other tests that create similar data

### Testing Patterns

#### UUID Piping
```nushell
let uuid = ($result.uu.0)
let details = ($uuid | command get)
```

#### Type Resolution
```nushell
let result = (command new "name" --type-search-key "TYPE_ENUM")
```

#### Request/Event Attachment
```nushell
let attached = ($uuid | .append request "investigation")
```

#### Parent-Child Relationships (parent_uu)
```nushell
# Create parent-child relationship via piped UUID (only method)
let parent = (project new "Parent Project")
let parent_uuid = ($parent.uu.0)
let child = ($parent_uuid | project new "Sub-project")

# Test validation - parent UUID must belong to correct table
let request = (.append request "test-request")
let request_uuid = ($request.uu.0)
let invalid_result = (do { $request_uuid | project new "Test" } | complete)
assert ($invalid_result.exit_code != 0) "Should fail with wrong table UUID"
assert ($invalid_result.stderr | str contains "Invalid parent UUID") "Should show validation error"
```

## Testing JSON Parameters

For modules with `record_json` columns, comprehensive testing of the `--json` parameter is required.

### Basic JSON Test Pattern

```nushell
print "=== Testing item creation with JSON data ==="
let json_item = (item new "Premium Service" --json '{"features": ["24/7 support", "priority access"], "sla": "99.9%"}')
assert ($json_item | columns | any {|col| $col == "uu"}) "JSON item creation should return UUID"
assert ($json_item.uu | is-not-empty) "JSON item UUID should not be empty"
print "✓ Item with JSON created, UUID:" ($json_item.uu)

# Verify the stored JSON
let json_detail = ($json_item.uu.0 | item get)
assert ($json_detail | columns | any {|col| $col == "record_json"}) "Item should have record_json column"
let stored_json = ($json_detail.record_json.0)
assert (($stored_json.features | length) == 2) "Features should have 2 items"
assert ($stored_json.sla == "99.9%") "SLA should be 99.9%"
print "✓ JSON data verified"
```

### Required Test Cases

#### 1. Valid JSON Storage
Test various JSON structures:
```nushell
# Simple key-value
let simple = (module new "Test" --json '{"key": "value"}')

# Nested objects
let nested = (module new "Test" --json '{"parent": {"child": "value"}}')

# Arrays
let arrays = (module new "Test" --json '{"items": [1, 2, 3]}')

# Mixed types
let mixed = (module new "Test" --json '{"text": "hello", "number": 42, "bool": true}')
```

#### 2. Default Behavior (No JSON)
```nushell
print "=== Testing creation without JSON (default behavior) ==="
let no_json_item = (item new "Basic Service")
let no_json_detail = ($no_json_item.uu.0 | item get)
assert ($no_json_detail.record_json.0 == {}) "record_json should be empty object when no JSON provided"
print "✓ Default behavior verified"
```

#### 3. Complex Nested JSON
```nushell
let complex_json = '{
  "pricing": {"monthly": 99.99, "annual": 999.99, "currency": "USD"},
  "availability": {"regions": ["US", "EU", "APAC"], "uptime": 0.999},
  "features": [
    {"name": "API Access", "limit": 1000},
    {"name": "Support", "tier": "premium"}
  ]
}'
let complex_item = (item new "Enterprise Solution" --json $complex_json)
```

#### 4. JSON with Attachments
For modules supporting both attachments and JSON:
```nushell
# Create parent record
let parent = (project new "Parent Project")
let parent_uuid = ($parent.uu.0)

# Attach with JSON
let attached = ($parent_uuid | .append request "task" --json '{"priority": "high", "deadline": "2024-12-31"}')

# Verify both work together
let detail = ($attached.uu.0 | request get)
assert ($detail.table_name_uu_json.0 != {}) "Should have attachment"
assert ($detail.record_json.0.priority == "high") "Should have JSON data"
```

### Special Cases

#### Tables Using Other Tables (e.g., todo using stk_request)
```nushell
# For todo module which uses stk_request table
let json_todo = (todo add "Planning" --json '{"due_date": "2024-12-31"}')

# Must query the underlying table directly
let todo_detail = (psql exec $"SELECT * FROM api.stk_request WHERE uu = '($json_todo.uu.0)'" | get 0)
assert ($todo_detail.record_json.due_date == "2024-12-31") "JSON should be stored in stk_request"
```

#### Empty JSON Object
```nushell
# Test explicit empty JSON
let empty_json = (module new "Empty" --json '{}')
let detail = ($empty_json.uu.0 | module get)
assert ($detail.record_json.0 == {}) "Explicit empty JSON should be stored as empty object"
```

### JSON Test Checklist

For each module with `--json` parameter:
- [ ] Test simple JSON object
- [ ] Test nested JSON structure
- [ ] Test JSON with arrays
- [ ] Test without --json parameter (default to {})
- [ ] Test complex real-world JSON example
- [ ] Test JSON with other parameters (attachments, types, etc.)
- [ ] Verify stored JSON matches input
- [ ] Test edge cases (empty object, special characters)

## Running Tests

### Claude Code Requirements
**CRITICAL**: Claude Code cannot use interactive nix-shell. Always use `--run`:

```bash
# Correct for Claude Code
nix-shell --run "./suite/test-script.nu"

# Incorrect (exits immediately)
nix-shell
./suite/test-script.nu
```

### Execution Patterns

#### Single Test
```bash
nix-shell --run "./suite/test-simple.nu"
```

#### Verify Success
```bash
nix-shell --run "./suite/test-event.nu" 2>&1 | grep "=== All tests completed successfully ==="
```

#### Debug Output (Last 50 Lines)
```bash
nix-shell --run "./suite/test-new.nu" 2>&1 | tail -50
```

#### Efficient Multi-Test
```bash
# Run all with filtered output
nix-shell --run "cd suite && ./test-all.nu" 2>/dev/null | grep -E "PASSED|FAILED"
```

### Running Chuck-Stack Commands

You can explore and run chuck-stack commands directly without creating test files:

#### Ad-hoc Command Execution

```bash
# Simple commands
nix-shell --run "nu -l -c 'use ./modules *; bp list'"
nix-shell --run "nu -l -c 'use ./modules *; tag types'"
nix-shell --run "nu -l -c 'use ./modules *; project types'"
nix-shell --run "nu -l -c 'use ./modules *; item types'"

# Get help for commands
nix-shell --run "nu -l -c 'use ./modules *; bp new --help'"
nix-shell --run "nu -l -c 'use ./modules *; project line new --help'"

# Pipeline operations work fine too
nix-shell --run "nu -l -c 'use ./modules *; bp list | where name =~ \"ACME\"'"
nix-shell --run "nu -l -c 'use ./modules *; tag types | where search_key =~ \"ADDRESS\"'"

# For more complex operations, you can also create test files:
echo '#!/usr/bin/env nu
use ../modules *
bp list | where name =~ "ACME" | print
tag types | where search_key =~ "ADDRESS" | print
' > suite/explore-data.nu
chmod +x suite/explore-data.nu
nix-shell --run "./suite/explore-data.nu"
```

#### Useful for:
- Exploring available commands and types
- Quick data verification
- Understanding command parameters
- Testing command pipelines
- Debugging module behavior

**Note**: Always use `nu -l -c` to ensure proper environment loading:
- `-l` loads the login environment (required for modules)
- `-c` executes the command string

### Debugging Migration Failures

Since migrations run automatically when entering nix-shell, migration errors will prevent test execution. To debug:

```bash
# Quick check for migration errors
nix-shell --run "echo 'Migration check'" 2>&1 | grep -i error

# See detailed migration output (last 50 lines)
nix-shell --run "echo 'Migration check'" 2>&1 | tail -50

# Find specific migration that failed
nix-shell --run "echo 'Migration check'" 2>&1 | grep -B5 -A5 "error"

# Check migration status manually
nix-shell --run "migrate status ./migrations" 2>&1
```

Common migration error patterns:
- **Syntax errors**: Check for missing semicolons or parentheses
- **Dependency errors**: Ensure referenced tables/types exist
- **Permission errors**: Verify correct role is set in migration header
- **Enum errors**: Check enum values are properly quoted

### Debugging Tests

When tests fail, use targeted output:
```bash
# See end of output
nix-shell --run "./suite/test-failing.nu" 2>&1 | tail -50

# Find specific errors
nix-shell --run "./suite/test-failing.nu" 2>&1 | grep -A5 "Error"

# Check assertion failures
nix-shell --run "./suite/test-failing.nu" 2>&1 | grep -B2 "Assertion failed"
```

## Common Issues

### Permission Denied
```bash
# Problem
./suite/test-new.nu  # Error: Permission denied

# Solution
chmod +x suite/test-new.nu
```

### Module Not Found
```nushell
# Problem
let result = (command params)  # Error: Command not found

# Solution
use ../modules *  # Add at top of test
```

### Database Results and the .0 Pattern
```nushell
# CRITICAL: All psql commands return tables, even for single rows!

# Problem
let contact = (contact new "Test")
assert ($contact.name == "Test")  # WRONG! contact is a table, not a record

# Solution
let contact = (contact new "Test")
assert ($contact.name.0 == "Test")  # Correct - access first row with .0

# Explanation
The psql exec command uses CSV format which ALWAYS returns a table.
This means all database operations return tables, requiring .0 to
access the first (and often only) row. This is by design for consistency.

# Common patterns requiring .0:
let uuid = ($result.uu.0)                    # Extract UUID from result
let name = ($result.name.0)                  # Extract name field
let json = ($result.record_json.0)           # Extract JSON field
assert ($result.is_revoked.0 == true)        # Check boolean field
let type_uu = ($result.type_uu.0)           # Extract type UUID

# Exception: When module commands return single records
# Some high-level module commands convert single-row tables to records
# internally. Check the command's documentation or test the output type:
let result_type = ($result | describe)
if ($result_type | str starts-with "table") {
    # Use .0 to access fields
} else {
    # Direct field access
}
```

### NULL Values Returned as Strings
```nushell
# Problem
assert ($result.parent_uu.0 == null)  # Fails because NULL is "null" string

# Solution (temporary)
assert ($result.parent_uu.0 == "null")  # Check for string "null"

# Explanation
The .psqlrc-nu configuration sets \pset null 'null' to distinguish
NULL from empty strings in CSV format. This causes PostgreSQL NULL
values to be returned as the string "null" rather than nushell's
native null type. A future enhancement will convert these strings
back to proper null values in the psql exec command.
```

### Assertion Syntax Error
```nushell
# Problem
assert ($result | length) > 0 "message"  # Error: expected bool

# Solution
assert (($result | length) > 0) "message"  # Wrap in parentheses
```

### List Access Error
```nushell
# Problem
assert ($result.field | str contains "text")  # Error: can't convert list

# Solution
assert ($result.field.0 | str contains "text")  # Access first element
```

### Nushell String Escaping
```nushell
# Problem
let sql = $"INSERT INTO table (column) VALUES ('value')"  # Parse error

# Solution
let sql = $"INSERT INTO table \(column) VALUES \('value')"  # Escape parentheses
```

### JSON Parameter Issues
```nushell
# Problem
let result = (module new "Test" --json {key: "value"})  # Error: expects string

# Solution
let result = (module new "Test" --json '{"key": "value"}')  # Pass as JSON string

# For complex JSON, use variables
let json_data = '{"complex": {"nested": "data"}}'
let result = (module new "Test" --json $json_data)
```

### Test Output Not Visible (print vs echo)
```nushell
# Problem
echo "Test is running..."  # Nothing appears when test runs
echo $"Result: ($value)"   # Only final return value is shown

# Explanation
In nushell, only the last expression is returned when a script runs.
The `echo` command returns its string, which won't be displayed unless
it's the final expression. This makes debugging tests difficult.

# Solution for debugging
print "Test is running..."  # Use print for debug output to stderr
print $"Result: ($value)"   # This will always be visible

# IMPORTANT: Print statements policy
# - All print statements in tests should be COMMENTED OUT by default
# - Only uncomment print statements when actively debugging
# - Re-comment print statements before committing
# - test-all.nu is exempt (it's the test runner and needs output)
# - WARNING messages in test-ai.nu are exempt (they indicate missing tools)

# Normal test pattern (without debug output)
#!/usr/bin/env nu
use ../modules *
use std/assert

# === Testing Feature X ===
# print "=== Testing Feature X ===" # COMMENTED OUT - uncomment only for debugging
let result = (some command)
assert ($result.field == "expected") "Should match expected value"

# Final expression for test harness
"=== All tests completed successfully ==="

# When debugging is needed
#!/usr/bin/env nu
use ../modules *
use std/assert

# === Testing Feature X ===
print "=== Testing Feature X ===" # TEMPORARILY UNCOMMENTED for debugging
let result = (some command)
print $"DEBUG: Result is ($result)"  # Temporary debug output
assert ($result.field == "expected") "Should match expected value"

# Final expression for test harness
"=== All tests completed successfully ==="
```

### Error Handling Patterns
```nushell
# Preferred: Use try/catch for nushell functions
try {
    $bad_input | extract-uu-table-name
    assert false "Should have thrown error"
} catch { |err|
    assert (($err.msg | str contains "expected error")) "Error message should match"
}

# Alternative: do/complete can capture errors but try/catch is clearer
let result = (do { $input | some-command } | complete)
if ($result.exit_code != 0) {
    # Handle error
}

# Special case: Table operations with 'each' may return list<error>
let result = ($bad_table | extract-uu-table-name)
assert ((($result | describe) | str contains "error")) "Should return error list"
```

## Maintenance Tasks

### Updating Migration Tool

When `chuck-stack-nushell-psql-migration` is updated:

1. **Get new commit hash**:
   ```bash
   cd chuck-stack-nushell-psql-migration
   git log --format="%H" -1
   ```

2. **Update shell.nix**:
   - Find `migrationUtilSrc` section
   - Update `rev` with new commit hash
   - Use placeholder SHA256: `sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=`

3. **Get correct SHA256**:
   ```bash
   cd test
   timeout 30 nix-shell --command "echo 'testing'" 2>&1 | grep "got:"
   ```

4. **Update with correct hash**:
   - Replace placeholder with the "got:" value

5. **Test update**:
   ```bash
   nix-shell --run "echo 'Update successful'"
   ```

### Migration Commands

Current commands (via chuck-stack-nushell-psql-migration):
```bash
# From within test directory
migrate status ./migrations
migrate run ./migrations
migrate add ./migrations "description"
```

### Role Switching

For DDL operations:
```bash
export PGUSER=stk_superuser
export STK_PG_ROLE=stk_superuser
```

Default role is `stk_login` with `stk_api_role`.

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
- **Template-first mindset**: When documenting new patterns, consider if they belong in test templates
- **Continuous improvement**: Each new module should trigger template evaluation
